"""
Example usage of RAG system with TrayMe repository.

This script demonstrates various ways to use the RAG system.
"""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from rag_system import RAGAPI


def example_basic_search():
    """Example 1: Basic search."""
    print("\n" + "="*60)
    print("Example 1: Basic Search")
    print("="*60)
    
    api = RAGAPI()
    
    query = "How does clipboard management work?"
    results = api.search(query, top_k=3)
    
    print(f"\nQuery: {query}")
    print(f"Found {len(results)} results:\n")
    
    for i, result in enumerate(results, 1):
        print(f"{i}. {result['file_path']}")
        print(f"   Similarity: {1 - result.get('_distance', 0):.3f}")
        print(f"   Preview: {result['text'][:150]}...\n")


def example_code_search():
    """Example 2: Search for specific code."""
    print("\n" + "="*60)
    print("Example 2: Code Search")
    print("="*60)
    
    api = RAGAPI()
    
    query = "SwiftUI view for files"
    results = api.search(query, top_k=5, file_filter="*.swift")
    
    print(f"\nQuery: {query}")
    print(f"Filter: Swift files only")
    print(f"Found {len(results)} results:\n")
    
    for result in results[:3]:
        print(f"File: {result['file_path']}")
        print(f"Code:\n{result['text'][:200]}...\n")


def example_documentation_search():
    """Example 3: Search documentation."""
    print("\n" + "="*60)
    print("Example 3: Documentation Search")
    print("="*60)
    
    api = RAGAPI()
    
    query = "installation and setup instructions"
    results = api.search(query, top_k=3, file_filter="*.md")
    
    print(f"\nQuery: {query}")
    print(f"Filter: Markdown files only")
    print(f"Found {len(results)} results:\n")
    
    for result in results:
        print(f"Document: {result['file_path']}")
        print(f"Content:\n{result['text'][:300]}...\n")


def example_llm_context():
    """Example 4: Get context for LLM."""
    print("\n" + "="*60)
    print("Example 4: Context for LLM")
    print("="*60)
    
    api = RAGAPI()
    
    query = "What are the main features of TrayMe?"
    context = api.get_context(query, max_tokens=2000)
    
    print(f"\nQuery: {query}")
    print(f"\nContext (first 500 chars):")
    print(context[:500])
    print("...")
    print(f"\nTotal context length: {len(context)} characters")


def example_stats():
    """Example 5: Database statistics."""
    print("\n" + "="*60)
    print("Example 5: Database Statistics")
    print("="*60)
    
    api = RAGAPI()
    stats = api.get_stats()
    
    print(f"\nTotal embeddings: {stats['total_embeddings']}")
    print(f"Indexed files: {stats['indexed_files']}")
    print(f"Embedding dimension: {stats['embedding_dimension']}")
    print(f"Embedding provider: {stats['embedding_provider']}")
    
    print("\nSample of indexed files:")
    for file_path in stats['files'][:10]:
        print(f"  - {file_path}")
    if len(stats['files']) > 10:
        print(f"  ... and {len(stats['files']) - 10} more")


def example_batch_queries():
    """Example 6: Batch queries."""
    print("\n" + "="*60)
    print("Example 6: Batch Queries")
    print("="*60)
    
    api = RAGAPI()
    
    queries = [
        "clipboard history tracking",
        "drag and drop implementation",
        "mouse gesture detection",
        "file storage options",
        "SwiftUI panel design"
    ]
    
    print("\nRunning multiple queries:\n")
    
    for query in queries:
        results = api.search(query, top_k=1)
        if results:
            result = results[0]
            print(f"Q: {query}")
            print(f"A: {result['file_path']} (similarity: {1 - result.get('_distance', 0):.3f})")
            print()


def main():
    """Run all examples."""
    print("\n" + "="*60)
    print("RAG System Examples for TrayMe")
    print("="*60)
    
    try:
        # Run examples
        example_basic_search()
        example_code_search()
        example_documentation_search()
        example_llm_context()
        example_stats()
        example_batch_queries()
        
        print("\n" + "="*60)
        print("All examples completed successfully!")
        print("="*60 + "\n")
        
    except Exception as e:
        print(f"\nError: {e}")
        print("\nMake sure to:")
        print("1. Install dependencies: pip install -r requirements.txt")
        print("2. Set up config: cp config/config.env.example config/.env")
        print("3. Add API key in config/.env")
        print("4. Index repository: python scripts/index_repository.py")
        sys.exit(1)


if __name__ == "__main__":
    main()
