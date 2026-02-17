from PIL import Image
import os

# Source images (Tablet)
sources = [
    'assets/tablet_screenshot_welcome.png',
    'assets/tablet_screenshot_home.png',
    'assets/tablet_screenshot_surah_list.png',
    'assets/tablet_screenshot_settings.png',
    'assets/tablet_screenshot_reader.png'
]

# Target size: 12.9 inch iPad Pro (2nd/3rd Gen)
# This size (2048 x 2732) is accepted for the "12.9-inch" requirement
target_w = 2048
target_h = 2732

output_dir = 'ios_screenshots'
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

for src in sources:
    if os.path.exists(src):
        print(f"Processing {src}...")
        img = Image.open(src).convert('RGB')
        
        # Create new blank image
        new_img = Image.new('RGB', (target_w, target_h), (13, 27, 42)) # Deep Blue
        
        # Resize logic: fit width
        ratio = target_w / img.width
        new_h_scaled = int(img.height * ratio)
        
        resized = img.resize((target_w, new_h_scaled), Image.Resampling.LANCZOS)
        
        # Center vertically
        y_offset = (target_h - new_h_scaled) // 2
        
        new_img.paste(resized, (0, y_offset))
        
        basename = os.path.basename(src).replace('.png', '').replace('tablet_', '')
        filename = f'{basename}_ipad_12.9.png'
        outfile = os.path.join(output_dir, filename)
        new_img.save(outfile)
        print(f'Generated {outfile}')
    else:
        print(f"Warning: {src} not found")
