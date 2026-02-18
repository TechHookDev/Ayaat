import os

def split_release_notes(input_file):
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split by language headers
    sections = content.split('\n\n')
    current_lang = None
    note_content = []

    # Map language codes to Android Fastlane folder names if needed
    # Default matching is usually fine (en-US, ar-SA, fr-FR)

    base_dir = "android/fastlane/metadata/android"
    version_code = "10" # Hardcoded for this release, or read from pubspec

    for line in content.splitlines():
        line = line.strip()
        if not line: continue
        
        if line in ['en-US', 'ar-SA', 'fr-FR']:
            # Save previous
            if current_lang and note_content:
                save_note(base_dir, current_lang, version_code, '\n'.join(note_content))
            
            current_lang = line
            note_content = []
        else:
            note_content.append(line)
            
    # Save last one
    if current_lang and note_content:
        save_note(base_dir, current_lang, version_code, '\n'.join(note_content))

def save_note(base_dir, lang, version, text):
    # Fastlane structure: android/fastlane/metadata/android/[lang]/changelogs/[version_code].txt
    path = os.path.join(base_dir, lang, 'changelogs')
    os.makedirs(path, exist_ok=True)
    
    file_path = os.path.join(path, f"{version}.txt")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"Created release note for {lang}: {file_path}")

if __name__ == "__main__":
    split_release_notes("release_notes_v1.0.6.txt")
