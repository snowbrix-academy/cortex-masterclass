# Cortex Masterclass - Video Automation Pipeline

**Automated video generation for Snowflake Cortex course modules using voice cloning + slide generation.**

---

## 🎯 Overview

This pipeline automates video creation for the Cortex Masterclass by:
1. **Generating slides** from video scripts (PowerPoint with Snowbrix branding)
2. **Creating voiceover** using Amit's voice clone (Chatterbox TTS)
3. **Combining slides + audio** into base videos
4. **Stitching B-roll** screen recordings for Snowflake demos
5. **Producing final videos** ready for YouTube/course platform

**Time savings:** 75 minutes vs 5+ hours traditional recording (for Module 1-2)

---

## 📁 Directory Structure

```
video_automation/
├── generate_cortex_slides.py      # Step 1: Script → PowerPoint slides
├── generate_cortex_audio.py       # Step 2: Script → Voiceover audio
├── create_cortex_videos.py        # Step 3: Slides + Audio → Base video
├── stitch_final_video.py          # Step 4: Base video + B-roll → Final video
├── run_full_pipeline.py           # Master script (runs all steps)
├── README.md                      # This file
└── output/
    ├── slides/                    # Generated PowerPoint files
    ├── audio/                     # Generated voiceover files
    │   ├── module_01/
    │   │   ├── slide_01_audio_*_complete.wav
    │   │   ├── slide_02_audio_*_complete.wav
    │   │   └── ...
    │   └── module_02/
    ├── videos/                    # Base videos (slides + audio)
    │   ├── Module_01_Cortex_Analyst_*.mp4
    │   ├── Module_01_BRoll_Checklist.md
    │   └── ...
    ├── broll/                     # B-roll recordings (manual)
    │   ├── module_01/
    │   │   ├── module_01_broll_01.mp4
    │   │   └── ...
    │   └── module_02/
    └── final/                     # Final production videos
        ├── Module_01_FINAL_*.mp4
        └── Module_02_FINAL_*.mp4
```

---

## 🚀 Quick Start

### Prerequisites

1. **Chartterbox pipeline** installed at: `C:\Work\code\Voice_Clone\Chartterbox`
2. **Amit's voice clone** configured (see Chartterbox docs)
3. **Python dependencies:**
   ```bash
   pip install python-pptx moviepy Pillow soundfile pydub
   ```
4. **FFmpeg** installed (for video processing):
   ```bash
   winget install ffmpeg
   ```

### Generate Videos for Module 1

```bash
# Option 1: Run full pipeline (automated)
python run_full_pipeline.py --module 1

# Option 2: Run steps manually
python generate_cortex_slides.py --module 1
python generate_cortex_audio.py --module 1 --audio-only
python create_cortex_videos.py --module 1 --use-existing-audio

# Step 3: Record B-roll (manual)
# - Follow checklist: output/videos/Module_01_BRoll_Checklist.md
# - Save files to: output/broll/module_01/

# Step 4: Stitch final video
python stitch_final_video.py --module 1
```

### Generate All Modules

```bash
python run_full_pipeline.py --all
```

---

## 📊 Pipeline Steps

### **Step 1: Generate Slides**

**Script:** `generate_cortex_slides.py`

**Input:** `video_scripts/module_XX_script.md`

**Output:** `output/slides/Module_XX_Cortex_Analyst_*.pptx`

**What it does:**
- Parses video script markdown file
- Extracts sections, timestamps, narration
- Generates PowerPoint with Snowbrix branding using `snowbrix_layouts_complete.py`
- Creates title, agenda, content, and section divider slides

**Usage:**
```bash
python generate_cortex_slides.py --module 1
python generate_cortex_slides.py --module 2
python generate_cortex_slides.py --all
```

**Time:** ~5 seconds per module

---

### **Step 2: Generate Audio**

**Script:** `generate_cortex_audio.py`

**Input:** `video_scripts/module_XX_script.md`

**Output:** `output/audio/module_XX/slide_XX_audio_*_complete.wav`

**What it does:**
- Extracts narration text from video script (quoted sections)
- Calls `amit_narrate.py` from Chartterbox for each slide
- Generates voiceover using Amit's voice clone
- Saves per-slide audio files

**Usage:**
```bash
python generate_cortex_audio.py --module 1 --audio-only
python generate_cortex_audio.py --module 2 --audio-only
```

**Time:** ~20 minutes per module (can parallelize)

**Parallel generation:**
```bash
# Terminal 1
python generate_cortex_audio.py --module 1 --audio-only

# Terminal 2 (simultaneously)
python generate_cortex_audio.py --module 2 --audio-only

# Total time: 20 minutes instead of 40 minutes!
```

---

### **Step 3: Create Base Videos**

**Script:** `create_cortex_videos.py`

**Input:**
- `output/slides/Module_XX_Cortex_Analyst_*.pptx`
- `output/audio/module_XX/slide_*_audio_*_complete.wav`

**Output:**
- `output/videos/Module_XX_Cortex_Analyst_*.mp4` (base video)
- `output/videos/Module_XX_BRoll_Checklist.md` (recording checklist)

**What it does:**
- Finds latest slide deck and audio files for module
- Copies audio files to Chartterbox project structure
- Calls `video_creator.py` from Chartterbox
- Combines slides + audio into base video
- Generates B-roll recording checklist from [SCREEN:] cues

**Usage:**
```bash
python create_cortex_videos.py --module 1 --use-existing-audio
python create_cortex_videos.py --module 2 --use-existing-audio

# Generate B-roll checklist only (no video)
python create_cortex_videos.py --module 1 --broll-checklist
```

**Time:** ~2 minutes per module

---

### **Step 4: Record B-roll** (Manual)

**Checklist:** `output/videos/Module_XX_BRoll_Checklist.md`

**Output:** `output/broll/module_XX/module_XX_broll_XX.mp4`

**What to do:**
1. Open Snowflake in browser
2. Follow checklist sections (e.g., "Show Snowsight > Worksheets > Run script")
3. Record screen with OBS/QuickTime/Windows Game Bar
4. Save each recording as `module_XX_broll_XX.mp4`
5. Place files in `output/broll/module_XX/`

**Example B-roll checklist:**
```markdown
## Segment 1

**Screen:** https://signup.snowflake.com

**Recording notes:**
- [ ] Screen recorded
- [ ] File saved as: `module_01_broll_01.mp4`

## Segment 2

**Screen:** Snowsight > Worksheets > Create new worksheet
...
```

**Time:** ~30-40 minutes per module (one-time recording)

---

### **Step 5: Stitch Final Video**

**Script:** `stitch_final_video.py`

**Input:**
- `output/videos/Module_XX_Cortex_Analyst_*.mp4` (base video)
- `output/broll/module_XX/module_XX_broll_*.mp4` (B-roll recordings)
- `video_scripts/module_XX_script.md` (for timing info)

**Output:** `output/final/Module_XX_FINAL_*.mp4`

**What it does:**
- Parses video script for [SCREEN:] cue timestamps
- Loads base video and B-roll recordings
- Stitches together: slides → B-roll → slides → B-roll → ...
- Uses moviepy for video composition
- Produces final production-ready video

**Usage:**
```bash
python stitch_final_video.py --module 1
python stitch_final_video.py --module 2
python stitch_final_video.py --all
```

**Time:** ~5-10 minutes per module

---

## ⚡ Performance Comparison

### Traditional OBS Recording (for Module 1-2)
- **Slides creation:** 1 hour (manual PowerPoint)
- **Recording:** 3-4 hours (mistakes, retakes, editing)
- **Editing:** 1 hour (cut mistakes, add transitions)
- **Total:** **5+ hours**

### Automated Pipeline (Module 1-2)
- **Slides generation:** 10 seconds (automated)
- **Audio generation:** 20 minutes (parallel for both modules)
- **Video creation:** 4 minutes (2 min each)
- **B-roll recording:** 40 minutes (one-time, reusable)
- **Stitching:** 10 minutes (5 min each)
- **Total:** **~75 minutes**

**Speedup:** 4x faster!

---

## 🎨 Customization

### Change Voice

Edit `generate_cortex_audio.py`:
```python
# Line 82: Change to Saanvi's voice
amit_script = Path(CHARTTERBOX_PATH) / "clone_saanvi_voice.py"
```

### Modify Slide Layouts

Edit `generate_cortex_slides.py` to use different Snowbrix layouts:
```python
# Add emphasis slides
composer.add_emphasis_slide("Key Takeaway", "Important message here")

# Add two-column layout
composer.add_two_column_slide("Title", left_bullets, right_bullets)

# Add three-column layout
composer.add_three_column_slide("Title", col1_title, col1_bullets, ...)
```

See `snowbrix_layouts_complete.py` for all available layouts.

### Change Video Resolution

Edit `stitch_final_video.py`:
```python
# Line ~170: Change resolution
final_clip.write_videofile(
    str(output_file),
    codec='libx264',
    audio_codec='aac',
    fps=30,
    preset='medium',
    threads=4,
    # Add this:
    # ffmpeg_params=["-s", "1920x1080"]  # Force 1080p
)
```

---

## 🛠️ Troubleshooting

### "No slide deck found"
**Problem:** Step 3 can't find slides

**Solution:**
```bash
python generate_cortex_slides.py --module 1
```

### "No audio files found"
**Problem:** Step 3 can't find audio

**Solution:**
```bash
python generate_cortex_audio.py --module 1 --audio-only
```

### "Missing audio file" during video creation
**Problem:** Amit narration failed for some slides

**Solution:**
1. Check Chartterbox Amit_Clone/ directory for error logs
2. Re-run audio generation:
   ```bash
   python generate_cortex_audio.py --module 1 --audio-only
   ```

### "Missing B-roll files" during stitching
**Problem:** B-roll recordings not found

**Solution:**
1. Follow checklist: `output/videos/Module_XX_BRoll_Checklist.md`
2. Record missing segments
3. Save to: `output/broll/module_XX/`
4. Re-run stitching:
   ```bash
   python stitch_final_video.py --module 1
   ```

### Video/audio sync issues
**Problem:** Audio doesn't match slides

**Solution:**
- This should NOT happen with per-slide audio
- If it does, check that audio files were generated correctly
- Verify slide count matches audio file count:
  ```bash
  # Count slides in PowerPoint (approximate)
  python -c "from pptx import Presentation; print(len(Presentation('output/slides/Module_01*.pptx').slides))"

  # Count audio files
  ls output/audio/module_01/*.wav | wc -l
  ```

---

## 📝 Video Script Format

Video scripts use this format:

```markdown
# Module XX — Title | Video Script

**Duration:** ~15 minutes
**Type:** Concept + Hands-On

---

## [0:00 - 0:30] THE HOOK

**[SCREEN: https://snowflake.com]**

**SCRIPT:**
"Quoted narration text here. This will be extracted for voiceover."

---

## [0:30 - 2:00] Section Title

**[SLIDE: Slide Title Here]**

> Bullet point 1
> Bullet point 2
> Bullet point 3

**SCRIPT:**
"More narration here. All quoted text becomes voiceover."
```

**Key markers:**
- `## [MM:SS-MM:SS] Section Title` — Section with timestamp
- `**[SCREEN: URL/description]**` — Triggers B-roll recording
- `**[SLIDE: Title]**` — Triggers slide creation
- `**SCRIPT:**` followed by quotes — Narration text
- `> Bullet text` or `- Bullet text` — Slide bullet points

---

## 🎯 Production Workflow

### Week 1: Generate Module 1-2 Videos

```bash
# Day 1: Generate slides + audio (parallel)
python generate_cortex_slides.py --all
python generate_cortex_audio.py --module 1 --audio-only &
python generate_cortex_audio.py --module 2 --audio-only &
wait

# Day 2: Create base videos
python create_cortex_videos.py --all --use-existing-audio

# Day 3: Record B-roll for both modules
# Follow checklists in output/videos/

# Day 4: Stitch final videos
python stitch_final_video.py --all

# Day 5: Review, upload to YouTube
```

### Weeks 2-5: Generate Module 3-10 Videos

Repeat the same process for modules 3-10 once scripts are written.

---

## 📚 Additional Resources

**Chartterbox Documentation:**
- Voice Cloning: `C:\Work\code\Voice_Clone\Chartterbox\_docs\VOICE_CLONING_GUIDE.md`
- Video Automation: `C:\Work\code\Voice_Clone\Chartterbox\_video_automation\README_VIDEO.md`
- Workflow Guide: `C:\Work\code\Voice_Clone\Chartterbox\_video_automation\WORKFLOW_GUIDE.md`

**Snowbrix Layouts:**
- Complete Guide: `C:\Work\code\Voice_Clone\Chartterbox\_video_automation\snowbrix_layouts_complete.py`
- Brand Colors: `C:\Work\code\Voice_Clone\Chartterbox\_video_automation\brand_colors_snowbrix.py`

**Course Documentation:**
- Video Scripts: `video_scripts/`
- Lab Instructions: `labs/`
- Quiz Questions: `quizzes/`

---

## ✅ Current Status

- ✅ Pipeline scripts created (4 main scripts + master)
- ✅ Module 1 script ready (`video_scripts/module_01_script.md`)
- ✅ Module 2 script ready (`video_scripts/module_02_script.md`)
- ⏳ Module 3-10 scripts (to be created)
- ⏳ Video generation (ready to start)

---

**Last Updated:** February 14, 2026
**Version:** 1.0
**Author:** Snowbrix Academy

**Production-Grade Data Engineering. No Fluff.**
