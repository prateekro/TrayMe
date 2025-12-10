"""
Vector database interface using LanceDB.
Handles storage and retrieval of embeddings.
"""
import os
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import numpy as np


class VectorDatabase:
    """Vector database using LanceDB."""
    
    def __init__(self, db_path: str, table_name: str = "repository_embeddings"):
        """
        Initialize vector database.
        
        Args:
            db_path: Path to database directory
            table_name: Name of the table to use
        """
        try:
            import lancedb
        except ImportError:
            raise ImportError(
                "lancedb package is required. Install with: pip install lancedb"
            )
        
        # Create database directory if it doesn't exist
        Path(db_path).mkdir(parents=True, exist_ok=True)
        
        # Connect to database
        self.db = lancedb.connect(db_path)
        self.table_name = table_name
        self.table = None
    
    def create_table(self, dimension: int):
        """
        Create a new table for embeddings.
        
        Args:
            dimension: Dimension of embeddings
        """
        import pyarrow as pa
        
        # Define schema
        schema = pa.schema([
            pa.field("id", pa.string()),
            pa.field("text", pa.string()),
            pa.field("vector", pa.list_(pa.float32(), dimension)),
            pa.field("file_path", pa.string()),
            pa.field("chunk_index", pa.int32()),
            pa.field("metadata", pa.string()),  # JSON string
        ])
        
        # Create empty table
        self.table = self.db.create_table(
            self.table_name,
            schema=schema,
            mode="overwrite"
        )
    
    def open_table(self):
        """Open existing table."""
        try:
            self.table = self.db.open_table(self.table_name)
        except Exception as e:
            raise ValueError(f"Table '{self.table_name}' does not exist. Create it first.") from e
    
    def add_embeddings(
        self,
        texts: List[str],
        embeddings: List[List[float]],
        file_paths: List[str],
        chunk_indices: List[int],
        metadatas: List[Dict]
    ):
        """
        Add embeddings to database.
        
        Args:
            texts: List of text chunks
            embeddings: List of embedding vectors
            file_paths: List of file paths
            chunk_indices: List of chunk indices
            metadatas: List of metadata dictionaries
        """
        import json
        
        if self.table is None:
            raise ValueError("Table not initialized. Call create_table() or open_table() first.")
        
        # Prepare data
        data = []
        for i, (text, embedding, file_path, chunk_idx, metadata) in enumerate(
            zip(texts, embeddings, file_paths, chunk_indices, metadatas)
        ):
            data.append({
                "id": f"{file_path}_{chunk_idx}",
                "text": text,
                "vector": embedding,
                "file_path": file_path,
                "chunk_index": chunk_idx,
                "metadata": json.dumps(metadata),
            })
        
        # Add to table
        self.table.add(data)
    
    def search(
        self,
        query_embedding: List[float],
        top_k: int = 5,
        filter_expr: Optional[str] = None
    ) -> List[Dict]:
        """
        Search for similar embeddings.
        
        Args:
            query_embedding: Query embedding vector
            top_k: Number of results to return
            filter_expr: Optional filter expression
            
        Returns:
            List of search results with text, file_path, and score
        """
        import json
        
        if self.table is None:
            raise ValueError("Table not initialized. Call open_table() first.")
        
        # Perform search
        results = self.table.search(query_embedding).limit(top_k)
        
        # Apply filter if provided
        if filter_expr:
            results = results.where(filter_expr)
        
        # Convert to list of dicts
        results_list = results.to_list()
        
        # Parse metadata
        for result in results_list:
            if 'metadata' in result:
                result['metadata'] = json.loads(result['metadata'])
        
        return results_list
    
    def delete_by_file(self, file_path: str):
        """
        Delete all embeddings for a specific file.
        
        Args:
            file_path: Path to file
        """
        if self.table is None:
            raise ValueError("Table not initialized. Call open_table() first.")
        
        self.table.delete(f"file_path = '{file_path}'")
    
    def count(self) -> int:
        """
        Get total number of embeddings in database.
        
        Returns:
            Number of embeddings
        """
        if self.table is None:
            raise ValueError("Table not initialized. Call open_table() first.")
        
        return self.table.count_rows()
    
    def get_all_files(self) -> List[str]:
        """
        Get list of all indexed files.
        
        Returns:
            List of file paths
        """
        if self.table is None:
            raise ValueError("Table not initialized. Call open_table() first.")
        
        # Query unique file paths
        result = self.table.to_pandas()
        return result['file_path'].unique().tolist()
    
    def clear(self):
        """Clear all data from table."""
        if self.table is None:
            raise ValueError("Table not initialized.")
        
        # Drop and recreate table
        try:
            self.db.drop_table(self.table_name)
        except Exception:
            pass
    
    def close(self):
        """Close database connection."""
        # LanceDB handles cleanup automatically
        pass


class VectorStore:
    """High-level interface for vector storage operations."""
    
    def __init__(self, db: VectorDatabase, embedding_provider):
        """
        Initialize vector store.
        
        Args:
            db: VectorDatabase instance
            embedding_provider: Embedding provider instance
        """
        self.db = db
        self.embedding_provider = embedding_provider
    
    def index_chunks(self, chunks: List) -> int:
        """
        Index text chunks in the database.
        
        Args:
            chunks: List of TextChunk objects
            
        Returns:
            Number of chunks indexed
        """
        if not chunks:
            return 0
        
        # Extract data from chunks
        texts = [chunk.text for chunk in chunks]
        file_paths = [chunk.file_path for chunk in chunks]
        chunk_indices = [chunk.chunk_index for chunk in chunks]
        metadatas = [chunk.metadata for chunk in chunks]
        
        # Generate embeddings in batches
        embeddings = self.embedding_provider.embed_batch(texts)
        
        # Add to database
        self.db.add_embeddings(
            texts=texts,
            embeddings=embeddings,
            file_paths=file_paths,
            chunk_indices=chunk_indices,
            metadatas=metadatas
        )
        
        return len(chunks)
    
    def query(self, query_text: str, top_k: int = 5, threshold: float = 0.0) -> List[Dict]:
        """
        Query the vector database.
        
        Args:
            query_text: Query text
            top_k: Number of results to return
            threshold: Minimum similarity threshold
            
        Returns:
            List of search results
        """
        # Generate query embedding
        query_embedding = self.embedding_provider.embed_text(query_text)
        
        # Search database
        results = self.db.search(query_embedding, top_k=top_k)
        
        # Filter by threshold if specified
        if threshold > 0.0:
            results = [r for r in results if r.get('_distance', 0) <= (1 - threshold)]
        
        return results
