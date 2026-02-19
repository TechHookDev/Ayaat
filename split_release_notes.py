import os

def get_version_info():
    """Extracts version name and code from pubspec.yaml"""
    try:
        with open('pubspec.yaml', 'r') as f:
            for line in f:
                if line.strip().startswith('version:'):
                    # Format: version: 1.0.7+11
                    version_str = line.split(':')[1].strip()
                    if '+' in version_str:
                        version_name, version_code = version_str.split('+')
                        return version_name, version_code
                    else:
                        return version_str, None
    except FileNotFoundError:
        print("Error: pubspec.yaml not found.")
        return None, None
    return None, None

def split_release_notes():
    version_name, version_code = get_version_info()
    
    if not version_name:
        print("Error: Could not determine version from pubspec.yaml")
        return

    input_file = f"release_notes_v{version_name}.txt"
    
    if not os.path.exists(input_file):
        print(f"Error: Release notes file '{input_file}' not found.")
        print(f"Please create {input_file} before running this script.")
        # Fallback to play store notes if specific version not found?
        # No, better to fail loud so we know something is wrong.
        return

    print(f"Processing release notes for version {version_name} (Code: {version_code}) from {input_file}...")

    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split by language headers
    # release_notes_v1.0.7.txt format is:
    # en-US
    # Notes...
    #
    # ar-SA
    # Notes...
    
    sections = content.split('\n\n')
    current_lang = None
    note_content = []

    # Map language codes to Android Fastlane folder names if needed
    # Default matching is usually fine (en-US, ar-SA, fr-FR)

    base_dir = "android/fastlane/metadata/android"
    
    # Use version code for Android changelogs if available, otherwise just print warning
    if not version_code:
        print("Warning: No version code found. Android changelogs require a version code.")
        version_code = "1" # Fallback

    lines = content.splitlines()
    for i, line in enumerate(lines):
        line = line.strip()
        
        # Check if line is a language code
        if line in ['en-US', 'ar-SA', 'fr-FR', 'en-GB']:
            # Save previous language if exists
            if current_lang and note_content:
                save_note(base_dir, current_lang, version_code, '\n'.join(note_content))
                save_ios_note(current_lang, '\n'.join(note_content)) # Save IOS too
            
            current_lang = line
            note_content = []
        elif line:
            # Append non-empty lines to content
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
    split_release_notes()

