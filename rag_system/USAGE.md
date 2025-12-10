# RAG System Usage Guide

Comprehensive guide to using the TrayMe RAG system.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Advanced Queries](#advanced-queries)
- [Python API](#python-api)
- [LLM Integration](#llm-integration)
- [Batch Processing](#batch-processing)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

## Basic Usage

### Simple Search

```bash
# Basic search
python scripts/query.py "clipboard manager"

# Get top 10 results
python scripts/query.py "clipboard manager" --top-k 10

# Filter by similarity threshold
python scripts/query.py "clipboard manager" --threshold 0.8
```

### File Filtering

```bash
# Search only Swift files
python scripts/query.py "SwiftUI views" --file-filter "*.swift"

# Search only documentation
python scripts/query.py "installation" --file-filter "*.md"

# Search specific directory
python scripts/query.py "models" --file-filter "*/Models/*"
```

### Output Formats

```bash
# Plain text (default)
python scripts/query.py "clipboard"

# JSON format
python scripts/query.py "clipboard" --format json

# Markdown format
python scripts/query.py "clipboard" --format markdown

# LLM-optimized format
python scripts/query.py "clipboard" --format llm
```

## Advanced Queries

### Natural Language Queries

The RAG system understands natural language:

```bash
# Questions
python scripts/query.py "How does drag and drop work?"

# Concepts
python scripts/query.py "file storage architecture"

# Features
python scripts/query.py "What features does the clipboard manager have?"

# Implementation details
python scripts/query.py "Where is mouse tracking implemented?"
```

### Multi-term Queries

```bash
# Multiple keywords
python scripts/query.py "SwiftUI panel animation"

# Technical terms
python scripts/query.py "NSPanel NSHostingView integration"

# Function names
python scripts/query.py "clipboardManager save history"
```

### Semantic Search

The system finds semantically similar content:

```bash
# Finds "clipboard", "copy", "paste", etc.
python scripts/query.py "clipboard operations"

# Finds "drag", "drop", "file handling"
python scripts/query.py "file transfer"

# Finds "UI", "view", "design"
python scripts/query.py "user interface"
```

## Python API

### Quick Start

```python
from rag_system import RAGAPI

# Initialize
api = RAGAPI()

# Search
results = api.search("clipboard manager")

# Print results
for result in results:
    print(f"File: {result['file_path']}")
    print(f"Text: {result['text']}")
    print(f"Similarity: {1 - result.get('_distance', 0):.3f}")
    print()
```

### Search with Options

```python
# Custom parameters
results = api.search(
    query="SwiftUI views",
    top_k=10,
    threshold=0.7,
    file_filter="*.swift"
)

# Check if results found
if results:
    print(f"Found {len(results)} results")
else:
    print("No results found")
```

### Get Context for LLM

```python
# Get formatted context
context = api.get_context(
    query="How does clipboard work?",
    max_tokens=4000
)

# Use in your LLM prompt
prompt = f"""Based on this repository:

{context}

Question: How is clipboard history stored?
Answer:"""
```

### Direct Q&A

```python
# Ask questions and get answers (requires OpenAI API)
answer = api.answer_with_context(
    question="What are the main features of TrayMe?",
    model="gpt-4"
)

print(answer)
```

### Database Stats

```python
# Get statistics
stats = api.get_stats()

print(f"Total embeddings: {stats['total_embeddings']}")
print(f"Indexed files: {stats['indexed_files']}")
print(f"Provider: {stats['embedding_provider']}")

# List all indexed files
for file_path in stats['files']:
    print(file_path)
```

## LLM Integration

### OpenAI Integration

```python
from rag_system import RAGAPI
from openai import OpenAI

# Initialize
api = RAGAPI()
client = OpenAI(api_key="your-key")

# Get relevant context
query = "How does mouse tracking work?"
context = api.get_context(query, max_tokens=3000)

# Create prompt
messages = [
    {"role": "system", "content": "You are a helpful coding assistant."},
    {"role": "user", "content": f"Repository context:\n{context}\n\nQuestion: {query}"}
]

# Get response
response = client.chat.completions.create(
    model="gpt-4",
    messages=messages
)

print(response.choices[0].message.content)
```

### Anthropic Claude Integration

```python
from rag_system import RAGAPI
import anthropic

api = RAGAPI()
client = anthropic.Anthropic(api_key="your-key")

context = api.get_context("file storage system")

response = client.messages.create(
    model="claude-3-opus-20240229",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": f"Context:\n{context}\n\nQuestion: Explain the file storage system"
    }]
)

print(response.content)
```

### LangChain Integration

```python
from rag_system import RAGAPI
from langchain.llms import OpenAI
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate

api = RAGAPI()

# Define prompt template
template = """Use the following repository context to answer the question.

Context:
{context}

Question: {question}

Answer:"""

prompt = PromptTemplate(
    input_variables=["context", "question"],
    template=template
)

# Create chain
llm = OpenAI(temperature=0)
chain = LLMChain(llm=llm, prompt=prompt)

# Run query
question = "How does the clipboard manager work?"
context = api.get_context(question)

answer = chain.run(context=context, question=question)
print(answer)
```

## Batch Processing

### Process Multiple Queries

```python
from rag_system import RAGAPI

api = RAGAPI()

queries = [
    "clipboard implementation",
    "file storage system",
    "mouse tracking",
    "SwiftUI panels"
]

results_dict = {}
for query in queries:
    results_dict[query] = api.search(query, top_k=3)

# Print summary
for query, results in results_dict.items():
    print(f"{query}: {len(results)} results")
```

### Export Results

```python
import json

# Search and export
results = api.search("clipboard", top_k=10)

# Export as JSON
with open("search_results.json", "w") as f:
    json.dump(results, f, indent=2)

# Export as CSV
import csv

with open("search_results.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["file_path", "chunk_index", "similarity"])
    writer.writeheader()
    for r in results:
        writer.writerow({
            "file_path": r["file_path"],
            "chunk_index": r["chunk_index"],
            "similarity": 1 - r.get("_distance", 0)
        })
```

## Performance Tuning

### Adjust Chunk Size

Edit `config/config.yaml`:

```yaml
indexing:
  chunk_size: 1500    # Larger chunks = fewer, longer results
  chunk_overlap: 300  # More overlap = better context preservation
```

### Optimize Retrieval

```python
# Faster: Fewer results
results = api.search("query", top_k=3)

# More comprehensive: More results
results = api.search("query", top_k=20)

# Adjust threshold
results = api.search("query", threshold=0.8)  # More strict
results = api.search("query", threshold=0.5)  # More permissive
```

### Use Local Embeddings

For offline use or to avoid API costs:

```bash
# Edit config/.env
EMBEDDING_PROVIDER=local
```

Reindex:
```bash
python scripts/index_repository.py --force
```

## Troubleshooting

### Slow Queries

1. **Reduce top_k**: `--top-k 3` instead of `--top-k 20`
2. **Use OpenAI API**: Faster than local embeddings
3. **Increase chunk size**: Fewer chunks = faster search

### Poor Results

1. **Lower threshold**: `--threshold 0.5` instead of `--threshold 0.8`
2. **Increase top_k**: `--top-k 10` to see more results
3. **Rephrase query**: Try different keywords
4. **Check indexing**: Run `--stats` to verify files are indexed

### Out of Memory

1. **Reduce batch size** in `config.yaml`:
   ```yaml
   performance:
     batch_size: 5  # Instead of 10
   ```

2. **Use smaller embedding model**:
   ```yaml
   embedding:
     provider: local
     local:
       model: all-MiniLM-L6-v2  # Small and fast
   ```

### No Results Found

1. **Check database**: `python scripts/query.py "test" --stats`
2. **Verify indexing**: Files should be listed in stats
3. **Reindex**: `python scripts/index_repository.py --force`
4. **Check file filters**: Make sure files match `supported_extensions`

---

For more help, see [README.md](README.md) or check the examples in [examples.py](examples.py).
