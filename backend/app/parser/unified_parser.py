#!/usr/bin/env python3
"""
unified_parser.py - Объединенный парсер VK Market для компьютерных сборок
Совмещает функционал vk_export.py и process_csv.py
"""

import re
import json
import asyncio
import aiohttp
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
from dataclasses import dataclass, asdict
import torch
import open_clip
from PIL import Image
from io import BytesIO
import logging
import os

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class PCBuild:
    """Модель данных для компьютерной сборки"""
    id: str
    company: str
    title: str
    description: str
    price: float
    cpu: str
    gpu: str
    ram: str
    case_color: str
    photo_url: str
    vk_url: str
    parsed_at: datetime
    
    def to_dict(self) -> Dict:
        data = asdict(self)
        data['parsed_at'] = self.parsed_at.isoformat()
        return data

class VKMarketParser:
    """Парсер товаров из VK Market"""
    
    def __init__(self, token: str, api_version: str = "5.199"):
        self.token = token
        self.api_version = api_version
        self.base_url = "https://api.vk.com/method/"
        self.fallback_urls = [
            "https://api.vk.com/method/",
            "https://vkresult.ru/method/"
        ]
        self.session = None
        
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
            
    async def vk_call(self, method: str, params: Dict[str, Any]) -> Dict:
        """Асинхронный вызов VK API с fallback"""
        params['access_token'] = self.token
        params['v'] = self.api_version
        
        for base_url in self.fallback_urls:
            try:
                async with self.session.get(f"{base_url}{method}", params=params) as resp:
                    data = await resp.json()
                    
                    if 'error' in data:
                        logger.error(f"VK API Error: {data['error']}")
                        # Пробуем следующий URL если ошибка
                        continue
                        
                    return data.get('response', {})
            except Exception as e:
                logger.warning(f"Failed with {base_url}: {e}")
                continue
                
        raise Exception(f"All API endpoints failed for {method}")
            
    async def get_market_items(self, group_id: int, limit: int = 1000) -> List[Dict]:
        """Получить товары из группы через market.get"""
        items = []
        offset = 0
        count = 200
        
        while len(items) < limit:
            data = await self.vk_call('market.get', {
                'owner_id': -group_id,
                'count': count,
                'offset': offset,
                'extended': 1
            })
            
            batch = data.get('items', [])
            if not batch:
                break
                
            items.extend(batch)
            offset += count
            
            if len(batch) < count:
                break
                
        return items[:limit]
        
    async def get_wall_items(self, group_id: int, limit: int = 1000) -> List[Dict]:
        """Получить товары со стены группы"""
        items = []
        offset = 0
        count = 100
        
        while len(items) < limit:
            data = await self.vk_call('wall.get', {
                'owner_id': -group_id,
                'count': count,
                'offset': offset
            })
            
            posts = data.get('items', [])
            if not posts:
                break
                
            # Извлекаем товары из вложений
            for post in posts:
                attachments = post.get('attachments', [])
                for att in attachments:
                    if att.get('type') == 'market':
                        items.append(att.get('market', {}))
                        
            offset += count
            
            if len(posts) < count:
                break
                
        return items[:limit]
        
    async def get_group_name(self, group_id: int) -> str:
        """Получить название группы"""
        try:
            data = await self.vk_call('groups.getById', {
                'group_ids': str(group_id)
            })
            if data and len(data) > 0:
                return data[0].get('name', f'Group {group_id}')
        except:
            pass
        return f'Group {group_id}'

class PCComponentExtractor:
    """Извлечение компонентов ПК из текста"""
    
    def __init__(self):
        self.cpu_patterns = [
            # Intel patterns
            r'(?:Intel\s*)?Core\s*Ultra\s*[579]\s*\d{3,4}[A-Z]*',
            r'(?:Intel\s*)?(?:Core\s*)?i[3579][\s\-]*\d{4,5}[A-Z]*',
            # AMD patterns  
            r'(?:AMD\s*)?Ryzen\s*[3579]?\s*\d{4}[A-Z0-9]*',
            # Simplified patterns
            r'i[3579][\s\-]*\d{4,5}',
            r'R[3579][\s\-]*\d{4}'
        ]
        
        self.gpu_patterns = [
            # NVIDIA
            r'(?:GeForce\s*)?RTX\s*\d{4}(?:\s*Ti|\s*SUPER)?',
            r'(?:GeForce\s*)?GTX\s*\d{3,4}(?:\s*Ti)?',
            # AMD
            r'(?:Radeon\s*)?RX\s*\d{3,4}(?:\s*XT)?',
            r'(?:AMD\s*)?Radeon\s*\d{4}(?:\s*XT)?',
            # Intel Arc
            r'(?:Intel\s*)?ARC\s*A\d{3,4}'
        ]
        
        self.ram_patterns = [
            r'(\d+)\s*[xх]\s*(\d+)\s*GB',  # 2x8GB format
            r'(\d+)\s*GB\s*(?:DDR\d)?',     # Simple GB format
            r'DDR\d?\s+(\d+)\s*GB'          # DDR5 32GB format
        ]
        
    def extract_cpu(self, text: str) -> str:
        """Извлечь модель процессора"""
        if not text:
            return ""
            
        text = text.replace('–', '-').replace('—', '-')
        
        # Сначала ищем в контексте "Процессор:"
        proc_match = re.search(r'процессор[:\s\-—]+([^\n\t]+)', text, re.IGNORECASE)
        if proc_match:
            proc_text = proc_match.group(1)
            for pattern in self.cpu_patterns:
                match = re.search(pattern, proc_text, re.IGNORECASE)
                if match:
                    return self.normalize_cpu(match.group())
        
        # Если не нашли, ищем по всему тексту
        for pattern in self.cpu_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return self.normalize_cpu(match.group())
                
        return ""
        
    def extract_gpu(self, text: str) -> str:
        """Извлечь модель видеокарты"""
        if not text:
            return ""
            
        text = text.replace('–', '-').replace('—', '-')
        
        # Сначала ищем в контексте "Видеокарта:"
        gpu_match = re.search(r'видеокарта[:\s\-—]+([^\n\t]+)', text, re.IGNORECASE)
        if gpu_match:
            gpu_text = gpu_match.group(1)
            for pattern in self.gpu_patterns:
                match = re.search(pattern, gpu_text, re.IGNORECASE)
                if match:
                    return self.normalize_gpu(match.group())
        
        # Если не нашли, ищем по всему тексту
        for pattern in self.gpu_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return self.normalize_gpu(match.group())
                
        return ""
        
    def extract_ram(self, text: str) -> str:
        """Извлечь объем оперативной памяти"""
        if not text:
            return ""
            
        # Проверяем формат умножения (2x8GB)
        mult_match = re.search(r'(\d+)\s*[xх]\s*(\d+)\s*GB', text, re.IGNORECASE)
        if mult_match:
            count = int(mult_match.group(1))
            size = int(mult_match.group(2))
            total = count * size
            if total in [8, 16, 32, 48, 64, 96, 128]:
                return str(total)
                
        # Ищем в контексте памяти
        ram_contexts = [
            r'оперативная память[:\s\-—]+[^0-9]*(\d+)\s*GB',
            r'память[:\s\-—]+[^0-9]*(\d+)\s*GB',
            r'DDR\d[:\s]+[^0-9]*(\d+)\s*GB',
            r'RAM[:\s]+(\d+)\s*GB',
            r'ОЗУ[:\s]+(\d+)\s*GB'
        ]
        
        for pattern in ram_contexts:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                ram = int(match.group(1))
                if ram in [8, 16, 32, 48, 64, 96, 128]:
                    return str(ram)
        
        # Простой поиск числа с GB
        ram_matches = re.findall(r'(\d+)\s*GB', text, re.IGNORECASE)
        for match in ram_matches:
            ram = int(match)
            if ram in [8, 16, 32, 48, 64, 96, 128]:
                return str(ram)
                
        return ""
        
    def normalize_cpu(self, cpu: str) -> str:
        """Нормализация формата CPU"""
        # Intel Core Ultra -> U
        cpu = re.sub(r'(?:Intel\s*)?Core\s*Ultra\s*(\d)', r'U\1', cpu, flags=re.IGNORECASE)
        # AMD Ryzen -> R
        cpu = re.sub(r'(?:AMD\s*)?Ryzen\s*(\d)', r'R\1', cpu, flags=re.IGNORECASE)
        # Intel Core iX -> IX
        cpu = re.sub(r'(?:Intel\s*)?(?:Core\s*)?i(\d)', r'I\1', cpu, flags=re.IGNORECASE)
        
        return cpu.strip().upper()
        
    def normalize_gpu(self, gpu: str) -> str:
        """Нормализация формата GPU"""
        # Убираем производителя
        gpu = re.sub(r'(?:NVIDIA\s*)?(?:GeForce\s*)?', '', gpu, flags=re.IGNORECASE)
        gpu = re.sub(r'(?:AMD\s*)?(?:Radeon\s*)?', '', gpu, flags=re.IGNORECASE)
        
        return gpu.strip().upper()
        
    def extract_case_color_from_text(self, text: str) -> Optional[str]:
        """Извлечение цвета корпуса из текста"""
        if not text:
            return None
            
        text_lower = text.lower()
        
        # Ищем упоминания корпуса
        case_match = re.search(r'корпус[:\s]+([^\n\t]+)', text_lower)
        if case_match:
            case_info = case_match.group(1)
            
            white_indicators = ['белый', 'белом', 'white', 'wh']
            black_indicators = ['черный', 'чёрный', 'черном', 'black', 'bk']
            
            for indicator in white_indicators:
                if indicator in case_info:
                    return 'white'
                    
            for indicator in black_indicators:
                if indicator in case_info:
                    return 'black'
                    
        return None

class CaseColorDetector:
    """Определение цвета корпуса через ML"""
    
    def __init__(self):
        self.model = None
        self.preprocess = None
        self.tokenizer = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.enabled = os.getenv('USE_ML_COLOR_DETECTION', 'false').lower() == 'true'
        
    def load_model(self):
        """Загрузка модели OpenCLIP"""
        if not self.enabled:
            logger.info("ML color detection disabled")
            return
            
        try:
            self.model, _, self.preprocess = open_clip.create_model_and_transforms(
                'ViT-B-32', 
                pretrained='openai'
            )
            self.model = self.model.to(self.device)
            self.model.eval()
            self.tokenizer = open_clip.get_tokenizer('ViT-B-32')
            logger.info("Color detection model loaded")
        except Exception as e:
            logger.error(f"Failed to load color model: {e}")
            self.enabled = False
            
    async def detect_color(self, image_url: str) -> str:
        """Определить цвет корпуса по фото"""
        if not self.enabled or not self.model or not image_url:
            return ""
            
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(image_url) as resp:
                    if resp.status != 200:
                        return ""
                    
                    image_data = await resp.read()
                    image = Image.open(BytesIO(image_data)).convert('RGB')
                    
            # Подготовка изображения
            image_input = self.preprocess(image).unsqueeze(0).to(self.device)
            text_inputs = self.tokenizer([
                'white computer case', 
                'black computer case'
            ]).to(self.device)
            
            # Получаем эмбеддинги
            with torch.no_grad():
                image_features = self.model.encode_image(image_input)
                text_features = self.model.encode_text(text_inputs)
                
                # Нормализуем
                image_features /= image_features.norm(dim=-1, keepdim=True)
                text_features /= text_features.norm(dim=-1, keepdim=True)
                
                # Считаем сходство
                similarity = (100.0 * image_features @ text_features.T).softmax(dim=-1)
                
            values = similarity[0].cpu().numpy()
            return 'white' if values[0] > values[1] else 'black'
            
        except Exception as e:
            logger.error(f"Color detection failed: {e}")
            return ""

class UnifiedVKParser:
    """Объединенный парсер VK Market"""
    
    def __init__(self, token: str, min_price: float = 40000):
        self.vk_parser = VKMarketParser(token)
        self.extractor = PCComponentExtractor()
        self.color_detector = CaseColorDetector()
        self.min_price = min_price
        
    async def parse_groups(self, group_ids: List[int], 
                          source: str = 'market') -> List[PCBuild]:
        """Парсинг групп и извлечение данных о сборках"""
        
        # Загружаем модель для определения цвета
        self.color_detector.load_model()
        
        all_builds = []
        
        async with self.vk_parser as parser:
            for group_id in group_ids:
                logger.info(f"Parsing group {group_id}")
                
                # Получаем название группы
                company = await parser.get_group_name(group_id)
                
                # Получаем товары
                if source == 'market':
                    items = await parser.get_market_items(group_id)
                else:
                    items = await parser.get_wall_items(group_id)
                    
                logger.info(f"Found {len(items)} items in group {group_id}")
                    
                # Обрабатываем каждый товар
                for item in items:
                    build = await self.process_item(item, group_id, company)
                    if build and build.price >= self.min_price:
                        all_builds.append(build)
                        
        logger.info(f"Total builds parsed: {len(all_builds)}")
        return all_builds
        
    async def process_item(self, item: Dict, group_id: int, company: str) -> Optional[PCBuild]:
        """Обработка одного товара"""
        try:
            # Базовые данные
            title = item.get('title', '')
            description = item.get('description', '')
            
            # Цена
            price_obj = item.get('price', {})
            if isinstance(price_obj, dict):
                price = float(price_obj.get('amount', 0)) / 100
            else:
                price = 0
            
            # Фильтр по цене
            if price < self.min_price:
                return None
                
            # Извлекаем компоненты
            full_text = f"{title}\n{description}"
            cpu = self.extractor.extract_cpu(full_text)
            gpu = self.extractor.extract_gpu(full_text)
            ram = self.extractor.extract_ram(full_text)
            
            # URL фото
            photo_url = item.get('thumb_photo', '')
            if not photo_url and item.get('photos'):
                photos = item.get('photos', [])
                if photos and isinstance(photos[0], dict):
                    sizes = photos[0].get('sizes', [])
                    if sizes:
                        photo_url = sizes[-1].get('url', '')
                    
            # Определяем цвет корпуса
            case_color = self.extractor.extract_case_color_from_text(description)
            if not case_color and photo_url:
                case_color = await self.color_detector.detect_color(photo_url)
            if not case_color:
                case_color = ""
            
            # Формируем URL товара
            item_id = item.get('id')
            vk_url = f"https://vk.com/market-{group_id}?w=product-{group_id}_{item_id}"
            
            return PCBuild(
                id=f"{group_id}_{item_id}",
                company=company,
                title=title,
                description=description,
                price=price,
                cpu=cpu,
                gpu=gpu,
                ram=ram,
                case_color=case_color,
                photo_url=photo_url,
                vk_url=vk_url,
                parsed_at=datetime.now()
            )
            
        except Exception as e:
            logger.error(f"Failed to process item: {e}")
            return None

# Пример использования
async def main():
    """Пример запуска парсера"""
    
    # Настройки из переменных окружения
    VK_TOKEN = os.getenv('VK_TOKEN', '')
    GROUP_IDS = [int(x) for x in os.getenv('VK_GROUP_IDS', '').split(',') if x]
    MIN_PRICE = float(os.getenv('MIN_PRICE', '40000'))
    
    if not VK_TOKEN or not GROUP_IDS:
        logger.error("VK_TOKEN and VK_GROUP_IDS must be set")
        return
    
    # Создаем парсер
    parser = UnifiedVKParser(VK_TOKEN, MIN_PRICE)
    
    # Парсим группы
    logger.info("Starting parsing...")
    builds = await parser.parse_groups(GROUP_IDS, source='market')
    
    # Сохраняем результаты
    output_file = 'parsed_builds.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump([build.to_dict() for build in builds], f, ensure_ascii=False, indent=2)
    
    logger.info(f"Saved {len(builds)} builds to {output_file}")

if __name__ == "__main__":
    asyncio.run(main())
