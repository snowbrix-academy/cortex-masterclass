"""
Generate PowerPoint slides for Cortex Masterclass modules from video scripts.
Integrates with the Chartterbox pipeline for automated video generation.

Usage:
    python generate_cortex_slides.py --module 1
    python generate_cortex_slides.py --module 2
    python generate_cortex_slides.py --all
"""
import sys
import os
import re
from datetime import datetime
from pathlib import Path

# Add Chartterbox video automation to path
CHARTTERBOX_PATH = r"C:\Work\code\Voice_Clone\Chartterbox\_video_automation"
sys.path.insert(0, CHARTTERBOX_PATH)

from snowbrix_layouts_complete import SnowbrixLayoutsComplete

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "video_scripts"
OUTPUT_DIR = PROJECT_ROOT / "video_automation" / "output" / "slides"

def parse_video_script(script_path):
    """
    Parse video script and extract slides and narration.

    Returns:
        List of dicts: [
            {
                'timestamp': '00:00-00:30',
                'section': 'Section Title',
                'slide_type': 'title' | 'content' | 'screen',
                'title': 'Slide Title',
                'content': ['Bullet 1', 'Bullet 2', ...],
                'narration': 'Full narration text...',
                'screen_cue': 'URL or description' (if slide_type == 'screen')
            },
            ...
        ]
    """
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    slides = []

    # Split by section headers (## [timestamp] Section Name)
    sections = re.split(r'\n## \[([^\]]+)\] ([^\n]+)', content)

    # sections[0] is metadata before first section
    # sections[1] = timestamp, sections[2] = section name, sections[3] = content
    # sections[4] = timestamp, sections[5] = section name, sections[6] = content, etc.

    for i in range(1, len(sections), 3):
        if i + 2 >= len(sections):
            break

        timestamp = sections[i].strip()
        section_name = sections[i + 1].strip()
        section_content = sections[i + 2].strip()

        # Extract [SCREEN:] or [SLIDE:] cues
        screen_match = re.search(r'\*\*\[SCREEN:\s*([^\]]+)\]\*\*', section_content)
        slide_match = re.search(r'\*\*\[SLIDE:\s*([^\]]+)\]\*\*', section_content)

        # Extract narration (quoted text after SCRIPT: or direct quotes)
        narration_matches = re.findall(r'(?:\*\*SCRIPT:\*\*\s*)?["\u201c]([^"\u201d]+)["\u201d]', section_content)
        narration = ' '.join(narration_matches) if narration_matches else ''

        # Determine slide type and extract content
        if screen_match:
            # Screen recording cue - create note slide
            slides.append({
                'timestamp': timestamp,
                'section': section_name,
                'slide_type': 'screen',
                'title': section_name,
                'content': ['[SCREEN RECORDING]', screen_match.group(1)],
                'narration': narration,
                'screen_cue': screen_match.group(1)
            })
        elif slide_match:
            # Slide cue - extract bullet points
            slide_title = slide_match.group(1)

            # Extract bullet points (lines starting with >, -, or *)
            bullets = re.findall(r'^[>\-\*]\s*(.+)$', section_content, re.MULTILINE)

            slides.append({
                'timestamp': timestamp,
                'section': section_name,
                'slide_type': 'content',
                'title': slide_title,
                'content': bullets if bullets else [section_name],
                'narration': narration,
                'screen_cue': None
            })
        else:
            # No specific cue - infer from content
            # If it's a title-like section (short, no bullets), make it a section divider
            if len(section_name) < 60 and not re.search(r'^[>\-\*]', section_content, re.MULTILINE):
                slides.append({
                    'timestamp': timestamp,
                    'section': section_name,
                    'slide_type': 'section',
                    'title': section_name,
                    'content': [],
                    'narration': narration,
                    'screen_cue': None
                })
            else:
                # Extract bullet points
                bullets = re.findall(r'^[>\-\*]\s*(.+)$', section_content, re.MULTILINE)

                slides.append({
                    'timestamp': timestamp,
                    'section': section_name,
                    'slide_type': 'content',
                    'title': section_name,
                    'content': bullets if bullets else ['See video for details'],
                    'narration': narration,
                    'screen_cue': None
                })

    return slides

def generate_module_slides(module_num):
    """Generate slides for a specific module."""

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
    print(f"Generating Slides: Module {module_num}")
    print(f"{'='*70}\n")
    print(f"📄 Reading script: {script_path.name}")

    # Parse script
    slides = parse_video_script(script_path)
    print(f"✅ Parsed {len(slides)} slides from script\n")

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Output file
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = OUTPUT_DIR / f"Module_{module_num:02d}_Cortex_Analyst_{timestamp}.pptx"

    # Create presentation
    composer = SnowbrixLayoutsComplete(str(output_file), include_logo=True, include_page_numbers=False)

    # Module-specific title slides
    module_titles = {
        1: ("Module 01: Set Up Your Snowflake AI Workspace", "Environment Setup & Data Loading"),
        2: ("Module 02: Deploy Your First Cortex Analyst App", "Build & Deploy Streamlit App with Semantic YAML")
    }

    title, subtitle = module_titles.get(module_num, (f"Module {module_num}", "Cortex Masterclass"))

    # Add title slide
    composer.add_title_slide(title, subtitle)
    print(f"✅ Added title slide: {title}")

    # Add agenda slide if we have multiple sections
    section_names = list(set([s['section'] for s in slides if s['slide_type'] != 'screen']))
    if len(section_names) > 3:
        # Create agenda from first few sections
        agenda_items = []
        seen_sections = set()
        for slide in slides[:10]:  # First 10 slides
            if slide['section'] not in seen_sections and slide['slide_type'] != 'screen':
                agenda_items.append({
                    'number': f"{len(agenda_items)+1:02d}",
                    'title': slide['section'],
                    'duration': slide['timestamp'].split('-')[1] if '-' in slide['timestamp'] else '5 min'
                })
                seen_sections.add(slide['section'])
                if len(agenda_items) >= 5:
                    break

        if agenda_items:
            composer.add_agenda_slide("Today's Agenda", agenda_items)
            print(f"✅ Added agenda slide with {len(agenda_items)} sections")

    # Add slides
    current_section = None
    for idx, slide in enumerate(slides, 1):

        # Add section divider if section changed
        if slide['section'] != current_section and slide['slide_type'] == 'content':
            composer.add_section_divider(slide['section'])
            print(f"  📌 Section: {slide['section']}")
            current_section = slide['section']

        # Add slide based on type
        if slide['slide_type'] == 'section':
            composer.add_section_divider(slide['title'])
            print(f"  ➡️  Section divider: {slide['title']}")

        elif slide['slide_type'] == 'screen':
            # Screen recording cue - add as content slide with note
            composer.add_content_slide(
                f"🎥 {slide['title']}",
                [f"Screen Demo: {slide['screen_cue']}"]
            )
            print(f"  🎬 Screen slide: {slide['title']}")

        elif slide['slide_type'] == 'content':
            # Regular content slide
            if len(slide['content']) <= 4:
                composer.add_content_slide(slide['title'], slide['content'])
            elif len(slide['content']) <= 8:
                # Split into two columns
                mid = len(slide['content']) // 2
                composer.add_two_column_slide(
                    slide['title'],
                    slide['content'][:mid],
                    slide['content'][mid:],
                    left_title="",
                    right_title=""
                )
            else:
                # Too many bullets - create multiple slides
                composer.add_content_slide(slide['title'], slide['content'][:4])

            print(f"  ✅ Content slide: {slide['title']}")

    # Add closing slide
    composer.add_thank_you_slide(
        f"Module {module_num} Complete!",
        "contact@snowbrixacademy.com | snowbrixacademy.com/cortex"
    )
    print(f"✅ Added closing slide")

    # Save presentation
    composer.save()
    print(f"\n{'='*70}")
    print(f"✅ SLIDES CREATED: {output_file.name}")
    print(f"{'='*70}\n")

    return output_file

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Generate Cortex Masterclass slides from video scripts')
    parser.add_argument('--module', type=int, choices=[1, 2], help='Module number (1 or 2)')
    parser.add_argument('--all', action='store_true', help='Generate all modules')

    args = parser.parse_args()

    if not args.module and not args.all:
        parser.print_help()
        return

    modules = [1, 2] if args.all else [args.module]

    print(f"\n{'='*70}")
    print(f"Cortex Masterclass - Slide Generator")
    print(f"{'='*70}")
    print(f"Using Snowbrix layouts from: {CHARTTERBOX_PATH}")
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"{'='*70}\n")

    generated_files = []
    for module_num in modules:
        output_file = generate_module_slides(module_num)
        if output_file:
            generated_files.append(output_file)

    print(f"\n{'='*70}")
    print(f"SUMMARY")
    print(f"{'='*70}")
    print(f"Generated {len(generated_files)} presentations:")
    for f in generated_files:
        print(f"  ✅ {f.name}")
    print(f"\n{'='*70}")
    print(f"Next steps:")
    print(f"  1. Review slides: {OUTPUT_DIR}")
    print(f"  2. Generate audio: python generate_cortex_audio.py --module <N>")
    print(f"  3. Create videos: python create_cortex_videos.py --module <N>")
    print(f"{'='*70}\n")

if __name__ == "__main__":
    main()
