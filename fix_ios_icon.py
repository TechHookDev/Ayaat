#!/usr/bin/env python3
import os
from PIL import Image

def fix_icon():
    icon_path = 'assets/icon.png'
    if not os.path.exists(icon_path):
        print(f"Icon not found at {icon_path}")
        return

    # Open the existing icon
    img = Image.open(icon_path).convert("RGBA")
    
    # Create a new solid background image (1024x1024)
    # Color #1A237E matches the app's theme
    bg_color = (26, 35, 126, 255) 
    new_img = Image.new("RGBA", (1024, 1024), bg_color)
    
    # Get the logo part from the original image (cropping transparency)
    bbox = img.getbbox()
    if bbox:
        logo = img.crop(bbox)
        
        # Calculate size to fit nicely (about 80% of the canvas)
        # However, since the current icon is already centered in a larger canvas,
        # we might want to just scale it up or extract the raw logo.
        # Looking at the icon, the logo itself is quite large.
        
        target_size = 900 # Slightly smaller than 1024 to give some breathing room
        logo_w, logo_h = logo.size
        aspect = logo_w / logo_h
        
        if aspect > 1:
            new_w = target_size
            new_h = int(target_size / aspect)
        else:
            new_h = target_size
            new_w = int(target_size * aspect)
            
        logo_resized = logo.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Paste the logo onto the center of the blue background
        offset = ((1024 - new_w) // 2, (1024 - new_h) // 2)
        new_img.paste(logo_resized, offset, logo_resized)
        
    # Convert to RGB (no transparency) for iOS compatibility
    final_img = new_img.convert("RGB")
    final_img.save(icon_path, "PNG")
    print(f"Successfully updated {icon_path} with a solid background.")

if __name__ == "__main__":
    fix_icon()
