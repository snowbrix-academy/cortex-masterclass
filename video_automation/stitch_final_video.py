"""
Stitch together slides video + B-roll footage for Cortex Masterclass modules.
Creates the final production video with screen demos integrated.

Usage:
    python stitch_final_video.py --module 1
    python stitch_final_video.py --module 2
    python stitch_final_video.py --all
"""
import sys
import re
from datetime import datetime
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "video_scripts"
VIDEO_DIR = PROJECT_ROOT / "video_automation" / "output" / "videos"
BROLL_DIR = PROJECT_ROOT / "video_automation" / "output" / "broll"
FINAL_OUTPUT_DIR = PROJECT_ROOT / "video_automation" / "output" / "final"

def parse_screen_cues_with_timing(script_path):
    """
    Parse video script and extract [SCREEN:] cues with their timestamps.

    Returns:
        List of dicts: [
            {
                'timestamp': '01:30-03:00',
                'start_sec': 90,
                'end_sec': 180,
                'screen_cue': 'Description',
                'broll_file': 'module_01_broll_01.mp4'
            },
            ...
        ]
    """
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    screen_segments = []
    broll_num = 0

    # Split by section headers (## [timestamp] Section Name)
    sections = re.split(r'\n## \[([^\]]+)\] ([^\n]+)', content)

    for i in range(1, len(sections), 3):
        if i + 2 >= len(sections):
            break

        timestamp = sections[i].strip()
        section_name = sections[i + 1].strip()
        section_content = sections[i + 2].strip()

        # Check for [SCREEN:] cue
        screen_match = re.search(r'\*\*\[SCREEN:\s*([^\]]+)\]\*\*', section_content)

        if screen_match:
            broll_num += 1

            # Parse timestamp (format: "MM:SS-MM:SS")
            time_match = re.match(r'(\d+):(\d+)-(\d+):(\d+)', timestamp)
            if time_match:
                start_min, start_sec, end_min, end_sec = map(int, time_match.groups())
                start_total = start_min * 60 + start_sec
                end_total = end_min * 60 + end_sec
            else:
                # Default to 30 seconds if timestamp parsing fails
                start_total = 0
                end_total = 30

            screen_segments.append({
                'timestamp': timestamp,
                'start_sec': start_total,
                'end_sec': end_total,
                'section': section_name,
                'screen_cue': screen_match.group(1),
                'broll_file': f"module_{{module:02d}}_broll_{broll_num:02d}.mp4"
            })

    return screen_segments

def check_broll_files(module_num, screen_segments):
    """Check if all B-roll files exist."""
    module_broll_dir = BROLL_DIR / f"module_{module_num:02d}"

    if not module_broll_dir.exists():
        return False, []

    missing = []
    for segment in screen_segments:
        broll_filename = segment['broll_file'].format(module=module_num)
        broll_path = module_broll_dir / broll_filename

        if not broll_path.exists():
            missing.append(broll_filename)

    return len(missing) == 0, missing

def stitch_video(module_num, base_video, screen_segments):
    """
    Stitch base video with B-roll footage using moviepy.

    Args:
        module_num: Module number
        base_video: Path to slides video
        screen_segments: List of screen segment dicts with timing info
    """
    try:
        from moviepy.editor import VideoFileClip, concatenate_videoclips, CompositeVideoClip
        import moviepy.video.fx.all as vfx
    except ImportError:
        print("❌ moviepy not installed. Install with: pip install moviepy")
        return None

    print(f"  🎬 Loading base video: {base_video.name}")
    base_clip = VideoFileClip(str(base_video))
    total_duration = base_clip.duration

    print(f"  📊 Base video duration: {total_duration:.1f}s")
    print(f"  📋 B-roll segments to insert: {len(screen_segments)}")

    # Build segment list
    clips = []
    current_time = 0
    module_broll_dir = BROLL_DIR / f"module_{module_num:02d}"

    for idx, segment in enumerate(screen_segments, 1):
        # Add slides segment before this B-roll
        if current_time < segment['start_sec']:
            slides_segment = base_clip.subclip(current_time, segment['start_sec'])
            clips.append(slides_segment)
            print(f"    ✅ Segment {idx-1}: Slides {current_time:.1f}s - {segment['start_sec']:.1f}s")

        # Add B-roll segment
        broll_filename = segment['broll_file'].format(module=module_num)
        broll_path = module_broll_dir / broll_filename

        if broll_path.exists():
            broll_clip = VideoFileClip(str(broll_path))

            # Resize B-roll to match base video resolution if needed
            if broll_clip.size != base_clip.size:
                broll_clip = broll_clip.resize(base_clip.size)

            clips.append(broll_clip)
            print(f"    🎥 Segment {idx}: B-roll {broll_filename} ({broll_clip.duration:.1f}s)")

            current_time = segment['end_sec']
        else:
            print(f"    ⚠️  B-roll file missing: {broll_filename}, using slides instead")
            slides_segment = base_clip.subclip(current_time, segment['end_sec'])
            clips.append(slides_segment)
            current_time = segment['end_sec']

    # Add remaining slides after last B-roll
    if current_time < total_duration:
        final_segment = base_clip.subclip(current_time, total_duration)
        clips.append(final_segment)
        print(f"    ✅ Final segment: Slides {current_time:.1f}s - {total_duration:.1f}s")

    # Concatenate all clips
    print(f"\n  🔗 Stitching {len(clips)} segments...")
    final_clip = concatenate_videoclips(clips, method="compose")

    # Output file
    FINAL_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = FINAL_OUTPUT_DIR / f"Module_{module_num:02d}_FINAL_{timestamp}.mp4"

    # Write video
    print(f"  💾 Writing final video: {output_file.name}")
    final_clip.write_videofile(
        str(output_file),
        codec='libx264',
        audio_codec='aac',
        fps=30,
        preset='medium',
        threads=4
    )

    # Clean up
    base_clip.close()
    final_clip.close()
    for clip in clips:
        clip.close()

    print(f"  ✅ Final video created: {output_file}")

    return output_file

def stitch_module_video(module_num):
    """Stitch final video for a specific module."""

    print(f"\n{'='*70}")
    print(f"Stitching Final Video: Module {module_num}")
    print(f"{'='*70}\n")

    # Find base video (slides + audio)
    base_video_pattern = f"Module_{module_num:02d}_Cortex_Analyst_*.mp4"
    base_videos = sorted(VIDEO_DIR.glob(base_video_pattern), key=lambda p: p.stat().st_mtime, reverse=True)

    if not base_videos:
        print(f"❌ No base video found for Module {module_num}")
        print(f"   Run: python create_cortex_videos.py --module {module_num} --use-existing-audio")
        return None

    base_video = base_videos[0]
    print(f"✅ Found base video: {base_video.name}")

    # Parse script for screen cues
    script_files = {
        1: SCRIPTS_DIR / "module_01_script.md",
        2: SCRIPTS_DIR / "module_02_script.md"
    }

    script_path = script_files.get(module_num)
    if not script_path or not script_path.exists():
        print(f"❌ Script file not found: {script_path}")
        return None

    screen_segments = parse_screen_cues_with_timing(script_path)

    if not screen_segments:
        print(f"ℹ️  No B-roll segments needed for Module {module_num}")
        print(f"   Base video is already final: {base_video}")
        return base_video

    print(f"✅ Found {len(screen_segments)} B-roll segments in script\n")

    # Check if B-roll files exist
    all_exist, missing = check_broll_files(module_num, screen_segments)

    if not all_exist:
        print(f"⚠️  WARNING: Missing B-roll files:")
        for filename in missing:
            print(f"   - {filename}")
        print(f"\nℹ️  B-roll files should be in: {BROLL_DIR / f'module_{module_num:02d}'}")
        print(f"   Use checklist: {VIDEO_DIR / f'Module_{module_num:02d}_BRoll_Checklist.md'}")
        print(f"\n❓ Continue anyway? (missing segments will use slides) [y/N]: ", end='')

        response = input().strip().lower()
        if response != 'y':
            print("❌ Aborted. Record B-roll files and try again.")
            return None
        print()

    # Stitch video
    final_video = stitch_video(module_num, base_video, screen_segments)

    if final_video:
        print(f"\n{'='*70}")
        print(f"✅ FINAL VIDEO COMPLETE")
        print(f"{'='*70}")
        print(f"Module: {module_num}")
        print(f"Output: {final_video}")
        print(f"{'='*70}\n")

    return final_video

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Stitch final Cortex Masterclass videos with B-roll')
    parser.add_argument('--module', type=int, choices=[1, 2], help='Module number (1 or 2)')
    parser.add_argument('--all', action='store_true', help='Stitch all modules')

    args = parser.parse_args()

    if not args.module and not args.all:
        parser.print_help()
        return

    modules = [1, 2] if args.all else [args.module]

    print(f"\n{'='*70}")
    print(f"Cortex Masterclass - Final Video Stitcher")
    print(f"{'='*70}")
    print(f"B-roll directory: {BROLL_DIR}")
    print(f"Output directory: {FINAL_OUTPUT_DIR}")
    print(f"{'='*70}\n")

    final_videos = []
    for module_num in modules:
        final_video = stitch_module_video(module_num)
        if final_video:
            final_videos.append(final_video)

    print(f"\n{'='*70}")
    print(f"SUMMARY")
    print(f"{'='*70}")
    print(f"Created {len(final_videos)} final videos:")
    for v in final_videos:
        print(f"  ✅ {v.name}")
    print(f"\n{'='*70}")
    print(f"Next steps:")
    print(f"  1. Review final videos: {FINAL_OUTPUT_DIR}")
    print(f"  2. Upload to YouTube")
    print(f"  3. Add to course platform")
    print(f"{'='*70}\n")

if __name__ == "__main__":
    main()
