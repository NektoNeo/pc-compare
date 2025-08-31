#!/bin/bash

# This script should be run on the REMOTE SERVER (37.220.82.104)
# It sets up nginx to serve the VK OAuth setup page

echo "========================================="
echo "Remote Server Setup for pc.builds.ngrok.app"
echo "This script runs on server 37.220.82.104"
echo "========================================="

# Update and install nginx
echo "[1/4] Installing nginx..."
apt update
apt install -y nginx

# Create the setup page
echo "[2/4] Creating setup page..."
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PC Compare - Setup</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; background: #f0f2f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #1877f2; }
        .success { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .url-box { background: #f8f9fa; padding: 15px; border-left: 4px solid #1877f2; margin: 20px 0; }
        .code { background: #263238; color: #aed581; padding: 12px; border-radius: 4px; font-family: monospace; }
        .step { background: #f8f9fa; padding: 20px; margin: 20px 0; border-radius: 8px; }
        .step h3 { margin-top: 0; color: #495057; }
        button { background: #1877f2; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        button:hover { background: #166fe5; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 PC Compare Setup</h1>
        
        <div class="success">
            <strong>✅ Server is running!</strong><br>
            Domain: pc.builds.ngrok.app
        </div>
        
        <div class="url-box">
            <strong>OAuth Callback URL for VK:</strong>
            <div class="code">https://pc.builds.ngrok.app/auth/callback</div>
        </div>
        
        <div class="step">
            <h3>1️⃣ Create VK App</h3>
            <p>Go to <a href="https://vk.com/apps?act=manage" target="_blank">vk.com/apps</a> → Create App → Standalone application</p>
        </div>
        
        <div class="step">
            <h3>2️⃣ Configure OAuth</h3>
            <p>Add redirect URI: <code>https://pc.builds.ngrok.app/auth/callback</code></p>
            <p>Base domain: <code>pc.builds.ngrok.app</code></p>
        </div>
        
        <div class="step">
            <h3>3️⃣ Get Credentials</h3>
            <p>Copy your App ID, Secure Key, and create a Service Token</p>
        </div>
        
        <button onclick="test()">Test Callback</button>
        <div id="result"></div>
    </div>
    
    <script>
        function test() {
            fetch('/auth/callback?code=test')
                .then(r => r.json())
                .then(d => document.getElementById('result').innerHTML = '<div class="success">Callback works! ' + JSON.stringify(d) + '</div>')
                .catch(e => document.getElementById('result').innerHTML = '<div class="url-box">Callback will be ready after full deployment</div>');
        }
    </script>
</body>
</html>
EOF

# Configure nginx
echo "[3/4] Configuring nginx..."
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html;
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /auth/callback {
        add_header Content-Type application/json;
        return 200 '{"status":"ready","message":"OAuth callback endpoint configured"}';
    }
    
    location /health {
        add_header Content-Type application/json;
        return 200 '{"status":"healthy"}';
    }
}
EOF

# Restart nginx
echo "[4/4] Starting nginx..."
systemctl restart nginx
systemctl enable nginx

echo ""
echo "========================================="
echo "✅ REMOTE SERVER READY!"
echo "========================================="
echo "Nginx is running on port 80"
echo "Setup page is available"
echo "========================================="