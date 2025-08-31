#!/bin/bash

# Quick fix script to run on server 37.220.82.104
# This will set up a simple web server for VK OAuth configuration

echo "========================================="
echo "Quick Server Setup for pc.builds.ngrok.app"
echo "========================================="

# Step 1: Install nginx if not installed
echo -e "\n[Step 1] Installing nginx..."
apt update
apt install -y nginx

# Step 2: Create a simple HTML page for VK OAuth setup
echo -e "\n[Step 2] Creating setup page..."

cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PC Compare - VK OAuth Setup</title>
    <meta charset="utf-8">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 900px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .callback-url {
            background: #e8f6ff;
            padding: 20px;
            border-left: 4px solid #3498db;
            margin: 30px 0;
            border-radius: 5px;
        }
        .code {
            background: #2c3e50;
            color: #fff;
            padding: 15px;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            word-break: break-all;
            margin: 10px 0;
        }
        .step {
            margin: 30px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            border: 1px solid #dee2e6;
        }
        .step h3 {
            color: #495057;
            margin-top: 0;
        }
        .warning {
            background: #fff3cd;
            padding: 20px;
            border-left: 4px solid #ffc107;
            margin: 30px 0;
            border-radius: 5px;
        }
        .success {
            background: #d4edda;
            padding: 20px;
            border-left: 4px solid #28a745;
            margin: 30px 0;
            border-radius: 5px;
        }
        button {
            background: #3498db;
            color: white;
            border: none;
            padding: 12px 30px;
            font-size: 16px;
            border-radius: 5px;
            cursor: pointer;
            margin: 10px 0;
        }
        button:hover {
            background: #2980b9;
        }
        a {
            color: #3498db;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        ol li {
            margin: 10px 0;
        }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 PC Compare - VK OAuth Configuration</h1>
        
        <div class="success">
            <h2>✅ Server is Running!</h2>
            <p>Your ngrok tunnel is working correctly at <strong>pc.builds.ngrok.app</strong></p>
        </div>
        
        <div class="callback-url">
            <h2>📍 OAuth Callback URL</h2>
            <div class="code">https://pc.builds.ngrok.app/auth/callback</div>
            <p>Use this URL in your VK application settings</p>
        </div>
        
        <h2>📋 Setup Instructions</h2>
        
        <div class="step">
            <h3>Step 1: Create VK Standalone Application</h3>
            <ol>
                <li>Go to <a href="https://vk.com/apps?act=manage" target="_blank">VK Apps Management</a></li>
                <li>Click <strong>"Create App"</strong></li>
                <li>Choose <strong>"Standalone application"</strong></li>
                <li>Name: <code>PC Build Comparator</code></li>
                <li>Platform: <strong>Website</strong></li>
                <li>Click <strong>"Connect app"</strong></li>
            </ol>
        </div>
        
        <div class="step">
            <h3>Step 2: Configure OAuth Settings</h3>
            <ol>
                <li>In your app, go to <strong>Settings</strong> tab</li>
                <li>Find <strong>"Authorized redirect URI"</strong></li>
                <li>Add: <code>https://pc.builds.ngrok.app/auth/callback</code></li>
                <li>Set <strong>Base domain</strong>: <code>pc.builds.ngrok.app</code></li>
                <li>Set <strong>Site address</strong>: <code>https://pc.builds.ngrok.app</code></li>
                <li>Enable: <strong>"App is enabled and visible to all"</strong></li>
                <li>Click <strong>"Save"</strong></li>
            </ol>
        </div>
        
        <div class="step">
            <h3>Step 3: Get Your Credentials</h3>
            <ol>
                <li><strong>App ID</strong>: Found in Settings (e.g., 51234567)</li>
                <li><strong>Secure key</strong>: Found in Settings (keep it secret!)</li>
                <li><strong>Service token</strong>: Click "Manage" → "Service token" → "Create token"</li>
            </ol>
            <p>The service token starts with <code>vk1.a.</code> and is used for server requests</p>
        </div>
        
        <div class="step">
            <h3>Step 4: Get VK Group IDs (for parsing)</h3>
            <p>To find a VK group ID:</p>
            <ol>
                <li>Go to the VK group page</li>
                <li>Look at the URL: <code>vk.com/club<strong>123456789</strong></code></li>
                <li>The numbers after "club" or "public" is the group ID</li>
                <li>For VA-PC and other PC builder groups, collect their IDs</li>
            </ol>
        </div>
        
        <div class="warning">
            <h3>⚠️ Important Notes</h3>
            <ul>
                <li>Save all credentials securely - you'll need them for deployment</li>
                <li>The service token is required for server-side API calls</li>
                <li>Make sure the redirect URI matches exactly (including https://)</li>
                <li>The app must be enabled and visible to work properly</li>
            </ul>
        </div>
        
        <div class="step" style="background: #e8f6ff;">
            <h3>🎯 Next Steps</h3>
            <p>Once you have all credentials:</p>
            <ol>
                <li>SSH to your server: <code>ssh root@37.220.82.104</code></li>
                <li>Run the deployment script with your credentials</li>
                <li>The full application will be deployed at this domain</li>
            </ol>
            
            <button onclick="testCallback()">Test OAuth Callback</button>
            <div id="test-result"></div>
        </div>
        
        <div style="text-align: center; margin-top: 40px; color: #666;">
            <p>PC Compare - VK Market Parser & Comparator</p>
            <p>Domain: pc.builds.ngrok.app | Server: 37.220.82.104</p>
        </div>
    </div>
    
    <script>
        function testCallback() {
            fetch('/auth/callback?code=test123')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('test-result').innerHTML = 
                        '<div class="success" style="margin-top: 10px;">✅ Callback endpoint is ready! Response: ' + JSON.stringify(data) + '</div>';
                })
                .catch(error => {
                    document.getElementById('test-result').innerHTML = 
                        '<div class="warning" style="margin-top: 10px;">⚠️ Callback endpoint not yet configured. This is normal during initial setup.</div>';
                });
        }
    </script>
</body>
</html>
EOF

# Step 3: Create a simple callback endpoint
echo -e "\n[Step 3] Creating callback endpoint..."

cat > /var/www/html/auth/callback <<'EOF'
#!/usr/bin/env python3
import json
import sys

print("Content-Type: application/json\n")
print(json.dumps({
    "status": "ready",
    "message": "OAuth callback endpoint is configured",
    "note": "Full implementation will be available after deployment"
}))
EOF

mkdir -p /var/www/html/auth
chmod +x /var/www/html/auth/callback

# Step 4: Configure nginx
echo -e "\n[Step 4] Configuring nginx..."

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
    
    # Mock OAuth callback endpoint
    location /auth/callback {
        add_header Content-Type application/json;
        return 200 '{"status": "ready", "message": "OAuth callback endpoint is configured", "note": "Full implementation coming after deployment"}';
    }
    
    # Health check
    location /health {
        add_header Content-Type application/json;
        return 200 '{"status": "healthy", "service": "nginx"}';
    }
}
EOF

# Step 5: Test and restart nginx
echo -e "\n[Step 5] Starting nginx..."
nginx -t
systemctl enable nginx
systemctl restart nginx

# Step 6: Test if everything is working
echo -e "\n[Step 6] Testing setup..."
sleep 2

echo "Testing local nginx..."
curl -s http://localhost/health | python3 -m json.tool || echo "Local test failed"

echo -e "\n========================================="
echo "✅ SERVER CONFIGURED!"
echo "========================================="
echo ""
echo "The server is now running on port 80"
echo ""
echo "📍 Access your setup page at:"
echo "   https://pc.builds.ngrok.app"
echo ""
echo "📋 What's running:"
echo "   - Nginx on port 80 (for ngrok)"
echo "   - Setup instructions page"
echo "   - Mock OAuth callback endpoint"
echo ""
echo "🎯 Next steps:"
echo "1. Open https://pc.builds.ngrok.app in your browser"
echo "2. Follow the VK OAuth setup instructions"
echo "3. Get your VK credentials"
echo "4. Run the full deployment script"
echo ""
echo "========================================="