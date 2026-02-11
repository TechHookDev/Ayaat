#!/usr/bin/env python3
"""
Fix Android adaptive icon foreground images.
The foreground should only contain the calligraphy on a transparent background,
without any rounded corners or borders.
"""
from PIL import Image
import os

def create_foreground_from_icon(source_path, output_dir):
    """
    Create proper adaptive icon foreground images.
    For adaptive icons, the foreground needs extra safe zone padding.
    The visible area is about 66% of the total, centered.
    """
    # Load the source icon
    source = Image.open(source_path).convert('RGBA')
    source_size = source.size[0]
    
    # The source icon has the design with rounded corners.
    # We need to extract just the central portion (the actual content)
    # and place it on a transparent background.
    
    # For adaptive icons, we need the content to be in the safe zone (center 66%)
    # The full icon canvas is 108dp, but only the center 72dp is guaranteed visible
    # So we need to scale our content to fit in the center with proper padding
    
    # Android adaptive icon sizes for foreground
    sizes = {
        'drawable-mdpi': 108,
        'drawable-hdpi': 162,
        'drawable-xhdpi': 216,
        'drawable-xxhdpi': 324,
        'drawable-xxxhdpi': 432,
    }
    
    # First, let's crop the source to remove the white/transparent border
    # Find the bounding box of non-transparent pixels
    bbox = source.getbbox()
    if bbox:
        # Add a small margin
        margin = int(source_size * 0.05)
        bbox = (
            max(0, bbox[0] - margin),
            max(0, bbox[1] - margin),
            min(source_size, bbox[2] + margin),
            min(source_size, bbox[3] + margin)
        )
        cropped = source.crop(bbox)
    else:
        cropped = source
    
    # Now we need to extract just the calligraphy without the background
    # Since the source has a blue background with gold text, we need to isolate the text
    # We'll use the source as-is but remove the corners and any border effects
    
    # For a proper solution, let's create a mask based on the blue background
    # and invert it to get just the gold calligraphy
    
    # Actually, looking at the source, the icon has the calligraphy baked in
    # The best approach is to use the existing foreground but ensure it fills properly
    
    # Load the existing foreground to see if we can work with it
    existing_fg = f'{output_dir}/drawable-xxxhdpi/ic_launcher_foreground.png'
    if os.path.exists(existing_fg):
        fg_source = Image.open(existing_fg).convert('RGBA')
        
        # The issue is the foreground has rounded corners and shadow
        # We need to expand those edges to fill the canvas
        
        # Get the bounding box of non-transparent content
        fg_bbox = fg_source.getbbox()
        if fg_bbox:
            # Crop to content
            fg_cropped = fg_source.crop(fg_bbox)
            
            for folder, size in sizes.items():
                # Create a new transparent canvas
                canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
                
                # Calculate the size for the content
                # The safe zone is 66% of the icon, but we want the content 
                # to fill that nicely
                content_size = int(size * 0.75)  # 75% of canvas
                
                # Resize the cropped content
                aspect = fg_cropped.size[0] / fg_cropped.size[1]
                if aspect > 1:
                    new_w = content_size
                    new_h = int(content_size / aspect)
                else:
                    new_h = content_size
                    new_w = int(content_size * aspect)
                
                resized = fg_cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
                
                # Center on canvas
                x = (size - new_w) // 2
                y = (size - new_h) // 2
                
                # Paste the resized content
                canvas.paste(resized, (x, y), resized)
                
                # Save
                path = f'{output_dir}/{folder}/ic_launcher_foreground.png'
                canvas.save(path)
                print(f'Created {path}')
    
    print("\nForeground icons updated!")
    print("The background color is set in colors.xml (#1A237E)")

def main():
    android_res = 'android/app/src/main/res'
    source_icon = 'assets/icon.png'
    
    if not os.path.exists(source_icon):
        print(f"Error: Source icon not found at {source_icon}")
        return
    
    create_foreground_from_icon(source_icon, android_res)

if __name__ == '__main__':
    main()
