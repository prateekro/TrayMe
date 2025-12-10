# RAG System for TrayMe Repository

A Retrieval-Augmented Generation (RAG) system that enables fast and efficient retrieval over the TrayMe repository files for use with large language models (LLMs).

## 🎯 Overview

This RAG system allows you to:
- **Index** the entire TrayMe repository (Swift code, markdown docs, etc.)
- **Search** for relevant code and documentation using natural language queries
- **Retrieve** contextual information to enhance LLM responses
- **Integrate** seamlessly with LLMs for repository-aware Q&A

## ✨ Features

- **Multiple Embedding Providers**: OpenAI, Cohere, or local models (sentence-transformers)
- **Lightweight Vector Database**: LanceDB for serverless, local-first storage
- **Smart Text Chunking**: Intelligently splits code by functions/classes and markdown by sections
- **Fast Retrieval**: Optimized for low latency and resource usage
- **Error Handling**: Gracefully handles binary files, large files, and unsupported formats
- **Flexible API**: Easy-to-use Python API for LLM integration

## 📋 Prerequisites

- Python 3.8 or higher
- pip (Python package manager)
- API key for embedding provider (OpenAI, Cohere, or use local models)

## 🚀 Quick Start

### 1. Installation

```bash
cd /path/to/TrayMe/rag_system

# Install dependencies
pip install -r requirements.txt
```

### 2. Configuration

Copy the example configuration and add your API keys:

```bash
cp config/config.env.example config/.env
```

Edit `config/.env` and add your API key:

```bash
# For OpenAI (recommended)
EMBEDDING_PROVIDER=openai
OPENAI_API_KEY=your-api-key-here

# For Cohere (alternative)
# EMBEDDING_PROVIDER=cohere
# COHERE_API_KEY=your-api-key-here

# For local models (no API key needed, but slower)
# EMBEDDING_PROVIDER=local
```

### 3. Index the Repository

```bash
# Index from TrayMe root directory
cd /path/to/TrayMe
python rag_system/scripts/index_repository.py

# Or specify a path
python rag_system/scripts/index_repository.py /path/to/TrayMe
```

This will:
- Scan all supported files (`.swift`, `.md`, `.txt`, etc.)
- Generate embeddings for code and documentation
- Store them in the local vector database

**First-time indexing** takes 2-5 minutes depending on API speed.

### 4. Query the System

#### Command Line

```bash
# Basic query
python rag_system/scripts/query.py "How does clipboard management work?"

# Get more results
python rag_system/scripts/query.py "File storage implementation" --top-k 10

# Filter by file type
python rag_system/scripts/query.py "SwiftUI views" --file-filter "*.swift"

# Different output formats
python rag_system/scripts/query.py "Mouse tracking" --format markdown
python rag_system/scripts/query.py "Mouse tracking" --format json
```

#### Python API

```python
from rag_system import RAGAPI

# Initialize
api = RAGAPI()

# Search for relevant content
results = api.search("How does the drag and drop work?", top_k=5)
for result in results:
    print(f"File: {result['file_path']}")
    print(f"Content: {result['text'][:200]}...")
    print()

# Get formatted context for LLM
context = api.get_context("Explain the clipboard manager")
print(context)

# Answer questions (requires OpenAI API)
answer = api.answer_with_context("What file types are supported?")
print(answer)
```

#### Convenience Functions

```python
from rag_system import search, get_context, answer

# Quick search
results = search("NotesManager implementation")

# Get context for LLM prompt
context = get_context("How are files stored?", max_tokens=2000)

# Direct question answering
answer = answer("What are the main features of TrayMe?")
```

## 📁 Project Structure

```
rag_system/
├── config/
│   ├── config.yaml           # Main configuration
│   ├── config.env.example    # Environment variables template
│   └── config.py             # Configuration loader
├── scripts/
│   ├── embeddings.py         # Embedding provider implementations
│   ├── text_processor.py     # File reading and text chunking
│   ├── vector_db.py          # Vector database interface
│   ├── index_repository.py   # Repository indexing script
│   ├── query.py              # Query interface
│   └── rag_api.py            # High-level API
├── database/
│   └── vector_db/            # LanceDB storage (created on first run)
├── requirements.txt          # Python dependencies
└── README.md                 # This file
```

## ⚙️ Configuration

### Embedding Providers

#### OpenAI (Recommended)
- **Model**: `text-embedding-3-small` (1536 dimensions)
- **Pros**: High quality, fast, cost-effective
- **Cons**: Requires API key and internet
- **Cost**: ~$0.02 per 1M tokens

```bash
EMBEDDING_PROVIDER=openai
OPENAI_API_KEY=sk-...
```

#### Cohere
- **Model**: `embed-english-v3.0` (1024 dimensions)
- **Pros**: High quality, good for semantic search
- **Cons**: Requires API key and internet

```bash
EMBEDDING_PROVIDER=cohere
COHERE_API_KEY=...
```

#### Local (sentence-transformers)
- **Model**: `all-MiniLM-L6-v2` (384 dimensions)
- **Pros**: Free, offline, no API key
- **Cons**: Slower, lower quality, requires GPU for speed

```bash
EMBEDDING_PROVIDER=local
```

### Advanced Configuration

Edit `config/config.yaml` to customize:

```yaml
indexing:
  chunk_size: 1000              # Characters per chunk
  chunk_overlap: 200            # Overlap between chunks
  max_file_size_mb: 10          # Skip files larger than this
  supported_extensions:         # File types to index
    - .swift
    - .md
    - .txt
    - .json

retrieval:
  top_k: 5                      # Default number of results
  similarity_threshold: 0.7     # Minimum similarity score
```

## 🔧 Usage Examples

### Use Case 1: Code Search

```python
api = RAGAPI()

# Find files related to clipboard
results = api.search("clipboard history tracking", file_filter="*.swift")

for r in results:
    print(f"{r['file_path']}: {r['text'][:100]}")
```

### Use Case 2: Documentation Retrieval

```python
# Get all documentation about installation
context = api.get_context("installation and setup instructions")

# Use with your LLM
prompt = f"""Based on this repository documentation:

{context}

Question: How do I build and run TrayMe?
"""
```

### Use Case 3: Q&A with LLM Integration

```python
# Direct answer using GPT-4
answer = api.answer_with_context(
    "What are the three main features of TrayMe?",
    model="gpt-4"
)
print(answer)
```

### Use Case 4: Incremental Updates

```python
from rag_system.scripts.index_repository import RepositoryIndexer
from rag_system.config.config import Config

config = Config()
indexer = RepositoryIndexer(config)

# Update a single file after editing
indexer.update_file("/path/to/TrayMe/TrayMe/Models/FileItem.swift", "/path/to/TrayMe")
```

## 🎛️ Command Line Interface

### Index Repository

```bash
# Index current directory
python scripts/index_repository.py

# Index specific path
python scripts/index_repository.py /path/to/repo

# Force reindex (clear and rebuild)
python scripts/index_repository.py --force

# Use custom config
python scripts/index_repository.py --config /path/to/config.yaml
```

### Query

```bash
# Basic query
python scripts/query.py "your query here"

# With options
python scripts/query.py "query" \
    --top-k 10 \
    --threshold 0.8 \
    --format markdown \
    --file-filter "*.swift"

# Show database statistics
python scripts/query.py "query" --stats
```

### API Demo

```bash
# Search only
python scripts/rag_api.py "How does mouse tracking work?"

# Get context for LLM
python scripts/rag_api.py "File storage" --context-only

# Answer with GPT-4 (requires OpenAI API)
python scripts/rag_api.py "What is TrayMe?" --answer
```

## 🚨 Error Handling

The system handles various edge cases:

### Binary Files
- Automatically skipped (images, executables, etc.)
- Warning logged, continues processing

### Large Files
- Files > 10MB skipped by default
- Configurable via `max_file_size_mb`

### Unsupported Formats
- Only indexes configured extensions
- See `supported_extensions` in config

### API Errors
- Retries with exponential backoff
- Graceful degradation
- Detailed error messages

### Empty Results
```python
results = api.search("nonexistent query")
if not results:
    print("No relevant content found")
```

## 🔍 Performance Optimization

### Indexing Performance
- **Batch processing**: Embeddings generated in batches
- **Parallel processing**: Multiple workers for file I/O
- **Smart chunking**: Preserves code structure and context

**Expected performance**:
- ~30 files/minute with OpenAI API
- ~50 files/minute with local embeddings (GPU)
- TrayMe repository: ~2-3 minutes total

### Query Performance
- **Vector search**: <50ms for top-5 results
- **Embedding generation**: ~100-200ms (OpenAI API)
- **Total latency**: <300ms end-to-end

### Resource Usage
- **Memory**: ~100-200MB (database loaded)
- **Disk**: ~5-10MB for embeddings
- **CPU**: Minimal (vector search is fast)

## 📊 Database Management

### View Statistics

```python
api = RAGAPI()
stats = api.get_stats()

print(f"Total embeddings: {stats['total_embeddings']}")
print(f"Indexed files: {stats['indexed_files']}")
print(f"Files: {stats['files']}")
```

### Clear Database

```python
from rag_system.scripts.vector_db import VectorDatabase

db = VectorDatabase("./rag_system/database/vector_db")
db.open_table()
db.clear()
```

### Rebuild Index

```bash
# Complete reindex
python scripts/index_repository.py --force
```

## 🧪 Testing

### Test Indexing

```bash
# Index repository
python scripts/index_repository.py

# Verify
python scripts/query.py "test" --stats
```

### Test Queries

```python
from rag_system import RAGAPI

api = RAGAPI()

# Test various queries
queries = [
    "clipboard manager implementation",
    "file drag and drop",
    "SwiftUI views",
    "mouse tracking"
]

for query in queries:
    results = api.search(query, top_k=3)
    print(f"Query: {query}")
    print(f"Results: {len(results)}")
    print()
```

## 🐛 Troubleshooting

### "Table does not exist" Error
**Solution**: Run indexing first:
```bash
python scripts/index_repository.py
```

### "API key required" Error
**Solution**: Set API key in `.env`:
```bash
echo "OPENAI_API_KEY=sk-..." >> config/.env
```

### No Results Found
**Possible causes**:
1. Threshold too high - try `--threshold 0.5`
2. Query too specific - try broader terms
3. Database empty - reindex with `--force`

### Slow Indexing
**Solutions**:
1. Use OpenAI API instead of local models
2. Reduce `batch_size` if memory limited
3. Increase `chunk_size` to reduce chunks

### Import Errors
**Solution**: Install dependencies:
```bash
pip install -r requirements.txt
```

## 🔐 Security & Privacy

- ✅ **Local storage**: All embeddings stored locally
- ✅ **No data sharing**: Only API calls are to embedding providers
- ✅ **API key safety**: Stored in `.env` (git-ignored)
- ⚠️ **Sensitive code**: Be careful with proprietary code and public APIs

## 📈 Future Enhancements

- [ ] Hybrid search (keyword + semantic)
- [ ] Re-ranking with cross-encoders
- [ ] Incremental updates (watch for file changes)
- [ ] Web UI for browsing and searching
- [ ] Support for more file types (images with OCR, PDFs)
- [ ] Query caching for faster repeated searches
- [ ] Multi-language support

## 📝 License

Part of the TrayMe project. See main repository for license details.

## 🙋 Support

For issues or questions:
1. Check this README
2. Review configuration in `config/config.yaml`
3. Run with `--stats` to verify database state
4. Check error messages in console output

## 📚 Additional Resources

- [LanceDB Documentation](https://lancedb.github.io/lancedb/)
- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings)
- [Sentence Transformers](https://www.sbert.net/)
- [RAG Overview](https://python.langchain.com/docs/use_cases/question_answering/)

---

**Built with ❤️ for the TrayMe project**
