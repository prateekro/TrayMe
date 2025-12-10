"""
Text processing utilities for RAG system.
Handles file reading, chunking, and preprocessing.
"""
import os
import re
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass


@dataclass
class TextChunk:
    """Represents a chunk of text with metadata."""
    text: str
    file_path: str
    chunk_index: int
    start_char: int
    end_char: int
    metadata: Dict = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class FileProcessor:
    """Processes files and extracts text content."""
    
    # Binary file extensions to skip
    BINARY_EXTENSIONS = {
        '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.icns',
        '.pdf', '.zip', '.tar', '.gz', '.dmg', '.app',
        '.xcodeproj', '.xcworkspace', '.xcassets'
    }
    
    @staticmethod
    def is_binary_file(file_path: str) -> bool:
        """
        Check if file is binary.
        
        Args:
            file_path: Path to file
            
        Returns:
            True if binary, False otherwise
        """
        ext = Path(file_path).suffix.lower()
        if ext in FileProcessor.BINARY_EXTENSIONS:
            return True
        
        # Check file content for binary data
        try:
            with open(file_path, 'rb') as f:
                chunk = f.read(1024)
                if b'\0' in chunk:  # Null bytes indicate binary
                    return True
        except Exception:
            return True
        
        return False
    
    @staticmethod
    def read_file(file_path: str, max_size_mb: int = 10) -> Optional[str]:
        """
        Read file content safely.
        
        Args:
            file_path: Path to file
            max_size_mb: Maximum file size in MB
            
        Returns:
            File content as string, or None if unable to read
        """
        try:
            # Check file size
            file_size = os.path.getsize(file_path) / (1024 * 1024)
            if file_size > max_size_mb:
                print(f"Warning: Skipping large file {file_path} ({file_size:.2f} MB)")
                return None
            
            # Check if binary
            if FileProcessor.is_binary_file(file_path):
                print(f"Warning: Skipping binary file {file_path}")
                return None
            
            # Try to read as text
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()
        
        except UnicodeDecodeError:
            # Try with different encoding
            try:
                with open(file_path, 'r', encoding='latin-1') as f:
                    return f.read()
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
                return None
        
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return None
    
    @staticmethod
    def extract_metadata(file_path: str, content: str) -> Dict:
        """
        Extract metadata from file.
        
        Args:
            file_path: Path to file
            content: File content
            
        Returns:
            Dictionary of metadata
        """
        path_obj = Path(file_path)
        
        metadata = {
            'file_name': path_obj.name,
            'file_extension': path_obj.suffix,
            'file_size': len(content),
            'line_count': content.count('\n') + 1,
        }
        
        # Extract language for code files
        if path_obj.suffix in ['.swift', '.py', '.js', '.ts', '.java', '.cpp', '.c']:
            metadata['language'] = path_obj.suffix[1:]
        
        # Extract title from markdown
        if path_obj.suffix == '.md':
            lines = content.split('\n')
            for line in lines:
                if line.startswith('# '):
                    metadata['title'] = line[2:].strip()
                    break
        
        return metadata


class TextChunker:
    """Splits text into chunks for embedding."""
    
    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 200):
        """
        Initialize text chunker.
        
        Args:
            chunk_size: Maximum size of each chunk in characters
            chunk_overlap: Number of overlapping characters between chunks
        """
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
    
    def chunk_text(self, text: str, file_path: str, metadata: Dict = None) -> List[TextChunk]:
        """
        Split text into chunks.
        
        Args:
            text: Text to chunk
            file_path: Path to source file
            metadata: Optional metadata to attach to chunks
            
        Returns:
            List of TextChunk objects
        """
        if not text or len(text) == 0:
            return []
        
        chunks = []
        
        # For small files, return as single chunk
        if len(text) <= self.chunk_size:
            chunks.append(TextChunk(
                text=text,
                file_path=file_path,
                chunk_index=0,
                start_char=0,
                end_char=len(text),
                metadata=metadata or {}
            ))
            return chunks
        
        # Split into chunks with overlap
        start = 0
        chunk_index = 0
        
        while start < len(text):
            end = min(start + self.chunk_size, len(text))
            
            # Try to break at sentence or paragraph boundary
            if end < len(text):
                # Look for paragraph break
                next_para = text.find('\n\n', max(0, end - 100), min(len(text), end + 100))
                if next_para != -1:
                    end = next_para + 2
                else:
                    # Look for sentence break
                    next_sentence = text.find('. ', max(0, end - 50), min(len(text), end + 50))
                    if next_sentence != -1:
                        end = next_sentence + 2
                    # Look for line break
                    elif '\n' in text[max(0, end - 50):min(len(text), end + 50)]:
                        next_line = text.find('\n', max(0, end - 50), min(len(text), end + 50))
                        if next_line != -1:
                            end = next_line + 1
            
            chunk_text = text[start:end].strip()
            
            if chunk_text:
                chunks.append(TextChunk(
                    text=chunk_text,
                    file_path=file_path,
                    chunk_index=chunk_index,
                    start_char=start,
                    end_char=end,
                    metadata=metadata or {}
                ))
            
            # Move to next chunk with overlap
            start = end - self.chunk_overlap
            chunk_index += 1
        
        return chunks
    
    def chunk_by_sections(self, text: str, file_path: str, metadata: Dict = None) -> List[TextChunk]:
        """
        Split text by sections (for markdown and code).
        
        Args:
            text: Text to chunk
            file_path: Path to source file
            metadata: Optional metadata to attach to chunks
            
        Returns:
            List of TextChunk objects
        """
        ext = Path(file_path).suffix
        
        if ext == '.md':
            return self._chunk_markdown(text, file_path, metadata)
        elif ext in ['.swift', '.py', '.js', '.ts']:
            return self._chunk_code(text, file_path, metadata)
        else:
            return self.chunk_text(text, file_path, metadata)
    
    def _chunk_markdown(self, text: str, file_path: str, metadata: Dict = None) -> List[TextChunk]:
        """Split markdown by headers."""
        chunks = []
        sections = re.split(r'\n(?=#{1,6} )', text)
        
        for i, section in enumerate(sections):
            if section.strip():
                chunks.append(TextChunk(
                    text=section.strip(),
                    file_path=file_path,
                    chunk_index=i,
                    start_char=0,  # Approximate
                    end_char=len(section),
                    metadata=metadata or {}
                ))
        
        return chunks if chunks else self.chunk_text(text, file_path, metadata)
    
    def _chunk_code(self, text: str, file_path: str, metadata: Dict = None) -> List[TextChunk]:
        """Split code by functions/classes."""
        # Simple heuristic: split on function/class definitions
        # For more sophisticated parsing, use AST
        chunks = []
        
        # Swift patterns
        if Path(file_path).suffix == '.swift':
            pattern = r'\n(?=(?:class|struct|enum|func|extension|protocol) )'
        # Python patterns
        elif Path(file_path).suffix == '.py':
            pattern = r'\n(?=(?:class|def|async def) )'
        # JavaScript/TypeScript patterns
        else:
            pattern = r'\n(?=(?:class|function|const .* = |export |interface |type ) )'
        
        sections = re.split(pattern, text)
        
        for i, section in enumerate(sections):
            section = section.strip()
            if section and len(section) > 50:  # Skip very small sections
                # If section is too large, fall back to regular chunking
                if len(section) > self.chunk_size:
                    chunks.extend(self.chunk_text(section, file_path, metadata))
                else:
                    chunks.append(TextChunk(
                        text=section,
                        file_path=file_path,
                        chunk_index=i,
                        start_char=0,
                        end_char=len(section),
                        metadata=metadata or {}
                    ))
        
        return chunks if chunks else self.chunk_text(text, file_path, metadata)
