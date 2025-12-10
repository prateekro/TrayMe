"""
Configuration loader for RAG system.
Loads configuration from YAML file and environment variables.
"""
import os
import yaml
from pathlib import Path
from typing import Dict, Any, List
from dotenv import load_dotenv

class Config:
    """Configuration manager for RAG system."""
    
    def __init__(self, config_path: str = None):
        """
        Initialize configuration.
        
        Args:
            config_path: Path to YAML config file. If None, uses default.
        """
        # Load YAML config first
        if config_path is None:
            config_path = Path(__file__).parent / 'config.yaml'
        
        with open(config_path, 'r') as f:
            self._config = yaml.safe_load(f)
        
        # Then load and apply environment variable overrides
        env_path = Path(__file__).parent / '.env'
        if env_path.exists():
            load_dotenv(env_path)
        
        self._load_env_overrides()
    
    def _load_env_overrides(self):
        """Override config values with environment variables."""
        # Embedding provider
        if os.getenv('EMBEDDING_PROVIDER'):
            self._config['embedding']['provider'] = os.getenv('EMBEDDING_PROVIDER')
        
        # OpenAI settings
        if os.getenv('OPENAI_EMBEDDING_MODEL'):
            self._config['embedding']['openai']['model'] = os.getenv('OPENAI_EMBEDDING_MODEL')
        
        # Cohere settings
        if os.getenv('COHERE_EMBEDDING_MODEL'):
            self._config['embedding']['cohere']['model'] = os.getenv('COHERE_EMBEDDING_MODEL')
        
        # Local model settings
        if os.getenv('LOCAL_EMBEDDING_MODEL'):
            self._config['embedding']['local']['model'] = os.getenv('LOCAL_EMBEDDING_MODEL')
        
        # Database path
        if os.getenv('VECTOR_DB_PATH'):
            self._config['database']['path'] = os.getenv('VECTOR_DB_PATH')
    
    @property
    def embedding_provider(self) -> str:
        """Get embedding provider name."""
        return self._config['embedding']['provider']
    
    @property
    def openai_api_key(self) -> str:
        """Get OpenAI API key from environment."""
        return os.getenv('OPENAI_API_KEY', '')
    
    @property
    def cohere_api_key(self) -> str:
        """Get Cohere API key from environment."""
        return os.getenv('COHERE_API_KEY', '')
    
    @property
    def openai_model(self) -> str:
        """Get OpenAI embedding model name."""
        return self._config['embedding']['openai']['model']
    
    @property
    def cohere_model(self) -> str:
        """Get Cohere embedding model name."""
        return self._config['embedding']['cohere']['model']
    
    @property
    def local_model(self) -> str:
        """Get local embedding model name."""
        return self._config['embedding']['local']['model']
    
    @property
    def embedding_dimension(self) -> int:
        """Get embedding dimension based on provider."""
        provider = self.embedding_provider
        return self._config['embedding'][provider]['dimension']
    
    @property
    def db_path(self) -> str:
        """Get vector database path."""
        return self._config['database']['path']
    
    @property
    def table_name(self) -> str:
        """Get database table name."""
        return self._config['database']['table_name']
    
    @property
    def chunk_size(self) -> int:
        """Get text chunk size for splitting."""
        return self._config['indexing']['chunk_size']
    
    @property
    def chunk_overlap(self) -> int:
        """Get chunk overlap size."""
        return self._config['indexing']['chunk_overlap']
    
    @property
    def max_file_size_mb(self) -> int:
        """Get maximum file size in MB."""
        return self._config['indexing']['max_file_size_mb']
    
    @property
    def supported_extensions(self) -> List[str]:
        """Get list of supported file extensions."""
        return self._config['indexing']['supported_extensions']
    
    @property
    def exclude_patterns(self) -> List[str]:
        """Get list of exclude patterns."""
        return self._config['indexing']['exclude_patterns']
    
    @property
    def top_k(self) -> int:
        """Get number of top results to retrieve."""
        return self._config['retrieval']['top_k']
    
    @property
    def similarity_threshold(self) -> float:
        """Get similarity threshold for filtering results."""
        return self._config['retrieval']['similarity_threshold']
    
    @property
    def batch_size(self) -> int:
        """Get batch size for processing."""
        return self._config['performance']['batch_size']
    
    @property
    def max_workers(self) -> int:
        """Get maximum number of worker threads."""
        return self._config['performance']['max_workers']
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value by key."""
        keys = key.split('.')
        value = self._config
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k, default)
            else:
                return default
        return value
