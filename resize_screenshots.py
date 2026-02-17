from PIL import Image
import os

# Source images
sources = [
    'assets/screenshot_welcome.png',
    'assets/screenshot_home.png',
    'assets/screenshot_surah_list.png',
    'assets/screenshot_settings.png',
    'assets/screenshot_picker.png'
]

# Target sizes
# 6.5 inch (iPhone 11 Pro Max, XS Max, 14 Plus)
# 5.5 inch (iPhone 8 Plus)
sizes = {
    '6.5': (1242, 2688),
    '5.5': (1242, 2208)
}

output_dir = 'ios_screenshots'
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

for src in sources:
    if os.path.exists(src):
        print(f"Processing {src}...")
        img = Image.open(src).convert('RGB')
        
        for size_name, (target_w, target_h) in sizes.items():
            # Create new blank image with target size
            new_img = Image.new('RGB', (target_w, target_h), (13, 27, 42)) # Background color #0D1B2A from app theme
            
            # Calculate scaling to fit width
            # We want to fit the width perfectly, and crop/pad height
            ratio = target_w / img.width
            new_h = int(img.height * ratio)
            
            resized = img.resize((target_w, new_h), Image.Resampling.LANCZOS)
            
            # Center the image vertically
            y_offset = (target_h - new_h) // 2
            
            new_img.paste(resized, (0, y_offset))
            
            basename = os.path.basename(src).replace('.png', '')
            filename = f'{basename}_iphone_{size_name}.png'
            outfile = os.path.join(output_dir, filename)
            new_img.save(outfile)
            print(f'Generated {outfile}')
    else:
        print(f"Warning: {src} not found")
