# Quick Start Guide - Cortex Masterclass Video Automation

Get your first video generated in 30 minutes!

---

## ✅ Prerequisites Check

Before starting, verify:

```bash
# 1. Python installed (3.8+)
python --version

# 2. Chartterbox pipeline exists
ls "C:\Work\code\Voice_Clone\Chartterbox"

# 3. FFmpeg installed
ffmpeg -version

# 4. Dependencies installed
pip install python-pptx moviepy Pillow soundfile pydub
```

If any checks fail, see [README.md](README.md) for setup instructions.

---

## 🚀 Generate Your First Video (Module 1)

### Option 1: Full Automated Pipeline (Recommended)

```bash
cd C:\Work\code\youtube\snowbrix_academy\video_automation

# Run full pipeline
python run_full_pipeline.py --module 1
```

**What happens:**
1. ✅ Generates PowerPoint slides (~5 seconds)
2. ✅ Creates voiceover audio (~20 minutes)
3. ✅ Combines into base video (~2 minutes)
4. 📋 Shows B-roll recording checklist

**Time:** ~23 minutes + manual B-roll recording

---

### Option 2: Step-by-Step (Learn the Process)

```bash
# Step 1: Generate slides
python generate_cortex_slides.py --module 1

# Step 2: Generate audio (20 min - go get coffee!)
python generate_cortex_audio.py --module 1 --audio-only

# Step 3: Create base video
python create_cortex_videos.py --module 1 --use-existing-audio

# Step 4: Record B-roll (manual)
# - Open: output/videos/Module_01_BRoll_Checklist.md
# - Follow instructions
# - Save recordings to: output/broll/module_01/

# Step 5: Stitch final video
python stitch_final_video.py --module 1
```

---

## 📋 B-roll Recording Guide

After automated steps complete, you'll see:

```
📋 B-roll checklist: output/videos/Module_01_BRoll_Checklist.md

Recording instructions:
   1. Open Snowflake in browser
   2. Follow checklist sections
   3. Record screen for each segment
   4. Save files to: output/broll/module_01/
```

### How to Record B-roll

**Windows (Game Bar):**
1. Press `Win + G` to open Game Bar
2. Click record button (or `Win + Alt + R`)
3. Follow checklist action (e.g., "Open Snowsight > Worksheets")
4. Press `Win + Alt + R` to stop recording
5. Rename file to: `module_01_broll_01.mp4`
6. Move to: `output/broll/module_01/`

**Mac (QuickTime):**
1. Open QuickTime Player
2. File > New Screen Recording
3. Click record button
4. Follow checklist action
5. Click stop button in menu bar
6. Save as: `module_01_broll_01.mp4` in `output/broll/module_01/`

**OBS Studio (All platforms):**
1. Add "Display Capture" source
2. Click "Start Recording"
3. Follow checklist action
4. Click "Stop Recording"
5. Rename and move file to: `output/broll/module_01/`

---

## ⚡ Speed Tips

### Parallel Audio Generation (Both Modules)

```bash
# Terminal 1
python generate_cortex_audio.py --module 1 --audio-only

# Terminal 2 (open simultaneously)
python generate_cortex_audio.py --module 2 --audio-only

# Both finish in ~20 minutes instead of 40 minutes!
```

### Skip Audio Regeneration

If you already have audio files and only changed slides:

```bash
python run_full_pipeline.py --module 1 --skip-audio
```

### Generate All Modules at Once

```bash
python run_full_pipeline.py --all
```

---

## 🎯 Expected Output

After running the pipeline for Module 1, you'll have:

```
video_automation/output/
├── slides/
│   └── Module_01_Cortex_Analyst_20260214_123456.pptx  # ✅ Generated
├── audio/
│   └── module_01/
│       ├── slide_01_audio_20260214_123500_complete.wav  # ✅ Generated
│       ├── slide_02_audio_20260214_123520_complete.wav
│       └── ...
├── videos/
│   ├── Module_01_Cortex_Analyst_20260214_124500.mp4  # ✅ Generated (base)
│   └── Module_01_BRoll_Checklist.md                   # ✅ Generated
├── broll/
│   └── module_01/
│       ├── module_01_broll_01.mp4  # ⏳ You record these manually
│       ├── module_01_broll_02.mp4
│       └── ...
└── final/
    └── Module_01_FINAL_20260214_130000.mp4  # ✅ After stitching
```

---

## 🛠️ Troubleshooting

### "No module named 'snowbrix_layouts_complete'"

**Problem:** Can't find Chartterbox modules

**Solution:**
```bash
# Verify Chartterbox path
ls "C:\Work\code\Voice_Clone\Chartterbox\_video_automation\snowbrix_layouts_complete.py"

# If missing, update path in scripts
```

### Audio generation hangs

**Problem:** Amit narration script not responding

**Solution:**
1. Check if Chatterbox TTS is properly configured
2. See: `C:\Work\code\Voice_Clone\Chartterbox\_docs\VOICE_CLONING_GUIDE.md`
3. Test manually:
   ```bash
   cd "C:\Work\code\Voice_Clone\Chartterbox"
   echo "Test narration" > test.txt
   python amit_narrate.py test.txt
   ```

### Video creation fails

**Problem:** Chartterbox video_creator.py errors

**Solution:**
1. Verify FFmpeg installed: `ffmpeg -version`
2. Check audio files exist:
   ```bash
   ls output/audio/module_01/*.wav
   ```
3. Try creating video manually with Chartterbox:
   ```bash
   cd "C:\Work\code\Voice_Clone\Chartterbox"
   python _video_automation/video_creator.py [slides.pptx] --use-existing-audio
   ```

### "Missing B-roll files" warning

**Problem:** Stitching can't find B-roll recordings

**Solution:**
- This is expected if you haven't recorded B-roll yet
- Follow checklist: `output/videos/Module_01_BRoll_Checklist.md`
- Save recordings to: `output/broll/module_01/`
- File names must match: `module_01_broll_01.mp4`, `module_01_broll_02.mp4`, etc.

---

## 📊 Time Breakdown

For Module 1 (12 min video):

| Step | Time | Can Parallelize |
|------|------|----------------|
| Generate slides | 5 sec | ✅ Yes |
| Generate audio | 20 min | ✅ Yes (across modules) |
| Create video | 2 min | ✅ Yes (after audio) |
| Record B-roll | 30 min | 🚫 Manual |
| Stitch final | 5 min | ✅ Yes (after B-roll) |
| **Total** | **~58 min** | |

**For both Module 1 & 2:**
- Sequential: ~116 minutes (1h 56m)
- **Parallel**: ~78 minutes (1h 18m) — 33% faster!

---

## ✅ Success Checklist

After completing Quick Start, you should have:

- [x] Chartterbox pipeline accessible
- [x] Python dependencies installed
- [x] Module 1 slides generated (PPTX)
- [x] Module 1 audio generated (~15-20 WAV files)
- [x] Module 1 base video created (MP4)
- [x] B-roll checklist generated (MD)
- [ ] B-roll recordings completed (manual)
- [ ] Final video stitched (MP4)

---

## 🎓 Next Steps

### Learn More

- **Full Documentation:** [README.md](README.md)
- **Video Script Format:** [README.md#video-script-format](README.md#video-script-format)
- **Customization Guide:** [README.md#customization](README.md#customization)

### Generate More Videos

```bash
# Generate Module 2
python run_full_pipeline.py --module 2

# Generate all modules (after scripts are written)
python run_full_pipeline.py --all
```

### Upload to YouTube

1. Open final video: `output/final/Module_01_FINAL_*.mp4`
2. Upload to YouTube Studio
3. Set title: "Module 1: Set Up Your Snowflake AI Workspace | Cortex Masterclass"
4. Add description (from video script)
5. Add timestamps (from video script sections)

---

## 💡 Pro Tips

1. **Generate audio overnight** — Run audio generation before bed, create videos next morning
2. **Reuse B-roll** — Same Snowflake UI recording can be used across modules
3. **Test with preview** — Use `--preview 3` flags to test first 3 slides only
4. **Update audio only** — If script narration changes, just regenerate audio (don't redo B-roll)
5. **Parallel processing** — Use multiple terminals to generate audio for different modules simultaneously

---

**Ready to generate videos? Start here:**

```bash
python run_full_pipeline.py --module 1
```

Good luck! 🚀
