#!/usr/bin/env python3
"""
Validation script for RAG system.
Tests that all components are properly set up.
"""

import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

def test_imports():
    """Test that all modules can be imported."""
    print("Testing imports...")
    
    try:
        # Test config import
        from config.config import Config
        print("  ✓ Config module")
        
        # Test embeddings import
        from scripts.embeddings import EmbeddingProvider
        print("  ✓ Embeddings module")
        
        # Test text processor import
        from scripts.text_processor import FileProcessor, TextChunker
        print("  ✓ Text processor module")
        
        # Test vector DB import
        from scripts.vector_db import VectorDatabase
        print("  ✓ Vector database module")
        
        print("\n✓ All imports successful!\n")
        return True
    
    except ImportError as e:
        print(f"\n✗ Import failed: {e}")
        print("\nPlease install dependencies:")
        print("  pip install -r requirements.txt\n")
        return False


def test_config():
    """Test configuration loading."""
    print("Testing configuration...")
    
    try:
        from config.config import Config
        
        # Load config
        config = Config()
        
        # Check basic properties
        assert hasattr(config, 'embedding_provider')
        assert hasattr(config, 'chunk_size')
        assert hasattr(config, 'top_k')
        
        print(f"  Provider: {config.embedding_provider}")
        print(f"  Chunk size: {config.chunk_size}")
        print(f"  Top K: {config.top_k}")
        
        print("\n✓ Configuration loaded successfully!\n")
        return True
    
    except Exception as e:
        print(f"\n✗ Configuration test failed: {e}\n")
        return False


def test_file_processor():
    """Test file processing."""
    print("Testing file processor...")
    
    try:
        from scripts.text_processor import FileProcessor, TextChunker
        
        # Create processor
        processor = FileProcessor()
        
        # Test with this script
        script_path = __file__
        content = processor.read_file(script_path)
        
        assert content is not None
        assert len(content) > 0
        
        # Test chunker
        chunker = TextChunker(chunk_size=500, chunk_overlap=100)
        chunks = chunker.chunk_text(content, script_path)
        
        assert len(chunks) > 0
        
        print(f"  ✓ Read {len(content)} characters")
        print(f"  ✓ Created {len(chunks)} chunks")
        
        print("\n✓ File processor working!\n")
        return True
    
    except Exception as e:
        print(f"\n✗ File processor test failed: {e}\n")
        return False


def test_directory_structure():
    """Test that all required directories exist."""
    print("Testing directory structure...")
    
    required_dirs = [
        "config",
        "scripts",
        "database"
    ]
    
    required_files = [
        "config/config.yaml",
        "config/config.env.example",
        "requirements.txt",
        "README.md"
    ]
    
    all_ok = True
    
    for dir_name in required_dirs:
        if os.path.isdir(dir_name):
            print(f"  ✓ {dir_name}/")
        else:
            print(f"  ✗ {dir_name}/ NOT FOUND")
            all_ok = False
    
    for file_name in required_files:
        if os.path.isfile(file_name):
            print(f"  ✓ {file_name}")
        else:
            print(f"  ✗ {file_name} NOT FOUND")
            all_ok = False
    
    if all_ok:
        print("\n✓ Directory structure OK!\n")
    else:
        print("\n✗ Some files/directories missing!\n")
    
    return all_ok


def main():
    """Run all tests."""
    print("\n" + "="*60)
    print("RAG System Validation")
    print("="*60 + "\n")
    
    # Change to script directory
    os.chdir(Path(__file__).parent)
    
    # Run tests
    results = []
    
    results.append(("Directory Structure", test_directory_structure()))
    results.append(("Imports", test_imports()))
    results.append(("Configuration", test_config()))
    results.append(("File Processor", test_file_processor()))
    
    # Print summary
    print("="*60)
    print("Summary")
    print("="*60)
    
    all_passed = True
    for test_name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{test_name:.<40} {status}")
        if not passed:
            all_passed = False
    
    print("="*60)
    
    if all_passed:
        print("\n✓ All tests passed! System is ready to use.\n")
        print("Next steps:")
        print("1. Configure your API key in config/.env")
        print("2. Index repository: python scripts/index_repository.py")
        print("3. Try a query: python scripts/query.py 'test query'\n")
        return 0
    else:
        print("\n✗ Some tests failed. Please fix the issues above.\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
