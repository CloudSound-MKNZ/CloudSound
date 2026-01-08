"""
Metadata extraction utilities for MP3 files.

Uses mutagen library to extract ID3 tags and audio properties.
"""
import io
import base64
from typing import Dict, Any, Optional
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, TIT2, TPE1, TALB, TCON, TDRC, TRCK, APIC
from mutagen import File
from PIL import Image
import logging

logger = logging.getLogger(__name__)

logger = logging.getLogger(__name__)


def extract_metadata(blob_stream: io.BytesIO, filename: str) -> Optional[Dict[str, Any]]:
    """
    Extract metadata from MP3 file using mutagen library.
    
    Args:
        blob_stream: File stream of MP3 file
        filename: Original filename (for fallback)
        
    Returns:
        Dictionary with extracted metadata, or None if extraction fails
    """
    try:
        # Reset stream position
        blob_stream.seek(0)
        
        # Load audio file (mutagen can handle MP3 and other formats)
        audio_file = File(blob_stream, filename=filename)
        
        if audio_file is None:
            logger.warning(f'Could not parse audio file: {filename}')
            return None
        
        # Initialize metadata dict
        metadata: Dict[str, Any] = {
            'filename': filename,
            'source': 'unknown'
        }
        
        # Extract basic audio properties
        if hasattr(audio_file, 'info'):
            info = audio_file.info
            metadata.update({
                'duration': int(info.length) if hasattr(info, 'length') else 0,
                'bitrate': getattr(info, 'bitrate', 0),
                'sample_rate': getattr(info, 'sample_rate', 0),
                'channels': getattr(info, 'channels', 0),
            })
        
        # Extract ID3 tags if available
        if hasattr(audio_file, 'tags') and audio_file.tags is not None:
            tags = audio_file.tags
            
            # Title
            if 'TIT2' in tags:
                metadata['title'] = str(tags['TIT2'][0])
            elif 'TITLE' in tags:
                metadata['title'] = str(tags['TITLE'][0])
            
            # Artist
            if 'TPE1' in tags:
                metadata['artist'] = str(tags['TPE1'][0])
            elif 'ARTIST' in tags:
                metadata['artist'] = str(tags['ARTIST'][0])
            
            # Album
            if 'TALB' in tags:
                metadata['album'] = str(tags['TALB'][0])
            elif 'ALBUM' in tags:
                metadata['album'] = str(tags['ALBUM'][0])
            
            # Genre
            if 'TCON' in tags:
                metadata['genre'] = str(tags['TCON'][0])
            elif 'GENRE' in tags:
                metadata['genre'] = str(tags['GENRE'][0])
            
            # Year
            if 'TDRC' in tags:
                year_str = str(tags['TDRC'][0])
                # Extract year from date string
                if year_str:
                    year = year_str[:4] if len(year_str) >= 4 else year_str
                    metadata['year'] = year
            elif 'DATE' in tags:
                date_str = str(tags['DATE'][0])
                if date_str:
                    metadata['year'] = date_str[:4] if len(date_str) >= 4 else date_str
            
            # Track number
            if 'TRCK' in tags:
                track_str = str(tags['TRCK'][0])
                # Handle "1/10" format
                if '/' in track_str:
                    track_str = track_str.split('/')[0]
                try:
                    metadata['track_number'] = int(track_str)
                except ValueError:
                    metadata['track_number'] = track_str
            elif 'TRACKNUMBER' in tags:
                metadata['track_number'] = str(tags['TRACKNUMBER'][0])
            
            # Album art (APIC frame)
            if 'APIC:' in tags:
                apic = tags['APIC:'].data
                metadata['album_art_data'] = base64.b64encode(apic).decode('utf-8')
                metadata['album_art_mime'] = tags['APIC:'].mime
                metadata['album_art_description'] = tags['APIC:'].desc
            elif 'APIC' in tags:
                # Handle multiple APIC frames (use first one)
                apic = tags['APIC'][0]
                if hasattr(apic, 'data'):
                    metadata['album_art_data'] = base64.b64encode(apic.data).decode('utf-8')
                    metadata['album_art_mime'] = apic.mime
                    metadata['album_art_description'] = apic.desc
        
        # Fallback: Extract from filename if no tags
        if 'title' not in metadata or not metadata['title']:
            # Try to extract from filename (remove extension)
            name_without_ext = filename.rsplit('.', 1)[0]
            metadata['title'] = name_without_ext
        
        # Set source format
        if isinstance(audio_file, MP3):
            metadata['source'] = 'mp3'
        else:
            metadata['source'] = audio_file.mime[0] if hasattr(audio_file, 'mime') else 'unknown'
        
        logger.info(
            f'Extracted metadata: {metadata.get("title")} by {metadata.get("artist")}'
        )
        
        return metadata
        
    except Exception as e:
        logger.error(f'Error extracting metadata: {str(e)}', exc_info=True)
        return None


def generate_thumbnail_url(
    album_art_data: str,
    filename: str,
    mime_type: str = 'image/jpeg'
) -> Optional[str]:
    """
    Generate thumbnail from album art.
    
    In a real implementation, this would:
    1. Decode base64 image
    2. Resize to thumbnail (300x300)
    3. Upload to blob storage
    4. Return URL
    
    For now, returns a placeholder URL structure.
    
    Args:
        album_art_data: Base64-encoded album art image
        filename: Original filename (for naming)
        mime_type: MIME type of image
        
    Returns:
        URL to thumbnail (placeholder for now)
    """
    try:
        # Decode base64 image
        image_data = base64.b64decode(album_art_data)
        image = Image.open(io.BytesIO(image_data))
        
        # Resize to thumbnail (300x300, maintain aspect ratio)
        image.thumbnail((300, 300), Image.Resampling.LANCZOS)
        
        # In production, upload to blob storage here
        # For now, return placeholder URL
        thumbnail_name = filename.rsplit('.', 1)[0] + '_thumb.jpg'
        
        # Placeholder: In Azure, this would be:
        # https://<storage-account>.blob.core.windows.net/thumbnails/{thumbnail_name}
        thumbnail_url = f"https://storage.azure.com/thumbnails/{thumbnail_name}"
        
        logger.info(f'Generated thumbnail URL: {thumbnail_url}')
        return thumbnail_url
        
    except Exception as e:
        logger.warning(f'Failed to generate thumbnail: {str(e)}')
        return None

