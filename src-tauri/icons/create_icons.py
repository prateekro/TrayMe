#!/usr/bin/env python3
import struct
import zlib

def create_rgba_png(filename, width, height, color=(100, 108, 255, 255)):
    """Create a simple RGBA PNG file"""
    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk (color type 6 = RGBA)
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data) & 0xffffffff
    ihdr_chunk = struct.pack('>I', 13) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc)
    
    # IDAT chunk (compressed image data)
    pixels = b''
    for y in range(height):
        pixels += b'\x00'  # filter type
        for x in range(width):
            pixels += bytes(color)
    
    compressed = zlib.compress(pixels, 9)
    idat_crc = zlib.crc32(b'IDAT' + compressed) & 0xffffffff
    idat_chunk = struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc)
    
    # IEND chunk
    iend_crc = zlib.crc32(b'IEND') & 0xffffffff
    iend_chunk = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)
    
    with open(filename, 'wb') as f:
        f.write(signature + ihdr_chunk + idat_chunk + iend_chunk)

# Create icons
create_rgba_png('32x32.png', 32, 32)
create_rgba_png('128x128.png', 128, 128)
create_rgba_png('128x128@2x.png', 256, 256)
create_rgba_png('icon.png', 512, 512)
print("RGBA Icons created successfully")
