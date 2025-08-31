"""
main.py - FastAPI backend для системы сравнения ПК сборок
"""

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, String, Float, DateTime, Boolean, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import os
import asyncio
from app.parser.unified_parser import UnifiedVKParser

# Настройки
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./pc_builds.db")
VK_TOKEN = os.getenv("VK_TOKEN", "")
MIN_PRICE = float(os.getenv("MIN_PRICE", "40000"))
PRICE_COMPARISON_RANGE = float(os.getenv("PRICE_COMPARISON_RANGE", "50000"))

# База данных
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Модель БД
class PCBuildDB(Base):
    __tablename__ = "pc_builds"
    
    id = Column(String, primary_key=True)
    company = Column(String, index=True)
    title = Column(String)
    description = Column(String)
    price = Column(Float, index=True)
    cpu = Column(String, index=True)
    gpu = Column(String, index=True)
    ram = Column(String)
    case_color = Column(String)
    photo_url = Column(String)
    vk_url = Column(String)
    parsed_at = Column(DateTime, default=datetime.now)
    is_our_build = Column(Boolean, default=False)

Base.metadata.create_all(bind=engine)

# Pydantic модели
class BuildResponse(BaseModel):
    id: str
    company: str
    title: str
    description: str
    price: float
    price_formatted: str
    cpu: str
    gpu: str
    ram: str
    case_color: str
    photo_url: str
    vk_url: str
    is_our_build: bool
    price_comparison: Optional[str] = None
    
    class Config:
        from_attributes = True

class ComparisonRequest(BaseModel):
    build_id: str
    comparison_type: str

class ParseRequest(BaseModel):
    group_ids: List[int]
    source: str = "market"

# FastAPI app
app = FastAPI(
    title="VK PC Build Comparator API",
    description="API для сравнения компьютерных сборок из VK Market",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency для получения БД сессии
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# === API Endpoints ===

@app.get("/")
async def root():
    """Проверка работоспособности API"""
    return {"status": "ok", "service": "VK PC Build Comparator", "version": "1.0.0"}

@app.get("/api/builds/our", response_model=List[BuildResponse])
async def get_our_builds(db: Session = Depends(get_db)):
    """Получить список наших сборок (VA-PC)"""
    builds = db.query(PCBuildDB).filter(
        PCBuildDB.is_our_build == True
    ).order_by(PCBuildDB.price).all()
    
    return [format_build_response(build) for build in builds]

@app.get("/api/builds/{build_id}", response_model=BuildResponse)
async def get_build(build_id: str, db: Session = Depends(get_db)):
    """Получить информацию о конкретной сборке"""
    build = db.query(PCBuildDB).filter(PCBuildDB.id == build_id).first()
    
    if not build:
        raise HTTPException(status_code=404, detail="Build not found")
        
    return format_build_response(build)

@app.post("/api/compare/price", response_model=List[BuildResponse])
async def compare_by_price(
    request: ComparisonRequest,
    db: Session = Depends(get_db)
):
    """Сравнить сборку с другими по цене (±50k рублей)"""
    
    target = db.query(PCBuildDB).filter(PCBuildDB.id == request.build_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Build not found")
    
    min_price = target.price - PRICE_COMPARISON_RANGE
    max_price = target.price + PRICE_COMPARISON_RANGE
    
    similar = db.query(PCBuildDB).filter(
        PCBuildDB.price >= min_price,
        PCBuildDB.price <= max_price,
        PCBuildDB.id != target.id,
        PCBuildDB.is_our_build == False
    ).order_by(PCBuildDB.price).limit(20).all()
    
    results = []
    for build in similar:
        response = format_build_response(build)
        
        if build.price < target.price:
            response.price_comparison = "cheaper"
        elif build.price > target.price:
            response.price_comparison = "more_expensive"
        else:
            response.price_comparison = "equal"
            
        results.append(response)
    
    return results

@app.post("/api/compare/specs", response_model=List[BuildResponse])
async def compare_by_specs(
    request: ComparisonRequest,
    db: Session = Depends(get_db)
):
    """Сравнить сборку с другими по CPU и GPU"""
    
    target = db.query(PCBuildDB).filter(PCBuildDB.id == request.build_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Build not found")
    
    similar = db.query(PCBuildDB).filter(
        PCBuildDB.cpu == target.cpu,
        PCBuildDB.gpu == target.gpu,
        PCBuildDB.id != target.id,
        PCBuildDB.is_our_build == False
    ).order_by(PCBuildDB.price).limit(20).all()
    
    results = []
    for build in similar:
        response = format_build_response(build)
        
        if build.price < target.price:
            response.price_comparison = "cheaper"
        elif build.price > target.price:
            response.price_comparison = "more_expensive"
        else:
            response.price_comparison = "equal"
            
        results.append(response)
    
    return results

@app.post("/api/parse/start")
async def start_parsing(
    request: ParseRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Запустить парсинг групп VK"""
    
    if not VK_TOKEN:
        raise HTTPException(status_code=500, detail="VK token not configured")
    
    background_tasks.add_task(
        parse_groups_task,
        request.group_ids,
        request.source,
        db
    )
    
    return {
        "status": "parsing_started",
        "groups": request.group_ids,
        "source": request.source
    }

@app.get("/api/stats")
async def get_statistics(db: Session = Depends(get_db)):
    """Получить статистику по базе"""
    
    total_builds = db.query(PCBuildDB).count()
    our_builds = db.query(PCBuildDB).filter(PCBuildDB.is_our_build == True).count()
    other_builds = total_builds - our_builds
    
    last_update = db.query(PCBuildDB.parsed_at).order_by(
        PCBuildDB.parsed_at.desc()
    ).first()
    
    return {
        "total_builds": total_builds,
        "our_builds": our_builds,
        "other_builds": other_builds,
        "last_update": last_update[0] if last_update else None
    }

# === Helper функции ===

def format_build_response(build: PCBuildDB) -> BuildResponse:
    """Форматирование ответа для сборки"""
    return BuildResponse(
        id=build.id,
        company=build.company,
        title=build.title,
        description=build.description,
        price=build.price,
        price_formatted=f"{int(build.price):,} руб.".replace(',', ' '),
        cpu=build.cpu or "Не указан",
        gpu=build.gpu or "Не указана",
        ram=f"{build.ram} GB" if build.ram else "Не указана",
        case_color=build.case_color or "Не определен",
        photo_url=build.photo_url,
        vk_url=build.vk_url,
        is_our_build=build.is_our_build,
        price_comparison=None
    )

async def parse_groups_task(group_ids: List[int], source: str, db: Session):
    """Фоновая задача для парсинга групп"""
    try:
        parser = UnifiedVKParser(VK_TOKEN, MIN_PRICE)
        builds = await parser.parse_groups(group_ids, source)
        
        for build_data in builds:
            existing = db.query(PCBuildDB).filter(
                PCBuildDB.id == build_data.id
            ).first()
            
            if existing:
                for key, value in build_data.to_dict().items():
                    setattr(existing, key, value)
            else:
                db_build = PCBuildDB(**build_data.to_dict())
                
                if "VA-PC" in build_data.company.upper():
                    db_build.is_our_build = True
                    
                db.add(db_build)
        
        db.commit()
        
    except Exception as e:
        print(f"Parsing error: {e}")
        db.rollback()

@app.on_event("startup")
async def startup_event():
    """Инициализация при запуске"""
    print("Starting VK PC Build Comparator API...")
    # Можно добавить автоматический парсинг при старте

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
