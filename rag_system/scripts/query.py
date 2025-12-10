"""
Query interface for RAG system.
Retrieves relevant context from repository.
"""
import os
import sys
from pathlib import Path
from typing import List, Dict, Optional
import json

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from config.config import Config
from scripts.embeddings import get_embedding_provider
from scripts.vector_db import VectorDatabase, VectorStore


class RAGQuery:
    """Query interface for RAG system."""
    
    def __init__(self, config: Config):
        """
        Initialize RAG query interface.
        
        Args:
            config: Configuration object
        """
        self.config = config
        
        # Initialize embedding provider
        self.embedding_provider = get_embedding_provider(
            config.embedding_provider,
            config
        )
        
        # Initialize vector database
        self.vector_db = VectorDatabase(
            db_path=config.db_path,
            table_name=config.table_name
        )
        
        # Open existing table
        try:
            self.vector_db.open_table()
        except ValueError as e:
            raise ValueError(
                "Vector database not initialized. Run index_repository.py first."
            ) from e
        
        # Initialize vector store
        self.vector_store = VectorStore(self.vector_db, self.embedding_provider)
    
    def query(
        self,
        query_text: str,
        top_k: Optional[int] = None,
        threshold: Optional[float] = None,
        file_filter: Optional[str] = None
    ) -> List[Dict]:
        """
        Query the RAG system.
        
        Args:
            query_text: Query text
            top_k: Number of results to return (default: from config)
            threshold: Minimum similarity threshold (default: from config)
            file_filter: Optional file path filter (e.g., "*.swift")
            
        Returns:
            List of search results with text, file_path, metadata, and score
        """
        if top_k is None:
            top_k = self.config.top_k
        
        if threshold is None:
            threshold = self.config.similarity_threshold
        
        # Query vector store
        results = self.vector_store.query(
            query_text=query_text,
            top_k=top_k,
            threshold=threshold
        )
        
        # Apply file filter if specified
        if file_filter:
            import fnmatch
            results = [
                r for r in results
                if fnmatch.fnmatch(r['file_path'], file_filter)
            ]
        
        return results
    
    def format_results(self, results: List[Dict], format: str = "text") -> str:
        """
        Format query results for display or LLM consumption.
        
        Args:
            results: List of search results
            format: Output format ('text', 'json', 'markdown', or 'llm')
            
        Returns:
            Formatted results as string
        """
        if format == "json":
            return json.dumps(results, indent=2)
        
        elif format == "markdown":
            output = "# Query Results\n\n"
            for i, result in enumerate(results, 1):
                output += f"## Result {i}\n"
                output += f"**File:** `{result['file_path']}`\n"
                output += f"**Chunk:** {result['chunk_index']}\n"
                if '_distance' in result:
                    output += f"**Similarity:** {1 - result['_distance']:.3f}\n"
                output += f"\n{result['text']}\n\n"
                output += "---\n\n"
            return output
        
        elif format == "llm":
            # Format optimized for LLM consumption
            output = "# Relevant Repository Context\n\n"
            for i, result in enumerate(results, 1):
                output += f"## Source {i}: {result['file_path']}\n\n"
                output += f"```\n{result['text']}\n```\n\n"
            return output
        
        else:  # text format
            output = ""
            for i, result in enumerate(results, 1):
                output += f"\n{'='*60}\n"
                output += f"Result {i}/{len(results)}\n"
                output += f"{'='*60}\n"
                output += f"File: {result['file_path']}\n"
                output += f"Chunk: {result['chunk_index']}\n"
                if '_distance' in result:
                    output += f"Similarity: {1 - result['_distance']:.3f}\n"
                output += f"\n{result['text']}\n"
            output += f"\n{'='*60}\n"
            return output
    
    def get_context_for_llm(
        self,
        query: str,
        max_tokens: int = 4000,
        top_k: int = 10
    ) -> str:
        """
        Get formatted context for LLM prompts.
        
        Args:
            query: Query text
            max_tokens: Maximum tokens to include (approximate)
            top_k: Number of results to retrieve
            
        Returns:
            Formatted context string
        """
        # Query with higher top_k to have more candidates
        results = self.query(query_text=query, top_k=top_k)
        
        # Build context, respecting token limit
        context_parts = []
        total_chars = 0
        max_chars = max_tokens * 4  # Rough approximation: 1 token ≈ 4 chars
        
        for result in results:
            text = result['text']
            file_path = result['file_path']
            
            # Format as source citation
            source = f"\n## {file_path}\n```\n{text}\n```\n"
            
            if total_chars + len(source) > max_chars:
                break
            
            context_parts.append(source)
            total_chars += len(source)
        
        context = "# Repository Context\n" + "\n".join(context_parts)
        return context
    
    def get_stats(self) -> Dict:
        """
        Get statistics about the indexed repository.
        
        Returns:
            Dictionary with statistics
        """
        total_embeddings = self.vector_db.count()
        indexed_files = self.vector_db.get_all_files()
        
        stats = {
            "total_embeddings": total_embeddings,
            "indexed_files": len(indexed_files),
            "files": indexed_files,
            "embedding_dimension": self.embedding_provider.dimension,
            "embedding_provider": self.config.embedding_provider,
        }
        
        return stats


def main():
    """Main entry point for querying."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Query RAG system")
    parser.add_argument(
        "query",
        help="Query text"
    )
    parser.add_argument(
        "--config",
        help="Path to config file (default: config/config.yaml)"
    )
    parser.add_argument(
        "--top-k",
        type=int,
        help="Number of results to return"
    )
    parser.add_argument(
        "--threshold",
        type=float,
        help="Minimum similarity threshold"
    )
    parser.add_argument(
        "--format",
        choices=["text", "json", "markdown", "llm"],
        default="text",
        help="Output format"
    )
    parser.add_argument(
        "--file-filter",
        help="Filter results by file pattern (e.g., '*.swift')"
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Show database statistics"
    )
    
    args = parser.parse_args()
    
    # Load configuration
    config = Config(args.config)
    
    # Create query interface
    try:
        rag_query = RAGQuery(config)
    except ValueError as e:
        print(f"Error: {e}")
        print("\nPlease run 'python scripts/index_repository.py' first to index the repository.")
        sys.exit(1)
    
    # Show stats if requested
    if args.stats:
        stats = rag_query.get_stats()
        print("\nDatabase Statistics:")
        print(f"  Total embeddings: {stats['total_embeddings']}")
        print(f"  Indexed files: {stats['indexed_files']}")
        print(f"  Embedding dimension: {stats['embedding_dimension']}")
        print(f"  Embedding provider: {stats['embedding_provider']}")
        print()
    
    # Execute query
    print(f"Querying: {args.query}\n")
    
    results = rag_query.query(
        query_text=args.query,
        top_k=args.top_k,
        threshold=args.threshold,
        file_filter=args.file_filter
    )
    
    if not results:
        print("No results found.")
        return
    
    # Format and print results
    formatted = rag_query.format_results(results, format=args.format)
    print(formatted)


if __name__ == "__main__":
    main()
