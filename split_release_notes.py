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
        full_text = '\n'.join(note_content)
        save_note(base_dir, current_lang, version_code, full_text)
        save_ios_note(current_lang, full_text)

def save_note(base_dir, lang, version, text):
    # Fastlane structure: android/fastlane/metadata/android/[lang]/changelogs/[version_code].txt
    path = os.path.join(base_dir, lang, 'changelogs')
    os.makedirs(path, exist_ok=True)
    
    file_path = os.path.join(path, f"{version}.txt")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"Created Android note for {lang}: {file_path}")

def save_ios_note(lang, text):
    # Fastlane structure: ios/fastlane/metadata/[lang]/release_notes.txt
    # Map Android lang codes to iOS if needed (usually similar)
    ios_base_dir = "ios/fastlane/metadata"
    path = os.path.join(ios_base_dir, lang)
    os.makedirs(path, exist_ok=True)
    
    file_path = os.path.join(path, "release_notes.txt")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"Created iOS note for {lang}: {file_path}")

if __name__ == "__main__":
    split_release_notes("release_notes_v1.0.6.txt")
