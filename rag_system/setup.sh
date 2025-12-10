#!/bin/bash
# Setup script for RAG system

set -e

echo "================================================"
echo "TrayMe RAG System Setup"
echo "================================================"
echo ""

# Check Python version
echo "Checking Python version..."
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Found Python $python_version"

# Check if Python 3.8+
major=$(echo $python_version | cut -d. -f1)
minor=$(echo $python_version | cut -d. -f2)

if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 8 ]); then
    echo "Error: Python 3.8 or higher is required"
    exit 1
fi

echo "✓ Python version OK"
echo ""

# Create virtual environment
echo "Creating virtual environment..."
if [ -d "venv" ]; then
    echo "Virtual environment already exists. Skipping..."
else
    python3 -m venv venv
    echo "✓ Virtual environment created"
fi
echo ""

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate
echo "✓ Virtual environment activated"
echo ""

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt

echo "✓ Dependencies installed"
echo ""

# Create .env file if it doesn't exist
if [ ! -f "config/.env" ]; then
    echo "Creating configuration file..."
    cp config/config.env.example config/.env
    echo "✓ Configuration file created at config/.env"
    echo ""
    echo "⚠️  IMPORTANT: Edit config/.env and add your API key!"
    echo ""
else
    echo "✓ Configuration file already exists"
    echo ""
fi

# Create database directory
echo "Creating database directory..."
mkdir -p database/vector_db
echo "✓ Database directory created"
echo ""

echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Edit config/.env and add your API key"
echo "   - For OpenAI: OPENAI_API_KEY=sk-..."
echo "   - For Cohere: COHERE_API_KEY=..."
echo "   - Or use EMBEDDING_PROVIDER=local (no API key needed)"
echo ""
echo "2. Index the repository:"
echo "   python scripts/index_repository.py /path/to/TrayMe"
echo ""
echo "3. Try a query:"
echo "   python scripts/query.py 'How does clipboard work?'"
echo ""
echo "4. Or use the Python API:"
echo "   from rag_system import RAGAPI"
echo "   api = RAGAPI()"
echo "   results = api.search('your query')"
echo ""
echo "See README.md for more details."
echo ""
