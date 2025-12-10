"""
Simple API interface for RAG system.
Provides easy integration with LLMs and external tools.
"""
import sys
from pathlib import Path
from typing import List, Dict, Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from config.config import Config
from scripts.query import RAGQuery


class RAGAPI:
    """High-level API for RAG system."""
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize RAG API.
        
        Args:
            config_path: Optional path to config file
        """
        self.config = Config(config_path)
        self.rag_query = RAGQuery(self.config)
    
    def search(
        self,
        query: str,
        top_k: int = 5,
        threshold: float = 0.7,
        file_filter: Optional[str] = None
    ) -> List[Dict]:
        """
        Search for relevant content.
        
        Args:
            query: Search query
            top_k: Number of results to return
            threshold: Minimum similarity threshold
            file_filter: Optional file pattern filter
            
        Returns:
            List of search results
        """
        return self.rag_query.query(
            query_text=query,
            top_k=top_k,
            threshold=threshold,
            file_filter=file_filter
        )
    
    def get_context(self, query: str, max_tokens: int = 4000) -> str:
        """
        Get formatted context for LLM.
        
        Args:
            query: Query to find relevant context
            max_tokens: Maximum tokens to include
            
        Returns:
            Formatted context string ready for LLM
        """
        return self.rag_query.get_context_for_llm(query, max_tokens=max_tokens)
    
    def answer_with_context(self, question: str, model: str = "gpt-4") -> str:
        """
        Answer question using retrieved context and LLM.
        
        Args:
            question: Question to answer
            model: LLM model to use (requires OpenAI API)
            
        Returns:
            Answer from LLM with repository context
        """
        # Get relevant context
        context = self.get_context(question)
        
        # Build prompt
        prompt = f"""You are a helpful assistant with access to a code repository. 
Answer the following question based on the provided repository context.

{context}

Question: {question}

Answer:"""
        
        # Call LLM (requires OpenAI)
        try:
            from openai import OpenAI
            client = OpenAI(api_key=self.config.openai_api_key)
            
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "You are a helpful coding assistant."},
                    {"role": "user", "content": prompt}
                ]
            )
            
            return response.choices[0].message.content
        
        except ImportError:
            raise ImportError("OpenAI package required for LLM integration")
        except Exception as e:
            raise Exception(f"Error calling LLM: {e}")
    
    def get_stats(self) -> Dict:
        """Get database statistics."""
        return self.rag_query.get_stats()


# Convenience functions for quick usage
_default_api = None

def get_api(config_path: Optional[str] = None) -> RAGAPI:
    """Get or create default API instance."""
    global _default_api
    if _default_api is None:
        _default_api = RAGAPI(config_path)
    return _default_api


def search(query: str, **kwargs) -> List[Dict]:
    """Quick search function."""
    api = get_api()
    return api.search(query, **kwargs)


def get_context(query: str, **kwargs) -> str:
    """Quick context retrieval function."""
    api = get_api()
    return api.get_context(query, **kwargs)


def answer(question: str, **kwargs) -> str:
    """Quick question answering function."""
    api = get_api()
    return api.answer_with_context(question, **kwargs)


# Example usage
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="RAG API Demo")
    parser.add_argument("query", help="Query or question")
    parser.add_argument("--answer", action="store_true", help="Use LLM to answer")
    parser.add_argument("--context-only", action="store_true", help="Return context only")
    
    args = parser.parse_args()
    
    try:
        api = RAGAPI()
        
        if args.answer:
            # Use LLM to answer
            answer = api.answer_with_context(args.query)
            print("\nAnswer:")
            print(answer)
        elif args.context_only:
            # Return context only
            context = api.get_context(args.query)
            print(context)
        else:
            # Return search results
            results = api.search(args.query)
            print(f"\nFound {len(results)} results:\n")
            for i, result in enumerate(results, 1):
                print(f"{i}. {result['file_path']} (similarity: {1 - result.get('_distance', 0):.3f})")
                print(f"   {result['text'][:100]}...")
                print()
    
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
