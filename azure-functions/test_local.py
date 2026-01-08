#!/usr/bin/env python3
"""
Local testing script for metadata extraction.

Tests the metadata extraction logic without Azure Functions.
"""
import sys
import json
import io
from pathlib import Path

# Add function directory to path
sys.path.insert(0, str(Path(__file__).parent / 'metadata_extractor'))

from metadata_utils import extract_metadata, generate_thumbnail_url


def test_metadata_extraction(mp3_file_path: str):
    """
    Test metadata extraction from a local MP3 file.
    
    Args:
        mp3_file_path: Path to MP3 file
    """
    print(f"Testing metadata extraction for: {mp3_file_path}")
    print("-" * 60)
    
    # Read MP3 file
    with open(mp3_file_path, 'rb') as f:
        mp3_data = f.read()
    
    # Extract metadata
    blob_stream = io.BytesIO(mp3_data)
    metadata = extract_metadata(blob_stream, Path(mp3_file_path).name)
    
    if metadata:
        print("\n✅ Metadata extracted successfully:")
        print(json.dumps(metadata, indent=2, default=str))
        
        # Test thumbnail generation if album art exists
        if metadata.get('album_art_data'):
            print("\n📸 Testing thumbnail generation...")
            thumbnail_url = generate_thumbnail_url(
                metadata['album_art_data'],
                Path(mp3_file_path).name,
                metadata.get('album_art_mime', 'image/jpeg')
            )
            if thumbnail_url:
                print(f"✅ Thumbnail URL: {thumbnail_url}")
            else:
                print("❌ Thumbnail generation failed")
    else:
        print("\n❌ Failed to extract metadata")
        return False
    
    return True


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Test metadata extraction locally')
    parser.add_argument('mp3_file', help='Path to MP3 file to test')
    
    args = parser.parse_args()
    
    if not Path(args.mp3_file).exists():
        print(f"❌ File not found: {args.mp3_file}")
        sys.exit(1)
    
    success = test_metadata_extraction(args.mp3_file)
    sys.exit(0 if success else 1)

