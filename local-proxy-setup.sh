#!/bin/bash

# Local proxy setup for Mac to forward ngrok to remote server
# This runs on your Mac to proxy pc.builds.ngrok.app to your server

echo "========================================="
echo "Local Proxy Setup for pc.builds.ngrok.app"
echo "Forwarding to server: 37.220.82.104"
echo "========================================="

# Check if nginx is installed on Mac
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx via Homebrew..."
    brew install nginx
fi

# Stop any existing nginx
echo "Stopping existing nginx..."
sudo nginx -s stop 2>/dev/null || true

# Create nginx config for proxying to remote server
echo "Creating nginx proxy configuration..."

cat > /tmp/ngrok-proxy.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name localhost pc.builds.ngrok.app;
        
        client_max_body_size 100M;
        
        # Proxy everything to remote server
        location / {
            proxy_pass http://37.220.82.104:80;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
    }
}
EOF

# Start nginx with custom config
echo "Starting nginx proxy on port 80..."
sudo nginx -c /tmp/ngrok-proxy.conf

echo ""
echo "========================================="
echo "✅ LOCAL PROXY CONFIGURED!"
echo "========================================="
echo ""
echo "Nginx is now running on your Mac on port 80"
echo "It will forward all requests to 37.220.82.104"
echo ""
echo "Ngrok should now work with pc.builds.ngrok.app"
echo ""
echo "To stop the proxy:"
echo "  sudo nginx -s stop"
echo ""
echo "To check if it's working:"
echo "  curl http://localhost/health"
echo ""
echo "========================================="