"""
RAG System for TrayMe Repository.

This package provides a Retrieval-Augmented Generation (RAG) system
for fast and efficient retrieval over repository files.

Main components:
- Vector database (LanceDB) for embedding storage
- Multiple embedding providers (OpenAI, Cohere, Local)
- Repository indexing and chunking
- Query interface for retrieval
- API for LLM integration

Quick start:
    from rag_system import RAGAPI
    
    api = RAGAPI()
    results = api.search("How does clipboard management work?")
    context = api.get_context("Explain the file storage system")
"""

from pathlib import Path
import sys

# Add scripts directory to path
_scripts_dir = Path(__file__).parent / "scripts"
sys.path.insert(0, str(_scripts_dir))

# Import main API
try:
    from scripts.rag_api import RAGAPI, search, get_context, answer
    
    __all__ = ["RAGAPI", "search", "get_context", "answer"]
except ImportError:
    # Dependencies not installed yet
    __all__ = []

__version__ = "1.0.0"
