#!/usr/bin/env python3
"""
Test metadata extraction with k3s Kafka.

This script simulates the Azure Function behavior:
1. Reads MP3 files from a directory
2. Extracts metadata
3. Publishes to Kafka running in k3s
4. Saves metadata JSON files

Usage:
    python test_k3s.py /path/to/mp3/files --kafka-bootstrap kafka:9092
    python test_k3s.py /path/to/mp3/files --kafka-bootstrap localhost:9092  # Port-forward
"""
import sys
import json
import argparse
import io
from pathlib import Path
from typing import List, Dict, Any
import logging

# Add function directory to path
sys.path.insert(0, str(Path(__file__).parent / 'metadata_extractor'))

from metadata_utils import extract_metadata, generate_thumbnail_url
from kafka_utils import get_kafka_producer, publish_metadata_event, close_producer

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def process_mp3_file(
    mp3_path: Path,
    output_dir: Path,
    publish_to_kafka: bool = True
) -> bool:
    """
    Process a single MP3 file: extract metadata and publish to Kafka.
    
    Args:
        mp3_path: Path to MP3 file
        output_dir: Directory to save metadata JSON
        publish_to_kafka: Whether to publish to Kafka
        
    Returns:
        True if successful, False otherwise
    """
    logger.info(f"Processing: {mp3_path.name}")
    
    try:
        # Read MP3 file
        with open(mp3_path, 'rb') as f:
            mp3_data = f.read()
        
        # Extract metadata
        blob_stream = io.BytesIO(mp3_data)
        metadata = extract_metadata(blob_stream, mp3_path.name)
        
        if not metadata:
            logger.error(f"Failed to extract metadata from {mp3_path.name}")
            return False
        
        # Generate thumbnail URL if album art exists
        if metadata.get('album_art_data'):
            try:
                thumbnail_url = generate_thumbnail_url(
                    metadata['album_art_data'],
                    mp3_path.name,
                    metadata.get('album_art_mime', 'image/jpeg')
                )
                if thumbnail_url:
                    metadata['thumbnail_url'] = thumbnail_url
            except Exception as e:
                logger.warning(f"Failed to generate thumbnail: {e}")
        
        # Add processing metadata
        from datetime import datetime
        metadata['processed_at'] = datetime.utcnow().isoformat()
        metadata['source_file'] = str(mp3_path)
        metadata['file_size'] = len(mp3_data)
        metadata['function_version'] = '1.0.0'
        metadata['test_mode'] = True
        
        # Save metadata JSON
        output_file = output_dir / f"{mp3_path.stem}.json"
        with open(output_file, 'w') as f:
            json.dump(metadata, f, indent=2, default=str)
        
        logger.info(
            f"✅ Extracted: {metadata.get('title', 'Unknown')} "
            f"by {metadata.get('artist', 'Unknown Artist')}"
        )
        logger.info(f"   Saved to: {output_file}")
        
        # Publish to Kafka
        if publish_to_kafka:
            try:
                success = publish_metadata_event(metadata)
                if success:
                    logger.info(f"   Published to Kafka: ✅")
                else:
                    logger.warning(f"   Published to Kafka: ❌ (check Kafka connection)")
            except Exception as e:
                logger.error(f"   Kafka publish failed: {e}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error processing {mp3_path.name}: {e}", exc_info=True)
        return False


def find_mp3_files(directory: Path) -> List[Path]:
    """Find all MP3 files in directory."""
    mp3_files = list(directory.glob('*.mp3'))
    mp3_files.extend(directory.glob('*.MP3'))
    return sorted(mp3_files)


def main():
    parser = argparse.ArgumentParser(
        description='Test metadata extraction with k3s Kafka',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Process MP3s and publish to k3s Kafka (with port-forward)
  kubectl port-forward svc/kafka 9092:9092 -n cloudsound &
  python test_k3s.py /path/to/mp3s --kafka-bootstrap localhost:9092
  
  # Process MP3s without Kafka (just extract metadata)
  python test_k3s.py /path/to/mp3s --no-kafka
  
  # Process single file
  python test_k3s.py /path/to/track.mp3 --kafka-bootstrap localhost:9092
        """
    )
    
    parser.add_argument(
        'input',
        type=str,
        help='Path to MP3 file or directory containing MP3 files'
    )
    
    parser.add_argument(
        '--kafka-bootstrap',
        type=str,
        default='localhost:9092',
        help='Kafka bootstrap servers (default: localhost:9092)'
    )
    
    parser.add_argument(
        '--kafka-topic',
        type=str,
        default='music.metadata.extracted',
        help='Kafka topic for metadata events (default: music.metadata.extracted)'
    )
    
    parser.add_argument(
        '--output-dir',
        type=str,
        default='./metadata_output',
        help='Directory to save metadata JSON files (default: ./metadata_output)'
    )
    
    parser.add_argument(
        '--no-kafka',
        action='store_true',
        help='Skip Kafka publishing (only extract metadata)'
    )
    
    parser.add_argument(
        '--kafka-security-protocol',
        type=str,
        default='',
        help='Kafka security protocol (PLAINTEXT, SASL_PLAINTEXT, SASL_SSL)'
    )
    
    parser.add_argument(
        '--kafka-sasl-username',
        type=str,
        default='',
        help='Kafka SASL username'
    )
    
    parser.add_argument(
        '--kafka-sasl-password',
        type=str,
        default='',
        help='Kafka SASL password'
    )
    
    args = parser.parse_args()
    
    # Set up environment variables for Kafka
    import os
    os.environ['KAFKA_BOOTSTRAP_SERVERS'] = args.kafka_bootstrap
    os.environ['KAFKA_METADATA_TOPIC'] = args.kafka_topic
    
    if args.kafka_security_protocol:
        os.environ['KAFKA_SECURITY_PROTOCOL'] = args.kafka_security_protocol
        os.environ['KAFKA_SASL_MECHANISM'] = 'PLAIN'
        os.environ['KAFKA_SASL_USERNAME'] = args.kafka_sasl_username
        os.environ['KAFKA_SASL_PASSWORD'] = args.kafka_sasl_password
    
    # Determine input files
    input_path = Path(args.input)
    
    if input_path.is_file():
        mp3_files = [input_path]
    elif input_path.is_dir():
        mp3_files = find_mp3_files(input_path)
        if not mp3_files:
            logger.error(f"No MP3 files found in {input_path}")
            sys.exit(1)
    else:
        logger.error(f"Input path does not exist: {input_path}")
        sys.exit(1)
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    logger.info(f"Found {len(mp3_files)} MP3 file(s)")
    logger.info(f"Output directory: {output_dir}")
    logger.info(f"Kafka: {args.kafka_bootstrap} (topic: {args.kafka_topic})")
    if args.no_kafka:
        logger.info("Kafka publishing: DISABLED")
    print()
    
    # Process files
    success_count = 0
    fail_count = 0
    
    for mp3_file in mp3_files:
        success = process_mp3_file(
            mp3_file,
            output_dir,
            publish_to_kafka=not args.no_kafka
        )
        if success:
            success_count += 1
        else:
            fail_count += 1
        print()
    
    # Summary
    logger.info("=" * 60)
    logger.info(f"Processing complete:")
    logger.info(f"  ✅ Success: {success_count}")
    logger.info(f"  ❌ Failed: {fail_count}")
    logger.info(f"  📁 Metadata JSON files: {output_dir}")
    
    # Close Kafka producer
    if not args.no_kafka:
        close_producer()
    
    sys.exit(0 if fail_count == 0 else 1)


if __name__ == '__main__':
    main()

