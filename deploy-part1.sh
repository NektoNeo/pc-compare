#!/bin/bash

# PC Compare Deployment Script - PART 1
# Подготовка инфраструктуры и получение URL для VK OAuth

echo "========================================="
echo "PC Compare Deployment - PART 1"
echo "Domain: pc.builds.ngrok.app"
echo "========================================="

# Step 1: Update system and install dependencies
echo -e "\n[Step 1] Installing system dependencies..."
apt update
apt install -y python3 python3-pip nginx git docker.io docker-compose curl

# Step 2: Clone repository
echo -e "\n[Step 2] Cloning repository..."
cd /opt
if [ -d "pc-compare" ]; then
    echo "Directory pc-compare already exists, removing..."
    rm -rf pc-compare
fi
git clone https://github.com/serjnavigatian/pc-compare.git pc-compare
cd pc-compare

# Step 3: Create temporary .env file with placeholders
echo -e "\n[Step 3] Creating temporary .env configuration..."
cat > .env <<'EOF'
# VK API Configuration - WILL BE FILLED IN PART 2
VK_CLIENT_ID=PLACEHOLDER_WILL_BE_FILLED
VK_CLIENT_SECRET=PLACEHOLDER_WILL_BE_FILLED
VK_TOKEN=PLACEHOLDER_WILL_BE_FILLED
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

# VK Groups to Parse (VA-PC and competitors)
VK_GROUP_IDS=123456,789012,345678

# Frontend Configuration
REACT_APP_API_URL=https://pc.builds.ngrok.app/api
REACT_APP_WS_URL=wss://pc.builds.ngrok.app/ws

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Security
SECRET_KEY=pc-compare-secret-key-2024-production
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

# Step 4: Create Nginx configuration for domain
echo -e "\n[Step 4] Configuring Nginx..."
cat > /etc/nginx/sites-available/pc-compare <<'EOF'
server {
    listen 80;
    server_name pc.builds.ngrok.app;
    
    client_max_body_size 100M;
    
    # Temporary landing page before Docker is ready
    location / {
        return 200 '<!DOCTYPE html>
<html>
<head>
    <title>PC Compare - Setup</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .container { background: #f5f5f5; padding: 30px; border-radius: 10px; }
        h1 { color: #333; }
        .callback-url { background: #e8f4f8; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
        .code { background: #fff; padding: 10px; border: 1px solid #ddd; font-family: monospace; word-break: break-all; }
        .step { margin: 20px 0; padding: 15px; background: #fff; border-radius: 5px; }
        .warning { background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 PC Compare Setup - Part 1 Complete!</h1>
        
        <div class="callback-url">
            <h2>✅ Your OAuth Callback URL is ready:</h2>
            <div class="code">https://pc.builds.ngrok.app/auth/callback</div>
        </div>
        
        <h2>📋 Now configure your VK Application:</h2>
        
        <div class="step">
            <h3>Step 1: Create VK Standalone Application</h3>
            <ol>
                <li>Go to <a href="https://vk.com/apps?act=manage" target="_blank">VK Apps Management</a></li>
                <li>Click "Create App" → Choose "Standalone application"</li>
                <li>Fill in app name: "PC Build Comparator"</li>
                <li>Choose platform: "Website"</li>
            </ol>
        </div>
        
        <div class="step">
            <h3>Step 2: Configure OAuth Settings</h3>
            <ol>
                <li>In app settings, go to "Settings" tab</li>
                <li>Add Authorized redirect URI: <code>https://pc.builds.ngrok.app/auth/callback</code></li>
                <li>Set Base domain: <code>pc.builds.ngrok.app</code></li>
                <li>Save settings</li>
            </ol>
        </div>
        
        <div class="step">
            <h3>Step 3: Get Your Credentials</h3>
            <ol>
                <li>Copy your App ID (CLIENT_ID)</li>
                <li>Copy your Secure key (CLIENT_SECRET)</li>
                <li>Generate Service token for server requests</li>
            </ol>
        </div>
        
        <div class="warning">
            <strong>⚠️ Important:</strong> Save these credentials! You will need them for Part 2 of the deployment.
        </div>
        
        <div class="step">
            <h3>Step 4: Run Part 2</h3>
            <p>Once you have your VK credentials, SSH back to the server and run:</p>
            <div class="code">cd /opt/pc-compare && ./deploy-part2.sh</div>
        </div>
    </div>
</body>
</html>';
        add_header Content-Type text/html;
    }
    
    # OAuth callback endpoint (will work after full deployment)
    location /auth/callback {
        return 200 '{"status": "waiting_for_deployment", "message": "Please complete Part 2 of deployment"}';
        add_header Content-Type application/json;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/pc-compare /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t
systemctl reload nginx

# Step 5: Prepare Docker directories
echo -e "\n[Step 5] Preparing Docker structure..."
mkdir -p docker/nginx
mkdir -p logs/nginx
mkdir -p backend
mkdir -p frontend

# Create Nginx config for Docker (will be used in Part 2)
cat > docker/nginx/nginx.conf <<'EOF'
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
        
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
    
    # WebSocket
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
    
    # Frontend
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
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
EOF

# Step 6: Create docker-compose for production
echo -e "\n[Step 6] Creating docker-compose.production.yml..."
cat > docker-compose.production.yml <<'EOF'
version: '3.8'

services:
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

  redis:
    image: redis:7-alpine
    container_name: pc-compare-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

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
      ALLOWED_ORIGINS: ${ALLOWED_ORIGINS}
    volumes:
      - ./backend:/app
      - ./logs:/app/logs
    ports:
      - "127.0.0.1:8001:8000"
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

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
    environment:
      REACT_APP_API_URL: ${REACT_APP_API_URL}
      REACT_APP_WS_URL: ${REACT_APP_WS_URL}

  nginx:
    image: nginx:alpine
    container_name: pc-compare-nginx
    restart: unless-stopped
    depends_on:
      - backend
      - frontend
    ports:
      - "8080:80"
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

# Step 7: Configure firewall
if command -v ufw &> /dev/null; then
    echo -e "\n[Step 7] Configuring firewall..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8080/tcp
fi

# Step 8: Enable Docker
echo -e "\n[Step 8] Enabling Docker service..."
systemctl enable docker
systemctl start docker

echo -e "\n========================================="
echo "PART 1 DEPLOYMENT COMPLETE!"
echo "========================================="
echo ""
echo "✅ Nginx is running and serving the setup page"
echo "✅ Your OAuth callback URL is ready:"
echo ""
echo "   https://pc.builds.ngrok.app/auth/callback"
echo ""
echo "📋 NEXT STEPS:"
echo ""
echo "1. Open in browser: https://pc.builds.ngrok.app"
echo "   You'll see detailed VK setup instructions there"
echo ""
echo "2. Create VK Standalone Application at:"
echo "   https://vk.com/apps?act=manage"
echo ""
echo "3. Configure VK App with:"
echo "   - Redirect URI: https://pc.builds.ngrok.app/auth/callback"
echo "   - Base domain: pc.builds.ngrok.app"
echo ""
echo "4. Get your credentials:"
echo "   - App ID (CLIENT_ID)"
echo "   - Secure key (CLIENT_SECRET)"
echo "   - Service token (for server requests)"
echo ""
echo "5. Once you have credentials, run Part 2:"
echo "   cd /opt/pc-compare && ./deploy-part2.sh"
echo ""
echo "========================================="

# Create Part 2 script
chmod +x deploy-part2.sh 2>/dev/null || true