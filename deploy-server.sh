#!/bin/bash

# PC Compare Deployment Script for pc.builds.ngrok.app
# Run this script on your server after SSH connection

echo "========================================="
echo "PC Compare Deployment Script"
echo "Domain: pc.builds.ngrok.app"
echo "Port: 8001 (to avoid conflict with port 8000)"
echo "========================================="

# Step 1: Update system and install dependencies
echo -e "\n[Step 1] Installing system dependencies..."
sudo apt update
sudo apt install -y python3 python3-pip nginx certbot python3-certbot-nginx git docker.io docker-compose

# Step 2: Clone repository
echo -e "\n[Step 2] Cloning repository..."
cd /opt
if [ -d "pc-compare" ]; then
    echo "Directory pc-compare already exists, removing..."
    sudo rm -rf pc-compare
fi
sudo git clone https://github.com/serjnavigatian/pc-compare.git pc-compare
cd pc-compare

# Step 3: Create .env file
echo -e "\n[Step 3] Creating .env configuration..."
sudo tee .env > /dev/null <<'EOF'
# VK API Configuration
VK_CLIENT_ID=your_vk_app_id_here
VK_CLIENT_SECRET=your_vk_app_secret_here
VK_TOKEN=vk1.a.your_token_here
PUBLIC_BASE_URL=https://pc.builds.ngrok.app
VK_API_VERSION=5.199

# Database Configuration
DATABASE_URL=postgresql://pc_builds_user:secure_password_2024@db:5432/pc_builds
POSTGRES_USER=pc_builds_user
POSTGRES_PASSWORD=secure_password_2024
POSTGRES_DB=pc_builds

# Parser Settings
MIN_PRICE=40000
PRICE_COMPARISON_RANGE=50000

# VK Groups to Parse (comma-separated)
VK_GROUP_IDS=123456,789012,345678

# Frontend Configuration
REACT_APP_API_URL=https://pc.builds.ngrok.app/api
REACT_APP_WS_URL=wss://pc.builds.ngrok.app/ws

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Security
SECRET_KEY=your-secret-key-here-change-in-production-2024
ALLOWED_ORIGINS=https://pc.builds.ngrok.app

# ML Model Settings
USE_ML_COLOR_DETECTION=true
ML_MODEL_PATH=/app/models

# Logging
LOG_LEVEL=INFO
LOG_FILE=/app/logs/app.log

# Development
DEBUG=false
EOF

echo "IMPORTANT: Please edit /opt/pc-compare/.env and add your VK credentials!"

# Step 4: Create custom docker-compose for production with different ports
echo -e "\n[Step 4] Creating docker-compose.production.yml..."
sudo tee docker-compose.production.yml > /dev/null <<'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    container_name: pc-compare-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: pc-compare-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

  # Backend API - using port 8001 to avoid conflict
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: pc-compare-backend
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      VK_CLIENT_ID: ${VK_CLIENT_ID}
      VK_CLIENT_SECRET: ${VK_CLIENT_SECRET}
      VK_TOKEN: ${VK_TOKEN}
      PUBLIC_BASE_URL: ${PUBLIC_BASE_URL}
      SECRET_KEY: ${SECRET_KEY}
      MIN_PRICE: ${MIN_PRICE}
      PRICE_COMPARISON_RANGE: ${PRICE_COMPARISON_RANGE}
      VK_GROUP_IDS: ${VK_GROUP_IDS}
    volumes:
      - ./backend:/app
      - ./logs:/app/logs
    ports:
      - "127.0.0.1:8001:8000"
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000

  # Frontend
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      args:
        REACT_APP_API_URL: ${REACT_APP_API_URL}
    container_name: pc-compare-frontend
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "127.0.0.1:3001:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    environment:
      REACT_APP_API_URL: ${REACT_APP_API_URL}

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: pc-compare-nginx
    restart: unless-stopped
    depends_on:
      - backend
      - frontend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./logs/nginx:/var/log/nginx

volumes:
  postgres_data:
  redis_data:

networks:
  default:
    name: pc-compare-network
EOF

# Step 5: Create Nginx configuration
echo -e "\n[Step 5] Creating Nginx configuration..."
sudo mkdir -p docker/nginx
sudo tee docker/nginx/nginx.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name pc.builds.ngrok.app localhost;
    
    client_max_body_size 100M;
    
    # API requests
    location /api {
        proxy_pass http://backend:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        
        # Timeouts for long operations
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
    
    # WebSocket connections
    location /ws {
        proxy_pass http://backend:8000/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    # OAuth callback
    location /auth/callback {
        proxy_pass http://backend:8000/auth/callback;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    # Frontend React app
    location / {
        proxy_pass http://frontend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
EOF

# Step 6: Create backend Dockerfile if not exists
echo -e "\n[Step 6] Creating backend Dockerfile..."
sudo tee backend/Dockerfile > /dev/null <<'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create logs directory
RUN mkdir -p /app/logs

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Step 7: Create frontend Dockerfile if not exists
echo -e "\n[Step 7] Creating frontend Dockerfile..."
sudo tee frontend/Dockerfile > /dev/null <<'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Build the application
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
EOF

# Step 8: Start Docker services
echo -e "\n[Step 8] Starting Docker services..."
sudo systemctl enable docker
sudo systemctl start docker

# Step 9: Build and start containers
echo -e "\n[Step 9] Building and starting containers..."
sudo docker-compose -f docker-compose.production.yml down
sudo docker-compose -f docker-compose.production.yml build
sudo docker-compose -f docker-compose.production.yml up -d

# Step 10: Configure firewall
if command -v ufw &> /dev/null; then
    echo -e "\n[Step 10] Configuring firewall..."
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    echo "Firewall configured!"
fi

# Step 11: Show status
echo -e "\n[Step 11] Checking container status..."
sudo docker-compose -f docker-compose.production.yml ps

echo -e "\n========================================="
echo "Deployment complete!"
echo "========================================="
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Edit /opt/pc-compare/.env and add your VK credentials"
echo "2. Restart containers: cd /opt/pc-compare && sudo docker-compose -f docker-compose.production.yml restart"
echo "3. Initialize database: sudo docker-compose -f docker-compose.production.yml exec backend python -m app.init_db"
echo ""
echo "Your application will be available at:"
echo "  https://pc.builds.ngrok.app"
echo ""
echo "Useful commands:"
echo "  View logs: sudo docker-compose -f docker-compose.production.yml logs -f"
echo "  Restart: sudo docker-compose -f docker-compose.production.yml restart"
echo "  Stop: sudo docker-compose -f docker-compose.production.yml down"
echo ""
echo "========================================="
EOF

chmod +x deploy-server.sh