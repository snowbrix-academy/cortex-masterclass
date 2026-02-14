"""
Master automation script for Cortex Masterclass video generation.
Runs the complete pipeline: slides → audio → video → (manual B-roll) → final video.

Usage:
    python run_full_pipeline.py --module 1
    python run_full_pipeline.py --module 2
    python run_full_pipeline.py --all
    python run_full_pipeline.py --module 1 --skip-audio  # Use existing audio
    python run_full_pipeline.py --module 1 --broll-only  # Only B-roll reminder
"""
import sys
import subprocess
from pathlib import Path
from datetime import datetime

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
AUTOMATION_DIR = Path(__file__).parent

def run_step(script_name, args, step_num, step_name):
    """Run a pipeline step."""
    print(f"\n{'='*70}")
    print(f"STEP {step_num}: {step_name}")
    print(f"{'='*70}\n")

    script_path = AUTOMATION_DIR / script_name
    cmd = [sys.executable, str(script_path)] + args

    try:
        result = subprocess.run(
            cmd,
            cwd=str(PROJECT_ROOT),
            check=True,
            text=True
        )
        print(f"\n✅ Step {step_num} complete: {step_name}\n")
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Step {step_num} failed: {step_name}")
        print(f"Error code: {e.returncode}\n")
        return False
    except Exception as e:
        print(f"\n❌ Step {step_num} error: {e}\n")
        return False

def show_broll_reminder(module_num):
    """Show B-roll recording reminder."""
    checklist_file = AUTOMATION_DIR / "output" / "videos" / f"Module_{module_num:02d}_BRoll_Checklist.md"

    print(f"\n{'='*70}")
    print(f"📋 B-ROLL RECORDING NEEDED")
    print(f"{'='*70}\n")

    if checklist_file.exists():
        print(f"✅ B-roll checklist: {checklist_file}")
        print(f"\n📝 Recording instructions:")
        print(f"   1. Open Snowflake in browser")
        print(f"   2. Follow checklist in: {checklist_file.name}")
        print(f"   3. Record screen for each segment")
        print(f"   4. Save files to: output/broll/module_{module_num:02d}/")
        print(f"      - Format: module_{module_num:02d}_broll_01.mp4, module_{module_num:02d}_broll_02.mp4, etc.")
        print(f"\n⚠️  Estimated time: 30-40 minutes")
    else:
        print(f"ℹ️  No B-roll needed for Module {module_num}")

    print(f"\n{'='*70}")
    print(f"After recording B-roll, run:")
    print(f"  python stitch_final_video.py --module {module_num}")
    print(f"{'='*70}\n")

def run_full_pipeline(module_num, skip_audio=False):
    """Run complete pipeline for a module."""

    start_time = datetime.now()

    print(f"\n{'='*70}")
    print(f"Cortex Masterclass - Full Video Pipeline")
    print(f"{'='*70}")
    print(f"Module: {module_num}")
    print(f"Skip audio: {skip_audio}")
    print(f"Started: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*70}\n")

    # Step 1: Generate Slides
    success = run_step(
        "generate_cortex_slides.py",
        ["--module", str(module_num)],
        1,
        "Generate Slides"
    )
    if not success:
        print("❌ Pipeline failed at Step 1")
        return False

    # Step 2: Generate Audio (optional)
    if not skip_audio:
        success = run_step(
            "generate_cortex_audio.py",
            ["--module", str(module_num), "--audio-only"],
            2,
            "Generate Audio (Amit's Voice)"
        )
        if not success:
            print("❌ Pipeline failed at Step 2")
            return False
    else:
        print(f"\n{'='*70}")
        print(f"STEP 2: Generate Audio (SKIPPED)")
        print(f"{'='*70}\n")
        print("ℹ️  Using existing audio files\n")

    # Step 3: Create Base Video
    success = run_step(
        "create_cortex_videos.py",
        ["--module", str(module_num), "--use-existing-audio"],
        3,
        "Create Base Video (Slides + Audio)"
    )
    if not success:
        print("❌ Pipeline failed at Step 3")
        return False

    # Step 4: B-roll Recording Reminder
    print(f"\n{'='*70}")
    print(f"STEP 4: Record B-roll (MANUAL)")
    print(f"{'='*70}\n")

    show_broll_reminder(module_num)

    # Pipeline complete (except manual B-roll + final stitching)
    elapsed = (datetime.now() - start_time).total_seconds()

    print(f"\n{'='*70}")
    print(f"✅ AUTOMATED PIPELINE COMPLETE")
    print(f"{'='*70}")
    print(f"Module: {module_num}")
    print(f"Time: {elapsed/60:.1f} minutes")
    print(f"\n🎬 Base video ready!")
    print(f"   Location: output/videos/Module_{module_num:02d}_Cortex_Analyst_*.mp4")
    print(f"\n📋 Next steps:")
    print(f"   1. Record B-roll (see checklist above)")
    print(f"   2. Run: python stitch_final_video.py --module {module_num}")
    print(f"{'='*70}\n")

    return True

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Run full Cortex Masterclass video generation pipeline',
        epilog='''
Examples:
  python run_full_pipeline.py --module 1              # Generate Module 1 (full pipeline)
  python run_full_pipeline.py --all                   # Generate all modules
  python run_full_pipeline.py --module 1 --skip-audio # Use existing audio
  python run_full_pipeline.py --module 1 --broll-only # Show B-roll reminder only
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('--module', type=int, choices=[1, 2], help='Module number (1 or 2)')
    parser.add_argument('--all', action='store_true', help='Process all modules')
    parser.add_argument('--skip-audio', action='store_true', help='Skip audio generation (use existing)')
    parser.add_argument('--broll-only', action='store_true', help='Only show B-roll recording reminder')

    args = parser.parse_args()

    if not args.module and not args.all:
        parser.print_help()
        return

    modules = [1, 2] if args.all else [args.module]

    # B-roll reminder only
    if args.broll_only:
        for module_num in modules:
            show_broll_reminder(module_num)
        return

    # Run full pipeline for each module
    results = []
    overall_start = datetime.now()

    for module_num in modules:
        success = run_full_pipeline(module_num, skip_audio=args.skip_audio)
        results.append((module_num, success))

    overall_elapsed = (datetime.now() - overall_start).total_seconds()

    # Summary
    print(f"\n{'='*70}")
    print(f"FINAL SUMMARY")
    print(f"{'='*70}")
    print(f"Total time: {overall_elapsed/60:.1f} minutes")
    print(f"\nResults:")
    for module_num, success in results:
        status = "✅ SUCCESS" if success else "❌ FAILED"
        print(f"  Module {module_num}: {status}")

    successful = sum(1 for _, s in results if s)
    print(f"\n{successful}/{len(results)} modules completed successfully")

    if successful == len(results):
        print(f"\n🎉 All modules ready for B-roll recording!")
        print(f"\n📋 Next steps:")
        print(f"   1. Record B-roll for each module (see checklists)")
        print(f"   2. Stitch final videos:")
        for module_num, _ in results:
            print(f"      python stitch_final_video.py --module {module_num}")
    else:
        print(f"\n⚠️  Some modules failed. Check logs above.")

    print(f"{'='*70}\n")

if __name__ == "__main__":
    main()
