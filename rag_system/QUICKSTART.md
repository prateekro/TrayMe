# RAG System Quick Start Guide

Get up and running with the TrayMe RAG system in 5 minutes.

## Prerequisites

- Python 3.8+
- pip
- An API key from OpenAI, Cohere, or use local models (free)

## Installation (2 minutes)

```bash
cd /path/to/TrayMe/rag_system

# Run the setup script
./setup.sh
```

This will:
1. Create a Python virtual environment
2. Install all dependencies
3. Create configuration files

## Configuration (1 minute)

Edit `config/.env` and add your API key:

```bash
# For OpenAI (recommended - fast and high quality)
EMBEDDING_PROVIDER=openai
OPENAI_API_KEY=sk-your-key-here

# OR for local models (free but slower)
# EMBEDDING_PROVIDER=local
```

## Index Repository (1-2 minutes)

```bash
# Make sure you're in the virtual environment
source venv/bin/activate

# Index the TrayMe repository
cd /path/to/TrayMe
python rag_system/scripts/index_repository.py
```

Wait for indexing to complete (~2-3 minutes).

## Try It Out! (1 minute)

### Quick Query

```bash
# Ask a question
python rag_system/scripts/query.py "How does clipboard management work?"
```

### Python API

```python
from rag_system import RAGAPI

api = RAGAPI()

# Search
results = api.search("drag and drop implementation")
for r in results:
    print(f"{r['file_path']}: {r['text'][:100]}")

# Get context for LLM
context = api.get_context("What are the main features?")
print(context)
```

### Run Examples

```bash
python rag_system/examples.py
```

## Common Commands

```bash
# Search repository
python scripts/query.py "your query"

# Search specific files
python scripts/query.py "SwiftUI views" --file-filter "*.swift"

# Get more results
python scripts/query.py "clipboard" --top-k 10

# View database stats
python scripts/query.py "test" --stats

# Reindex repository
python scripts/index_repository.py --force
```

## Troubleshooting

### "Table does not exist"
Run indexing first: `python scripts/index_repository.py`

### "API key required"
Add your API key in `config/.env`

### "No module named 'lancedb'"
Install dependencies: `pip install -r requirements.txt`

## What's Next?

- Read the full [README.md](README.md) for detailed documentation
- Check out [examples.py](examples.py) for usage patterns
- Integrate with your LLM workflows

## Support

Having issues? Check:
1. Python version: `python3 --version` (must be 3.8+)
2. Dependencies installed: `pip list | grep lancedb`
3. Config file exists: `ls config/.env`
4. Database indexed: `python scripts/query.py "test" --stats`

---

**You're all set! Happy querying! 🚀**
