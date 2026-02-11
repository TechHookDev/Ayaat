#!/usr/bin/env python3
"""
Create proper Android adaptive icon foreground images.
The foreground should contain the content scaled to the adaptive icon 108dp grid.
"""
from PIL import Image
import os

def main():
    android_res = 'android/app/src/main/res'
    
    # Load the existing highest-res foreground
    source_path = f'{android_res}/drawable-xxxhdpi/ic_launcher_foreground.png'
    
    if not os.path.exists(source_path):
        print(f"Source not found: {source_path}")
        return
    
    source = Image.open(source_path).convert('RGBA')
    
    # Get the bounding box of non-transparent pixels
    bbox = source.getbbox()
    print(f"Source size: {source.size}")
    print(f"Content bbox: {bbox}")
    
    if not bbox:
        print("No content found in source image")
        return
    
    # Crop to just the content
    cropped = source.crop(bbox)
    print(f"Cropped size: {cropped.size}")
    
    # Android adaptive icon foreground sizes (108dp grid)
    # mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432
    sizes = {
        'drawable-mdpi': 108,
        'drawable-hdpi': 162,
        'drawable-xhdpi': 216,
        'drawable-xxhdpi': 324,
        'drawable-xxxhdpi': 432,
    }
    
    for folder, size in sizes.items():
        # Create canvas with transparent background
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        
        # Content should fit in the safe zone (center ~66% of 108dp = ~72dp)
        # But we want it to use about 80% of canvas for visual appeal
        content_size = int(size * 0.80)
        
        # Calculate new dimensions maintaining aspect ratio
        aspect = cropped.size[0] / cropped.size[1]
        if aspect > 1:
            new_w = content_size
            new_h = int(content_size / aspect)
        else:
            new_h = content_size
            new_w = int(content_size * aspect)
        
        # Resize content
        resized = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Center on canvas
        x = (size - new_w) // 2
        y = (size - new_h) // 2
        
        # Paste with alpha
        canvas.paste(resized, (x, y), resized)
        
        # Save
        out_path = f'{android_res}/{folder}/ic_launcher_foreground.png'
        canvas.save(out_path)
        print(f"Created: {out_path}")
    
    print("\nDone! Foreground icons have been updated.")
    print("The blue background is defined in values/colors.xml (#1A237E)")

if __name__ == '__main__':
    main()
