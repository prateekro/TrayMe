"""
Repository indexer for RAG system.
Scans repository files and creates embeddings.
"""
import os
import sys
from pathlib import Path
from typing import List, Optional
from tqdm import tqdm
import fnmatch

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from config.config import Config
from scripts.embeddings import get_embedding_provider
from scripts.text_processor import FileProcessor, TextChunker
from scripts.vector_db import VectorDatabase, VectorStore


class RepositoryIndexer:
    """Indexes repository files for RAG system."""
    
    def __init__(self, config: Config):
        """
        Initialize repository indexer.
        
        Args:
            config: Configuration object
        """
        self.config = config
        self.file_processor = FileProcessor()
        self.text_chunker = TextChunker(
            chunk_size=config.chunk_size,
            chunk_overlap=config.chunk_overlap
        )
        
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
        
        # Initialize vector store
        self.vector_store = VectorStore(self.vector_db, self.embedding_provider)
    
    def should_index_file(self, file_path: str) -> bool:
        """
        Check if file should be indexed.
        
        Args:
            file_path: Path to file
            
        Returns:
            True if file should be indexed, False otherwise
        """
        # Check file extension
        ext = Path(file_path).suffix
        if ext not in self.config.supported_extensions:
            return False
        
        # Check exclude patterns
        for pattern in self.config.exclude_patterns:
            if fnmatch.fnmatch(file_path, pattern) or fnmatch.fnmatch(str(file_path), f"*/{pattern}"):
                return False
        
        return True
    
    def find_files(self, repo_path: str) -> List[str]:
        """
        Find all files to index in repository.
        
        Args:
            repo_path: Path to repository
            
        Returns:
            List of file paths
        """
        files_to_index = []
        
        for root, dirs, files in os.walk(repo_path):
            # Skip hidden directories and excluded patterns
            dirs[:] = [d for d in dirs if not d.startswith('.') and d != '__pycache__']
            
            for file in files:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, repo_path)
                
                if self.should_index_file(rel_path):
                    files_to_index.append(file_path)
        
        return files_to_index
    
    def index_file(self, file_path: str, repo_path: str) -> int:
        """
        Index a single file.
        
        Args:
            file_path: Absolute path to file
            repo_path: Path to repository root
            
        Returns:
            Number of chunks indexed
        """
        # Read file content
        content = self.file_processor.read_file(
            file_path,
            max_size_mb=self.config.max_file_size_mb
        )
        
        if content is None:
            return 0
        
        # Get relative path for storage
        rel_path = os.path.relpath(file_path, repo_path)
        
        # Extract metadata
        metadata = self.file_processor.extract_metadata(file_path, content)
        
        # Chunk text
        chunks = self.text_chunker.chunk_by_sections(content, rel_path, metadata)
        
        if not chunks:
            return 0
        
        # Index chunks
        num_indexed = self.vector_store.index_chunks(chunks)
        
        return num_indexed
    
    def index_repository(self, repo_path: str, force_reindex: bool = False):
        """
        Index entire repository.
        
        Args:
            repo_path: Path to repository
            force_reindex: If True, clear existing index and reindex
        """
        print(f"Indexing repository: {repo_path}")
        print(f"Using embedding provider: {self.config.embedding_provider}")
        
        # Initialize or open database
        try:
            if force_reindex:
                print("Force reindex enabled - clearing existing data...")
                self.vector_db.clear()
                self.vector_db.create_table(self.embedding_provider.dimension)
            else:
                try:
                    self.vector_db.open_table()
                    print(f"Opened existing table with {self.vector_db.count()} embeddings")
                except ValueError:
                    print("Creating new table...")
                    self.vector_db.create_table(self.embedding_provider.dimension)
        except Exception as e:
            print(f"Error initializing database: {e}")
            print("Creating new table...")
            self.vector_db.create_table(self.embedding_provider.dimension)
        
        # Find files to index
        print("\nScanning repository for files...")
        files = self.find_files(repo_path)
        print(f"Found {len(files)} files to index")
        
        if not files:
            print("No files found to index!")
            return
        
        # Index files with progress bar
        total_chunks = 0
        failed_files = []
        
        with tqdm(total=len(files), desc="Indexing files") as pbar:
            for file_path in files:
                try:
                    num_chunks = self.index_file(file_path, repo_path)
                    total_chunks += num_chunks
                    pbar.set_postfix({'chunks': total_chunks})
                except Exception as e:
                    failed_files.append((file_path, str(e)))
                    pbar.write(f"Error indexing {file_path}: {e}")
                finally:
                    pbar.update(1)
        
        # Print summary
        print(f"\n{'='*60}")
        print("Indexing Complete!")
        print(f"{'='*60}")
        print(f"Files indexed: {len(files) - len(failed_files)}/{len(files)}")
        print(f"Total chunks created: {total_chunks}")
        print(f"Total embeddings in database: {self.vector_db.count()}")
        
        if failed_files:
            print(f"\nFailed to index {len(failed_files)} files:")
            for file_path, error in failed_files[:10]:  # Show first 10
                print(f"  - {file_path}: {error}")
            if len(failed_files) > 10:
                print(f"  ... and {len(failed_files) - 10} more")
        
        print(f"{'='*60}\n")
    
    def update_file(self, file_path: str, repo_path: str):
        """
        Update embeddings for a single file.
        
        Args:
            file_path: Absolute path to file
            repo_path: Path to repository root
        """
        rel_path = os.path.relpath(file_path, repo_path)
        
        # Delete existing embeddings for this file
        self.vector_db.delete_by_file(rel_path)
        
        # Reindex file
        num_chunks = self.index_file(file_path, repo_path)
        print(f"Updated {file_path}: {num_chunks} chunks indexed")


def main():
    """Main entry point for repository indexing."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Index repository for RAG system")
    parser.add_argument(
        "repo_path",
        nargs='?',
        default=os.getcwd(),
        help="Path to repository (default: current directory)"
    )
    parser.add_argument(
        "--config",
        help="Path to config file (default: config/config.yaml)"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force reindex (clear existing data)"
    )
    
    args = parser.parse_args()
    
    # Load configuration
    config = Config(args.config)
    
    # Create indexer
    indexer = RepositoryIndexer(config)
    
    # Index repository
    try:
        indexer.index_repository(args.repo_path, force_reindex=args.force)
    except KeyboardInterrupt:
        print("\nIndexing interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError during indexing: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
