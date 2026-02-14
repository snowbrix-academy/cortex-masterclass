"""
Create videos for Cortex Masterclass modules by combining slides + audio.
Integrates with the Chartterbox video creation pipeline.

Usage:
    python create_cortex_videos.py --module 1 --use-existing-audio
    python create_cortex_videos.py --module 2 --use-existing-audio
    python create_cortex_videos.py --all --use-existing-audio
"""
import sys
import os
import subprocess
from datetime import datetime
from pathlib import Path

# Add Chartterbox video automation to path
CHARTTERBOX_PATH = r"C:\Work\code\Voice_Clone\Chartterbox\_video_automation"
sys.path.insert(0, CHARTTERBOX_PATH)

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SLIDES_DIR = PROJECT_ROOT / "video_automation" / "output" / "slides"
AUDIO_DIR = PROJECT_ROOT / "video_automation" / "output" / "audio"
VIDEO_OUTPUT_DIR = PROJECT_ROOT / "video_automation" / "output" / "videos"

def find_latest_slide_deck(module_num):
    """Find the most recently generated slide deck for a module."""
    pattern = f"Module_{module_num:02d}_Cortex_Analyst_*.pptx"
    slide_files = sorted(SLIDES_DIR.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True)

    if not slide_files:
        return None

    return slide_files[0]

def find_audio_files(module_num):
    """Find all audio files for a module."""
    module_audio_dir = AUDIO_DIR / f"module_{module_num:02d}"

    if not module_audio_dir.exists():
        return []

    audio_files = sorted(module_audio_dir.glob("slide_*_audio_*_complete.wav"))
    return audio_files

def create_video_with_chartterbox(slide_deck, audio_dir, output_file):
    """
    Create video using Chartterbox video_creator.py.

    Args:
        slide_deck: Path to PowerPoint file
        audio_dir: Directory containing audio files
        output_file: Where to save the video
    """
    video_creator = Path(CHARTTERBOX_PATH) / "video_creator.py"

    print(f"  🎬 Running Chartterbox video_creator.py...")
    print(f"     Slides: {slide_deck.name}")
    print(f"     Audio: {audio_dir.name}")

    try:
        # Copy audio files to Chartterbox _projects structure
        # video_creator.py expects audio in _projects/[name]/output/slide_XX_audio_*_complete.wav

        chartterbox_root = Path(CHARTTERBOX_PATH).parent
        project_name = slide_deck.stem  # e.g., "Module_01_Cortex_Analyst_20260214_123456"
        chartterbox_project_dir = chartterbox_root / "_projects" / project_name / "output"
        chartterbox_project_dir.mkdir(parents=True, exist_ok=True)

        # Copy audio files
        import shutil
        audio_files = list(audio_dir.glob("slide_*_audio_*_complete.wav"))
        print(f"     Copying {len(audio_files)} audio files to Chartterbox project...")

        for audio_file in audio_files:
            dest = chartterbox_project_dir / audio_file.name
            if not dest.exists():
                shutil.copy2(audio_file, dest)

        print(f"     ✅ Audio files copied to: {chartterbox_project_dir}")

        # Run video_creator.py with --use-existing-audio
        cmd = [
            sys.executable,
            str(video_creator),
            str(slide_deck),
            "--use-existing-audio",
            "--output", str(output_file)
        ]

        print(f"     🎥 Creating video...")
        result = subprocess.run(
            cmd,
            cwd=str(chartterbox_root),
            capture_output=True,
            text=True,
            timeout=600  # 10 minute timeout
        )

        if result.returncode != 0:
            print(f"     ❌ Error creating video:")
            print(f"     {result.stderr}")
            return None

        print(f"     ✅ Video created: {output_file.name}")
        return output_file

    except subprocess.TimeoutExpired:
        print(f"     ❌ Timeout creating video (>10 min)")
        return None
    except Exception as e:
        print(f"     ❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def create_module_video(module_num):
    """Create video for a specific module."""

    print(f"\n{'='*70}")
    print(f"Creating Video: Module {module_num}")
    print(f"{'='*70}\n")

    # Find slide deck
    slide_deck = find_latest_slide_deck(module_num)
    if not slide_deck:
        print(f"❌ No slide deck found for Module {module_num}")
        print(f"   Run: python generate_cortex_slides.py --module {module_num}")
        return None

    print(f"✅ Found slide deck: {slide_deck.name}")

    # Find audio files
    audio_dir = AUDIO_DIR / f"module_{module_num:02d}"
    audio_files = find_audio_files(module_num)

    if not audio_files:
        print(f"❌ No audio files found for Module {module_num}")
        print(f"   Run: python generate_cortex_audio.py --module {module_num} --audio-only")
        return None

    print(f"✅ Found {len(audio_files)} audio files in: {audio_dir.name}\n")

    # Create output directory
    VIDEO_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Output file
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = VIDEO_OUTPUT_DIR / f"Module_{module_num:02d}_Cortex_Analyst_{timestamp}.mp4"

    # Create video
    start_time = datetime.now()
    video_path = create_video_with_chartterbox(slide_deck, audio_dir, output_file)
    elapsed = (datetime.now() - start_time).total_seconds()

    if video_path:
        print(f"\n{'='*70}")
        print(f"✅ VIDEO CREATED")
        print(f"{'='*70}")
        print(f"Module: {module_num}")
        print(f"Duration: {elapsed:.1f}s")
        print(f"Output: {video_path}")
        print(f"{'='*70}\n")
    else:
        print(f"\n❌ Failed to create video for Module {module_num}\n")

    return video_path

def generate_broll_checklist(module_num):
    """
    Generate a checklist of B-roll screen recordings needed for a module.

    Reads the video script and extracts all [SCREEN:] cues.
    """
    script_files = {
        1: PROJECT_ROOT / "video_scripts" / "module_01_script.md",
        2: PROJECT_ROOT / "video_scripts" / "module_02_script.md"
    }

    script_path = script_files.get(module_num)
    if not script_path or not script_path.exists():
        return None

    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    import re
    screen_cues = re.findall(r'\*\*\[SCREEN:\s*([^\]]+)\]\*\*', content)

    if not screen_cues:
        print(f"   ℹ️  No B-roll needed for Module {module_num}")
        return None

    # Save checklist
    checklist_file = VIDEO_OUTPUT_DIR / f"Module_{module_num:02d}_BRoll_Checklist.md"

    with open(checklist_file, 'w', encoding='utf-8') as f:
        f.write(f"# Module {module_num} - B-Roll Recording Checklist\n\n")
        f.write(f"**Total B-roll segments:** {len(screen_cues)}\n\n")
        f.write("---\n\n")

        for idx, cue in enumerate(screen_cues, 1):
            f.write(f"## Segment {idx}\n\n")
            f.write(f"**Screen:** {cue}\n\n")
            f.write("**Recording notes:**\n")
            f.write("- [ ] Screen recorded\n")
            f.write("- [ ] Audio recorded (optional voiceover)\n")
            f.write("- [ ] File saved as: `module_{:02d}_broll_{:02d}.mp4`\n\n".format(module_num, idx))
            f.write("---\n\n")

    print(f"   📋 B-roll checklist saved: {checklist_file.name}")
    return checklist_file

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Create Cortex Masterclass videos')
    parser.add_argument('--module', type=int, choices=[1, 2], help='Module number (1 or 2)')
    parser.add_argument('--all', action='store_true', help='Create videos for all modules')
    parser.add_argument('--use-existing-audio', action='store_true', help='Use pre-generated audio files')
    parser.add_argument('--broll-checklist', action='store_true', help='Generate B-roll recording checklist only')

    args = parser.parse_args()

    if not args.module and not args.all:
        parser.print_help()
        return

    modules = [1, 2] if args.all else [args.module]

    print(f"\n{'='*70}")
    print(f"Cortex Masterclass - Video Creator")
    print(f"{'='*70}")
    print(f"Chartterbox path: {CHARTTERBOX_PATH}")
    print(f"Output directory: {VIDEO_OUTPUT_DIR}")
    print(f"{'='*70}\n")

    if args.broll_checklist:
        # Only generate B-roll checklists
        print("Generating B-roll recording checklists...\n")
        for module_num in modules:
            print(f"Module {module_num}:")
            generate_broll_checklist(module_num)
            print()
        return

    # Create videos
    generated_videos = []
    for module_num in modules:
        video_path = create_module_video(module_num)
        if video_path:
            generated_videos.append(video_path)

            # Also generate B-roll checklist
            generate_broll_checklist(module_num)

    print(f"\n{'='*70}")
    print(f"SUMMARY")
    print(f"{'='*70}")
    print(f"Created {len(generated_videos)} videos:")
    for v in generated_videos:
        print(f"  ✅ {v.name}")
    print(f"\n{'='*70}")
    print(f"Next steps:")
    print(f"  1. Review videos: {VIDEO_OUTPUT_DIR}")
    print(f"  2. Record B-roll: Follow checklists in {VIDEO_OUTPUT_DIR}")
    print(f"  3. Stitch final video: python stitch_final_video.py --module <N>")
    print(f"{'='*70}\n")

if __name__ == "__main__":
    main()
