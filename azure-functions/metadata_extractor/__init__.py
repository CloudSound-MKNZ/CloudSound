"""
Azure Function: Audio Metadata Extractor

Triggered when MP3 files are uploaded to blob storage.
Extracts metadata (title, artist, album, duration, etc.) and publishes to Kafka.
"""
import logging
import json
import os
import io
import base64
from datetime import datetime
from typing import Dict, Any, Optional
import azure.functions as func
from metadata_utils import extract_metadata, generate_thumbnail_url
from kafka_utils import publish_metadata_event

logger = logging.getLogger(__name__)


def main(blob: func.InputStream, outputBlob: func.Out[str]) -> None:
    """
    Azure Function triggered when MP3 file is uploaded to blob storage.
    
    Args:
        blob: Input blob stream (MP3 file)
        outputBlob: Output blob for metadata JSON
    """
    blob_name = blob.name if hasattr(blob, 'name') else 'unknown'
    blob_size = blob.length if hasattr(blob, 'length') else 0
    
    logger.info(
        f'Processing blob: {blob_name}, Size: {blob_size} bytes'
    )
    
    try:
        # Read blob content into memory
        blob_data = blob.read()
        
        if not blob_data:
            logger.warning(f'Empty blob: {blob_name}')
            return
        
        # 1. Extract metadata from MP3
        logger.info(f'Extracting metadata from {blob_name}')
        metadata = extract_metadata(io.BytesIO(blob_data), blob_name)
        
        if not metadata:
            logger.error(f'Failed to extract metadata from {blob_name}')
            return
        
        # 2. Generate thumbnail URL if album art is available
        if metadata.get('album_art_data'):
            try:
                thumbnail_url = generate_thumbnail_url(
                    metadata['album_art_data'],
                    blob_name,
                    metadata.get('album_art_mime', 'image/jpeg')
                )
                if thumbnail_url:
                    metadata['thumbnail_url'] = thumbnail_url
            except Exception as e:
                logger.warning(f'Failed to generate thumbnail: {str(e)}')
        
        # 3. Add processing metadata
        metadata['processed_at'] = datetime.utcnow().isoformat()
        metadata['source_file'] = blob_name
        metadata['file_size'] = blob_size
        metadata['function_version'] = '1.0.0'
        
        # 4. Save metadata to blob storage (JSON)
        metadata_json = json.dumps(metadata, indent=2, default=str)
        outputBlob.set(metadata_json)
        
        logger.info(
            f'Metadata extracted successfully: {metadata.get("title", "Unknown")} '
            f'by {metadata.get("artist", "Unknown Artist")}'
        )
        
        # 5. Publish to Kafka for downstream processing
        try:
            publish_metadata_event(metadata)
            logger.info(f'Metadata event published to Kafka for {blob_name}')
        except Exception as e:
            logger.error(
                f'Failed to publish to Kafka: {str(e)}',
                exc_info=True
            )
            # Don't fail the function if Kafka publish fails
            # Metadata is still saved to blob storage
        
    except Exception as e:
        logger.error(
            f'Error processing blob {blob_name}: {str(e)}',
            exc_info=True
        )
        raise

