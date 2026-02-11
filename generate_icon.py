from PIL import Image, ImageDraw, ImageFont
import os

# Create a large icon (1024x1024)
size = 1024
img = Image.new('RGBA', (size, size), (26, 35, 126, 255))  # Blue background #1A237E
draw = ImageDraw.Draw(img)

# Try to find an Arabic font
font_paths = [
    '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Bold.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
]

font = None
for path in font_paths:
    if os.path.exists(path):
        try:
            font = ImageFont.truetype(path, 350)
            print(f"Using font: {path}")
            break
        except:
            pass

if font is None:
    font = ImageFont.load_default()
    print("Using default font")

# Draw the Arabic text "آيات" in golden color
text = "آيات"
golden_color = (255, 215, 0, 255)  # #FFD700

# Get text size
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]

# Center the text
x = (size - text_width) // 2
y = (size - text_height) // 2 - 50  # Slight adjustment

draw.text((x, y), text, font=font, fill=golden_color)

# Save the icon
os.makedirs('assets', exist_ok=True)
img.save('assets/icon.png')
print("Icon saved to assets/icon.png")

# Also create Android launcher icons
sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

android_res = 'android/app/src/main/res'
for folder, icon_size in sizes.items():
    resized = img.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    path = f'{android_res}/{folder}/ic_launcher.png'
    resized.save(path)
    print(f"Created {path}")

print("\nAll icons generated successfully!")
