#!/bin/bash

# Quick Start Script for VK PC Build Comparator

echo "========================================="
echo "  VK PC Build Comparator - Quick Start"
echo "========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your VK credentials!"
    echo ""
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Menu
echo "What would you like to do?"
echo "1) Start development environment"
echo "2) Start production environment"
echo "3) Stop all services"
echo "4) View logs"
echo "5) Initialize database"
echo "6) Run parser manually"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo "🚀 Starting development environment..."
        docker-compose up -d
        echo ""
        echo "✅ Services started!"
        echo "Frontend: http://localhost:3000"
        echo "Backend API: http://localhost:8000"
        echo "API Docs: http://localhost:8000/docs"
        ;;
    2)
        echo "🚀 Starting production environment..."
        docker-compose --profile production up -d
        echo ""
        echo "✅ Services started in production mode!"
        echo "Application: http://localhost"
        ;;
    3)
        echo "🛑 Stopping all services..."
        docker-compose down
        echo "✅ All services stopped"
        ;;
    4)
        echo "📋 Showing logs (press Ctrl+C to exit)..."
        docker-compose logs -f
        ;;
    5)
        echo "🗄️ Initializing database..."
        docker-compose exec backend python -c "from app.main import Base, engine; Base.metadata.create_all(bind=engine)"
        echo "✅ Database initialized"
        ;;
    6)
        echo "🔄 Running parser manually..."
        docker-compose exec backend python -m app.parser.unified_parser
        echo "✅ Parsing completed"
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "Need help? Check docs/DEPLOYMENT.md"
echo "========================================="
