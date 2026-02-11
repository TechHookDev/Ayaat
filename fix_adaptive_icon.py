#!/usr/bin/env python3
"""
Create proper adaptive icon by extracting ONLY the gold calligraphy
from the source icon and placing it on a transparent background.
The blue background will come from the adaptive icon background color.
"""
from PIL import Image
import os

def extract_calligraphy(source_path):
    """
    Extract the gold calligraphy by removing the blue background.
    The calligraphy is gold/yellow colored on a blue background.
    """
    source = Image.open(source_path).convert('RGBA')
    pixels = source.load()
    width, height = source.size
    
    # Create output with transparent background
    output = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    out_pixels = output.load()
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            
            # Skip fully transparent pixels
            if a == 0:
                continue
            
            # The blue background color is approximately #1A237E (26, 35, 126)
            # The gold calligraphy is yellow/gold tones
            # We want to KEEP pixels that are more yellow/gold (high R, high G, low-medium B)
            # and REMOVE pixels that are blue (low R, low G, high B)
            
            # Calculate how "golden" vs "blue" the pixel is
            # Gold has high red and green, blue has low red and green but high blue
            
            # Keep pixels that are more gold/yellow (high R, high G relative to B)
            is_gold = (r > 150 and g > 100) or (r + g > b * 2 and r > 80 and g > 60)
            
            if is_gold:
                out_pixels[x, y] = (r, g, b, a)
            else:
                out_pixels[x, y] = (0, 0, 0, 0)
    
    return output

def main():
    source_path = 'assets/icon.png'
    android_res = 'android/app/src/main/res'
    
    print("Extracting gold calligraphy from source icon...")
    calligraphy = extract_calligraphy(source_path)
    
    # Trim transparent edges
    bbox = calligraphy.getbbox()
    if bbox:
        calligraphy = calligraphy.crop(bbox)
        print(f"Calligraphy size after trim: {calligraphy.size}")
    
    # Save extracted calligraphy for reference
    calligraphy.save('assets/calligraphy_only.png')
    print("Saved extracted calligraphy to assets/calligraphy_only.png")
    
    # Adaptive icon foreground sizes
    sizes = {
        'drawable-mdpi': 108,
        'drawable-hdpi': 162,
        'drawable-xhdpi': 216,
        'drawable-xxhdpi': 324,
        'drawable-xxxhdpi': 432,
    }
    
    for folder, size in sizes.items():
        # Place calligraphy at 66% of canvas (adaptive icon safe zone)
        content_size = int(size * 0.66)
        
        # Maintain aspect ratio
        aspect = calligraphy.size[0] / calligraphy.size[1]
        if aspect > 1:
            new_w = content_size
            new_h = int(content_size / aspect)
        else:
            new_h = content_size
            new_w = int(content_size * aspect)
        
        resized = calligraphy.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Center on transparent canvas
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        x = (size - new_w) // 2
        y = (size - new_h) // 2
        canvas.paste(resized, (x, y), resized)
        
        # Save
        out_path = f'{android_res}/{folder}/ic_launcher_foreground.png'
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        canvas.save(out_path)
        print(f"Created {out_path}")
    
    print("\n✓ Done! The foreground now has ONLY the gold calligraphy on transparent background.")
    print("The blue background comes from colors.xml (#1A237E)")

if __name__ == '__main__':
    main()
