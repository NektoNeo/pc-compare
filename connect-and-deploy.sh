#!/bin/bash

echo "Connecting to server and deploying PC Compare..."
echo "Server: 37.220.82.104"
echo "Domain: pc.builds.ngrok.app"

# Copy deployment script to server
scp deploy-server.sh root@37.220.82.104:/tmp/

# Connect and execute
ssh root@37.220.82.104 << 'ENDSSH'
cd /tmp
chmod +x deploy-server.sh
./deploy-server.sh
ENDSSH

echo "Deployment initiated. Please check the server for completion status."