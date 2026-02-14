#!/usr/bin/env python3
import os
from PIL import Image

def zoom_icon():
    icon_path = 'assets/icon.png'
    if not os.path.exists(icon_path):
        print(f"Icon not found at {icon_path}")
        return

    # Open the existing icon (restored original)
    img = Image.open(icon_path).convert("RGBA")
    
    # Aggressive Zoom factor: 1.6x (160%)
    # This is mathematically enough to push the rounded corners of a full-size rounded box 
    # completely out of the 1024x1024 square.
    zoom_factor = 1.6
    new_size = int(1024 * zoom_factor)
    
    # Resize the image
    zoomed_img = img.resize((new_size, new_size), Image.Resampling.LANCZOS)
    
    # Calculate crop coordinates to get back to 1024x1024 from the center
    left = (new_size - 1024) // 2
    top = (new_size - 1024) // 2
    right = left + 1024
    bottom = top + 1024
    
    # Crop the center
    final_img = zoomed_img.crop((left, top, right, bottom))
    
    # Final check: Paste onto a solid blue background to fill any potential 1px gaps
    bg_color = (25, 34, 124) # Sampled core blue #19227C
    background = Image.new("RGB", (1024, 1024), bg_color)
    
    # Paste using the final_img as its own mask (if it still has alpha)
    if img.mode == 'RGBA':
        background.paste(final_img, (0, 0), final_img)
    else:
        background.paste(final_img, (0, 0))
    
    # Save as pure RGB (no alpha) to prevent iOS framing issues
    background.save(icon_path, "PNG")
    print(f"Successfully zoomed and updated {icon_path} aggressively. Zoom factor: {zoom_factor}")

if __name__ == "__main__":
    zoom_icon()
