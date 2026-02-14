"""
Generate audio narration for Cortex Masterclass modules using Amit's voice clone.
Integrates with the Chartterbox voice cloning pipeline.

Usage:
    python generate_cortex_audio.py --module 1 --audio-only
    python generate_cortex_audio.py --module 2 --audio-only
    python generate_cortex_audio.py --all --audio-only
"""
import sys
import os
import re
from datetime import datetime
from pathlib import Path
import subprocess

# Add Chartterbox to path
CHARTTERBOX_PATH = r"C:\Work\code\Voice_Clone\Chartterbox"
sys.path.insert(0, CHARTTERBOX_PATH)

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "video_scripts"
OUTPUT_DIR = PROJECT_ROOT / "video_automation" / "output" / "audio"

def parse_narration_from_script(script_path):
    """
    Extract narration text from video script.

    Returns:
        List of dicts: [
            {
                'slide_num': 1,
                'timestamp': '00:00-00:30',
                'section': 'Section Title',
                'narration': 'Full narration text...'
            },
            ...
        ]
    """
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    narrations = []
    slide_num = 0

    # Split by section headers (## [timestamp] Section Name)
    sections = re.split(r'\n## \[([^\]]+)\] ([^\n]+)', content)

    for i in range(1, len(sections), 3):
        if i + 2 >= len(sections):
            break

        timestamp = sections[i].strip()
        section_name = sections[i + 1].strip()
        section_content = sections[i + 2].strip()

        # Extract narration (quoted text after SCRIPT: or direct quotes)
        # Handle both straight quotes and smart quotes
        narration_matches = re.findall(r'(?:\*\*SCRIPT:\*\*\s*)?["\u201c]([^"\u201d]+)["\u201d]', section_content)

        if narration_matches:
            slide_num += 1
            narration_text = ' '.join(narration_matches)

            # Clean up narration text
            narration_text = narration_text.strip()
            narration_text = re.sub(r'\s+', ' ', narration_text)  # Normalize whitespace

            narrations.append({
                'slide_num': slide_num,
                'timestamp': timestamp,
                'section': section_name,
                'narration': narration_text
            })

    return narrations

def generate_slide_audio(narration_text, output_path, slide_num, section_name):
    """
    Generate audio for a single slide using Amit's voice.

    Args:
        narration_text: Text to narrate
        output_path: Where to save the audio file
        slide_num: Slide number (for logging)
        section_name: Section name (for logging)
    """
    # Create temporary text file for amit_narrate.py
    temp_dir = OUTPUT_DIR / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)

    temp_script = temp_dir / f"slide_{slide_num:02d}_script.txt"

    with open(temp_script, 'w', encoding='utf-8') as f:
        f.write(narration_text)

    print(f"  🎤 Generating audio for slide {slide_num}: {section_name}")
    print(f"     Narration length: {len(narration_text)} chars")

    # Call amit_narrate.py
    amit_script = Path(CHARTTERBOX_PATH) / "amit_narrate.py"

    try:
        # Run amit_narrate.py with the temp script
        result = subprocess.run(
            [sys.executable, str(amit_script), str(temp_script)],
            cwd=CHARTTERBOX_PATH,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout per slide
        )

        if result.returncode != 0:
            print(f"     ❌ Error generating audio:")
            print(f"     {result.stderr}")
            return None

        # amit_narrate.py saves to Amit_Clone/amit_TIMESTAMP.wav
        # Find the most recent file
        amit_clone_dir = Path(CHARTTERBOX_PATH) / "Amit_Clone"
        audio_files = sorted(amit_clone_dir.glob("amit_*.wav"), key=lambda p: p.stat().st_mtime, reverse=True)

        if not audio_files:
            print(f"     ❌ No audio file generated")
            return None

        latest_audio = audio_files[0]

        # Move to our output directory with proper naming
        output_path.parent.mkdir(parents=True, exist_ok=True)

        import shutil
        shutil.move(str(latest_audio), str(output_path))

        print(f"     ✅ Audio saved: {output_path.name}")

        # Clean up temp file
        temp_script.unlink()

        return output_path

    except subprocess.TimeoutExpired:
        print(f"     ❌ Timeout generating audio (>5 min)")
        return None
    except Exception as e:
        print(f"     ❌ Error: {e}")
        return None

def generate_module_audio(module_num):
    """Generate audio for all slides in a module."""

    # Find script file
    script_files = {
        1: SCRIPTS_DIR / "module_01_script.md",
        2: SCRIPTS_DIR / "module_02_script.md"
    }

    if module_num not in script_files:
        print(f"❌ Module {module_num} script not found")
        return None

    script_path = script_files[module_num]
    if not script_path.exists():
        print(f"❌ Script file not found: {script_path}")
        return None

    print(f"\n{'='*70}")
    print(f"Generating Audio: Module {module_num}")
    print(f"{'='*70}\n")
    print(f"📄 Reading script: {script_path.name}")

    # Parse narration from script
    narrations = parse_narration_from_script(script_path)
    print(f"✅ Found {len(narrations)} narration segments\n")

    if not narrations:
        print("❌ No narration found in script")
        return None

    # Create output directory for this module
    module_output_dir = OUTPUT_DIR / f"module_{module_num:02d}"
    module_output_dir.mkdir(parents=True, exist_ok=True)

    # Generate audio for each slide
    audio_files = []
    total_start = datetime.now()

    for idx, narration in enumerate(narrations, 1):
        slide_num = narration['slide_num']
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_file = module_output_dir / f"slide_{slide_num:02d}_audio_{timestamp}_complete.wav"

        slide_start = datetime.now()

        audio_path = generate_slide_audio(
            narration['narration'],
            output_file,
            slide_num,
            narration['section']
        )

        if audio_path:
            audio_files.append(audio_path)
            elapsed = (datetime.now() - slide_start).total_seconds()
            print(f"     ⏱️  Time: {elapsed:.1f}s\n")
        else:
            print(f"     ⚠️  Skipping slide {slide_num}\n")

    total_elapsed = (datetime.now() - total_start).total_seconds()

    print(f"\n{'='*70}")
    print(f"✅ AUDIO GENERATION COMPLETE")
    print(f"{'='*70}")
    print(f"Generated {len(audio_files)}/{len(narrations)} audio files")
    print(f"Total time: {total_elapsed/60:.1f} minutes")
    print(f"Output directory: {module_output_dir}")
    print(f"{'='*70}\n")

    return module_output_dir

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Generate Cortex Masterclass audio narration')
    parser.add_argument('--module', type=int, choices=[1, 2], help='Module number (1 or 2)')
    parser.add_argument('--all', action='store_true', help='Generate audio for all modules')
    parser.add_argument('--audio-only', action='store_true', help='Only generate audio (compatible with Chartterbox workflow)')

    args = parser.parse_args()

    if not args.module and not args.all:
        parser.print_help()
        return

    modules = [1, 2] if args.all else [args.module]

    print(f"\n{'='*70}")
    print(f"Cortex Masterclass - Audio Generator")
    print(f"{'='*70}")
    print(f"Voice: Amit (Chatterbox TTS)")
    print(f"Chartterbox path: {CHARTTERBOX_PATH}")
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"{'='*70}\n")

    generated_dirs = []
    for module_num in modules:
        output_dir = generate_module_audio(module_num)
        if output_dir:
            generated_dirs.append(output_dir)

    print(f"\n{'='*70}")
    print(f"SUMMARY")
    print(f"{'='*70}")
    print(f"Generated audio for {len(generated_dirs)} modules:")
    for d in generated_dirs:
        audio_count = len(list(d.glob("slide_*_audio_*_complete.wav")))
        print(f"  ✅ {d.name}: {audio_count} audio files")
    print(f"\n{'='*70}")
    print(f"Next steps:")
    print(f"  1. Review audio files: {OUTPUT_DIR}")
    print(f"  2. Create videos: python create_cortex_videos.py --module <N> --use-existing-audio")
    print(f"{'='*70}\n")

if __name__ == "__main__":
    main()
