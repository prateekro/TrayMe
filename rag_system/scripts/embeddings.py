"""
Embedding providers for RAG system.
Supports OpenAI, Cohere, and local models (sentence-transformers).
"""
import os
from abc import ABC, abstractmethod
from typing import List, Union
import numpy as np


class EmbeddingProvider(ABC):
    """Abstract base class for embedding providers."""
    
    @abstractmethod
    def embed_text(self, text: str) -> List[float]:
        """
        Generate embedding for a single text.
        
        Args:
            text: Input text to embed
            
        Returns:
            List of floats representing the embedding
        """
        pass
    
    @abstractmethod
    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """
        Generate embeddings for a batch of texts.
        
        Args:
            texts: List of input texts to embed
            
        Returns:
            List of embeddings
        """
        pass
    
    @property
    @abstractmethod
    def dimension(self) -> int:
        """Return the dimension of embeddings."""
        pass


class OpenAIEmbedding(EmbeddingProvider):
    """OpenAI embedding provider."""
    
    def __init__(self, api_key: str, model: str = "text-embedding-3-small"):
        """
        Initialize OpenAI embedding provider.
        
        Args:
            api_key: OpenAI API key
            model: Model name (default: text-embedding-3-small)
        """
        if not api_key:
            raise ValueError("OpenAI API key is required")
        
        try:
            from openai import OpenAI
        except ImportError:
            raise ImportError("openai package is required. Install with: pip install openai")
        
        self.client = OpenAI(api_key=api_key)
        self.model = model
        
        # Set dimension based on model
        self._dimension = 1536 if "3-small" in model else 3072
    
    def embed_text(self, text: str) -> List[float]:
        """Generate embedding for a single text."""
        response = self.client.embeddings.create(
            input=text,
            model=self.model
        )
        return response.data[0].embedding
    
    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for a batch of texts."""
        # OpenAI API supports batching
        response = self.client.embeddings.create(
            input=texts,
            model=self.model
        )
        return [item.embedding for item in response.data]
    
    @property
    def dimension(self) -> int:
        """Return the dimension of embeddings."""
        return self._dimension


class CohereEmbedding(EmbeddingProvider):
    """Cohere embedding provider."""
    
    def __init__(self, api_key: str, model: str = "embed-english-v3.0"):
        """
        Initialize Cohere embedding provider.
        
        Args:
            api_key: Cohere API key
            model: Model name (default: embed-english-v3.0)
        """
        if not api_key:
            raise ValueError("Cohere API key is required")
        
        try:
            import cohere
        except ImportError:
            raise ImportError("cohere package is required. Install with: pip install cohere")
        
        self.client = cohere.Client(api_key)
        self.model = model
        self._dimension = 1024  # embed-english-v3.0 dimension
    
    def embed_text(self, text: str) -> List[float]:
        """Generate embedding for a single text."""
        response = self.client.embed(
            texts=[text],
            model=self.model,
            input_type="search_document"
        )
        return response.embeddings[0]
    
    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for a batch of texts."""
        response = self.client.embed(
            texts=texts,
            model=self.model,
            input_type="search_document"
        )
        return response.embeddings
    
    @property
    def dimension(self) -> int:
        """Return the dimension of embeddings."""
        return self._dimension


class LocalEmbedding(EmbeddingProvider):
    """Local embedding provider using sentence-transformers."""
    
    def __init__(self, model: str = "all-MiniLM-L6-v2"):
        """
        Initialize local embedding provider.
        
        Args:
            model: Model name (default: all-MiniLM-L6-v2)
        """
        try:
            from sentence_transformers import SentenceTransformer
        except ImportError:
            raise ImportError(
                "sentence-transformers package is required. "
                "Install with: pip install sentence-transformers"
            )
        
        self.model = SentenceTransformer(model)
        self._dimension = self.model.get_sentence_embedding_dimension()
    
    def embed_text(self, text: str) -> List[float]:
        """Generate embedding for a single text."""
        embedding = self.model.encode(text, convert_to_numpy=True)
        return embedding.tolist()
    
    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for a batch of texts."""
        embeddings = self.model.encode(texts, convert_to_numpy=True)
        return embeddings.tolist()
    
    @property
    def dimension(self) -> int:
        """Return the dimension of embeddings."""
        return self._dimension


def get_embedding_provider(provider: str, config) -> EmbeddingProvider:
    """
    Factory function to get embedding provider.
    
    Args:
        provider: Provider name (openai, cohere, or local)
        config: Configuration object
        
    Returns:
        EmbeddingProvider instance
        
    Raises:
        ValueError: If provider is not supported
    """
    if provider == "openai":
        return OpenAIEmbedding(
            api_key=config.openai_api_key,
            model=config.openai_model
        )
    elif provider == "cohere":
        return CohereEmbedding(
            api_key=config.cohere_api_key,
            model=config.cohere_model
        )
    elif provider == "local":
        return LocalEmbedding(model=config.local_model)
    else:
        raise ValueError(
            f"Unsupported embedding provider: {provider}. "
            f"Supported providers: openai, cohere, local"
        )
