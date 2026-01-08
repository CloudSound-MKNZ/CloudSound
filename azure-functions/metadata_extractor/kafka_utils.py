"""
Kafka integration utilities for Azure Functions.

Publishes metadata extraction events to Kafka for downstream processing.
"""
import os
import json
import logging
from typing import Dict, Any, Optional
from kafka import KafkaProducer
from kafka.errors import KafkaError

logger = logging.getLogger(__name__)

# Global producer instance (reused across function invocations)
_producer: Optional[KafkaProducer] = None


def get_kafka_producer() -> Optional[KafkaProducer]:
    """
    Get or create Kafka producer instance.
    
    Returns:
        KafkaProducer instance, or None if Kafka is not configured
    """
    global _producer
    
    # Check if Kafka is configured
    bootstrap_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS')
    if not bootstrap_servers:
        logger.warning('KAFKA_BOOTSTRAP_SERVERS not configured, skipping Kafka publish')
        return None
    
    # Reuse existing producer if available
    if _producer is not None:
        return _producer
    
    try:
        # Create producer with configuration
        config = {
            'bootstrap_servers': bootstrap_servers.split(','),
            'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
            'key_serializer': lambda k: k.encode('utf-8') if k else None,
        }
        
        # Add security configuration if provided
        security_protocol = os.environ.get('KAFKA_SECURITY_PROTOCOL')
        if security_protocol:
            config['security_protocol'] = security_protocol
            
            if security_protocol in ['SASL_PLAINTEXT', 'SASL_SSL']:
                config['sasl_mechanism'] = os.environ.get('KAFKA_SASL_MECHANISM', 'PLAIN')
                config['sasl_plain_username'] = os.environ.get('KAFKA_SASL_USERNAME', '')
                config['sasl_plain_password'] = os.environ.get('KAFKA_SASL_PASSWORD', '')
        
        _producer = KafkaProducer(**config)
        logger.info(f'Kafka producer created: {bootstrap_servers}')
        
        return _producer
        
    except Exception as e:
        logger.error(f'Failed to create Kafka producer: {str(e)}', exc_info=True)
        return None


def publish_metadata_event(metadata: Dict[str, Any]) -> bool:
    """
    Publish metadata extraction event to Kafka.
    
    Args:
        metadata: Extracted metadata dictionary
        
    Returns:
        True if published successfully, False otherwise
    """
    producer = get_kafka_producer()
    if not producer:
        return False
    
    try:
        # Create event
        event = {
            'event_type': 'music.metadata.extracted',
            'track_id': metadata.get('track_id'),  # If provided
            'source_file': metadata.get('source_file'),
            'metadata': {
                'title': metadata.get('title'),
                'artist': metadata.get('artist'),
                'album': metadata.get('album'),
                'duration': metadata.get('duration'),
                'bitrate': metadata.get('bitrate'),
                'sample_rate': metadata.get('sample_rate'),
                'genre': metadata.get('genre'),
                'year': metadata.get('year'),
                'track_number': metadata.get('track_number'),
                'thumbnail_url': metadata.get('thumbnail_url'),
                'file_size': metadata.get('file_size'),
            },
            'processed_at': metadata.get('processed_at'),
            'function_version': metadata.get('function_version', '1.0.0'),
        }
        
        # Determine topic
        topic = os.environ.get('KAFKA_METADATA_TOPIC', 'music.metadata.extracted')
        
        # Use track_id or filename as key for partitioning
        key = metadata.get('track_id') or metadata.get('source_file', 'unknown')
        
        # Send to Kafka
        future = producer.send(topic, value=event, key=str(key))
        
        # Wait for send to complete (with timeout)
        record_metadata = future.get(timeout=10)
        
        logger.info(
            f'Metadata event published to Kafka: topic={record_metadata.topic}, '
            f'partition={record_metadata.partition}, offset={record_metadata.offset}'
        )
        
        return True
        
    except KafkaError as e:
        logger.error(f'Kafka error publishing metadata event: {str(e)}', exc_info=True)
        return False
    except Exception as e:
        logger.error(f'Error publishing metadata event: {str(e)}', exc_info=True)
        return False


def close_producer():
    """Close Kafka producer connection."""
    global _producer
    if _producer:
        try:
            _producer.flush()
            _producer.close()
            _producer = None
            logger.info('Kafka producer closed')
        except Exception as e:
            logger.error(f'Error closing Kafka producer: {str(e)}')

