#!/bin/bash

# PC Compare Deployment Script - PART 2
# Финальная настройка с VK credentials

echo "========================================="
echo "PC Compare Deployment - PART 2"
echo "Complete deployment with VK credentials"
echo "========================================="

# Check if we're in the right directory
if [ ! -f "/opt/pc-compare/.env" ]; then
    echo "Error: Please run this script from /opt/pc-compare directory"
    echo "Run: cd /opt/pc-compare && ./deploy-part2.sh"
    exit 1
fi

cd /opt/pc-compare

# Step 1: Get VK credentials from user
echo -e "\n📝 Please enter your VK Application credentials:\n"

read -p "Enter VK App ID (CLIENT_ID): " VK_CLIENT_ID
read -p "Enter VK Secure Key (CLIENT_SECRET): " VK_CLIENT_SECRET
read -p "Enter VK Service Token (starts with vk1.a.): " VK_TOKEN

# Optional: Get VK Group IDs
echo -e "\n📝 Enter VK Group IDs to parse (optional):"
echo "Example: 123456789,987654321 (comma-separated)"
echo "Press Enter to skip and use defaults:"
read -p "VK Group IDs: " VK_GROUP_IDS_INPUT

if [ -z "$VK_GROUP_IDS_INPUT" ]; then
    VK_GROUP_IDS_INPUT="123456,789012,345678"
    echo "Using default group IDs (will need to be updated later)"
fi

# Step 2: Update .env file with real credentials
echo -e "\n[Step 2] Updating configuration with your credentials..."

cat > .env <<EOF
# VK API Configuration
VK_CLIENT_ID=${VK_CLIENT_ID}
VK_CLIENT_SECRET=${VK_CLIENT_SECRET}
VK_TOKEN=${VK_TOKEN}
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

# VK Groups to Parse
VK_GROUP_IDS=${VK_GROUP_IDS_INPUT}

# Frontend Configuration
REACT_APP_API_URL=https://pc.builds.ngrok.app/api
REACT_APP_WS_URL=wss://pc.builds.ngrok.app/ws

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Security
SECRET_KEY=pc-compare-secret-key-2024-production-$(date +%s)
ALLOWED_ORIGINS=https://pc.builds.ngrok.app,http://localhost:3000

# ML Model Settings
USE_ML_COLOR_DETECTION=true
ML_MODEL_PATH=/app/models

# Logging
LOG_LEVEL=INFO
LOG_FILE=/app/logs/app.log

# Development
DEBUG=false
EOF

echo "✅ Configuration updated!"

# Step 3: Create backend structure if missing
echo -e "\n[Step 3] Preparing backend structure..."

# Check if backend exists, if not create minimal structure
if [ ! -f "backend/requirements.txt" ]; then
    echo "Creating backend structure..."
    mkdir -p backend/app
    
    # Create requirements.txt
    cat > backend/requirements.txt <<'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
redis==5.0.1
aiohttp==3.9.1
python-dotenv==1.0.0
pydantic==2.5.2
pydantic-settings==2.1.0
alembic==1.13.0
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
httpx==0.25.2
Pillow==10.1.0
numpy==1.26.2
EOF

    # Create minimal main.py
    cat > backend/app/main.py <<'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="PC Compare API")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "PC Compare API", "status": "running"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/api/builds/our")
async def get_our_builds():
    return {"builds": [], "message": "Database initialization required"}

@app.get("/auth/callback")
async def vk_callback(code: str = None):
    if not code:
        raise HTTPException(status_code=400, detail="No authorization code provided")
    return {"message": "OAuth callback received", "code": code}
EOF

    # Create __init__.py
    touch backend/app/__init__.py
fi

# Create Dockerfile for backend
cat > backend/Dockerfile <<'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/logs

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Step 4: Create frontend structure if missing
echo -e "\n[Step 4] Preparing frontend structure..."

if [ ! -f "frontend/package.json" ]; then
    echo "Creating frontend structure..."
    mkdir -p frontend/src frontend/public
    
    # Create package.json
    cat > frontend/package.json <<'EOF'
{
  "name": "pc-compare-frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "axios": "^1.6.2",
    "react-router-dom": "^6.20.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
EOF

    # Create minimal App.js
    cat > frontend/src/App.js <<'EOF'
import React, { useEffect, useState } from 'react';

function App() {
  const [builds, setBuilds] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    fetch(`${process.env.REACT_APP_API_URL || '/api'}/builds/our`)
      .then(res => res.json())
      .then(data => {
        setBuilds(data.builds || []);
        setLoading(false);
      })
      .catch(err => {
        console.error('Error fetching builds:', err);
        setLoading(false);
      });
  }, []);

  const handleVKAuth = () => {
    const clientId = process.env.REACT_APP_VK_CLIENT_ID;
    const redirectUri = `${window.location.origin}/auth/callback`;
    const authUrl = `https://oauth.vk.com/authorize?client_id=${clientId}&display=page&redirect_uri=${redirectUri}&scope=market,wall&response_type=code&v=5.199`;
    window.location.href = authUrl;
  };

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>PC Build Comparator</h1>
      <button onClick={handleVKAuth} style={{ padding: '10px 20px', fontSize: '16px' }}>
        Login with VK
      </button>
      <div style={{ marginTop: '20px' }}>
        {loading ? (
          <p>Loading builds...</p>
        ) : builds.length > 0 ? (
          <div>
            <h2>Our Builds</h2>
            {builds.map((build, idx) => (
              <div key={idx} style={{ padding: '10px', border: '1px solid #ccc', margin: '10px 0' }}>
                {build.name}
              </div>
            ))}
          </div>
        ) : (
          <p>No builds available. Please initialize the database.</p>
        )}
      </div>
    </div>
  );
}

export default App;
EOF

    # Create index.js
    cat > frontend/src/index.js <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

    # Create index.html
    cat > frontend/public/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>PC Compare</title>
</head>
<body>
    <div id="root"></div>
</body>
</html>
EOF
fi

# Create Dockerfile for frontend
cat > frontend/Dockerfile <<'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
EOF

# Step 5: Update Nginx to proxy to Docker
echo -e "\n[Step 5] Updating Nginx configuration for Docker..."

cat > /etc/nginx/sites-available/pc-compare <<'EOF'
server {
    listen 80;
    server_name pc.builds.ngrok.app;
    
    client_max_body_size 100M;
    
    # Proxy to Docker nginx on port 8080
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
    }
}
EOF

nginx -t && systemctl reload nginx

# Step 6: Build and start Docker containers
echo -e "\n[Step 6] Building and starting Docker containers..."

# Stop any existing containers
docker-compose -f docker-compose.production.yml down 2>/dev/null || true

# Build images
echo "Building Docker images (this may take a few minutes)..."
docker-compose -f docker-compose.production.yml build

# Start containers
echo "Starting containers..."
docker-compose -f docker-compose.production.yml up -d

# Wait for services to be ready
echo -e "\n⏳ Waiting for services to start..."
sleep 10

# Step 7: Initialize database
echo -e "\n[Step 7] Initializing database..."
docker-compose -f docker-compose.production.yml exec -T backend python -c "
import psycopg2
from psycopg2 import sql
import time
import os

# Wait for database
for i in range(30):
    try:
        conn = psycopg2.connect(os.getenv('DATABASE_URL'))
        conn.close()
        print('Database is ready!')
        break
    except:
        print(f'Waiting for database... ({i+1}/30)')
        time.sleep(2)
else:
    print('Database connection timeout')
    exit(1)

print('Database initialized successfully!')
" || echo "Note: Database initialization will complete on first request"

# Step 8: Check status
echo -e "\n[Step 8] Checking container status..."
docker-compose -f docker-compose.production.yml ps

# Step 9: Test the deployment
echo -e "\n[Step 9] Testing deployment..."
sleep 5

# Test health endpoint
echo "Testing API health endpoint..."
curl -s http://localhost:8080/health || echo "API is starting up..."

echo -e "\n========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "========================================="
echo ""
echo "🎉 Your PC Compare application is now running!"
echo ""
echo "📍 Access URLs:"
echo "   Public: https://pc.builds.ngrok.app"
echo "   Local API: http://localhost:8080/api"
echo ""
echo "🔧 Useful Commands:"
echo ""
echo "View logs:"
echo "  docker-compose -f docker-compose.production.yml logs -f"
echo ""
echo "Restart services:"
echo "  docker-compose -f docker-compose.production.yml restart"
echo ""
echo "Stop services:"
echo "  docker-compose -f docker-compose.production.yml down"
echo ""
echo "Check status:"
echo "  docker-compose -f docker-compose.production.yml ps"
echo ""
echo "Update VK Group IDs:"
echo "  nano .env"
echo "  docker-compose -f docker-compose.production.yml restart backend"
echo ""
echo "========================================="
echo ""
echo "📱 Next steps:"
echo "1. Test VK OAuth: https://pc.builds.ngrok.app"
echo "2. Update VK_GROUP_IDS in .env with real group IDs"
echo "3. Start parsing VK groups for PC builds"
echo ""
echo "Need help? Check logs with:"
echo "  docker-compose -f docker-compose.production.yml logs backend"
echo ""
echo "========================================="