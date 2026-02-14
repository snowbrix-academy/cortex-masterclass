# Video Recording Guide - Module 1 & 2

Complete step-by-step guide to record, edit, and publish course videos.

**Estimated time:**
- Setup: 30 minutes (one-time)
- Recording: 3 hours (both modules)
- Editing: 2 hours (both modules)
- **Total: 5.5 hours**

---

## 📋 Pre-Recording Checklist (30 minutes - One-Time Setup)

### **Step 1: Install Recording Software** (10 minutes)

**Option A: OBS Studio (Free, Recommended)**

**Download:** https://obsproject.com/download

**Installation:**
1. Download for Windows
2. Run installer (default settings)
3. Launch OBS Studio
4. Click "Auto-Configuration Wizard"
5. Select "Optimize for recording"
6. Accept recommended settings

**Option B: Camtasia (Paid, Easier to Edit)**

**Download:** https://www.techsmith.com/video-editor.html
- Free 30-day trial
- $299 one-time purchase
- Simpler interface than OBS

---

### **Step 2: Configure OBS Settings** (10 minutes)

**Open OBS Studio > Settings**

**Video Settings:**
```
Base Resolution: 1920x1080
Output Resolution: 1920x1080
FPS: 30
```

**Output Settings:**
```
Output Mode: Simple
Recording Quality: High Quality
Recording Format: MP4
Encoder: Hardware (NVENC) if available, otherwise x264
```

**Audio Settings:**
```
Sample Rate: 48kHz
Channels: Stereo
```

**Hotkeys:**
```
Start Recording: F9
Stop Recording: F10
```

---

### **Step 3: Set Up Microphone** (5 minutes)

**Check microphone quality:**
1. Open OBS
2. Click Settings > Audio
3. Select your microphone (Mic/Auxiliary Audio)
4. Speak into mic - watch audio meter
5. Adjust volume so it peaks around -12dB (green zone)

**Recommended USB mics:**
- Blue Yeti ($100)
- Audio-Technica ATR2100x ($80)
- Samson Q2U ($70)
- Built-in laptop mic (acceptable for MVP)

**Mic tips:**
- Position 6-8 inches from your mouth
- Use pop filter (or improvise with sock over mic)
- Record in quiet room (close windows, turn off AC)

---

### **Step 4: Prepare Snowflake Environment** (5 minutes)

**Clean Snowflake account:**
1. Clear browser cache/cookies
2. Log in to Snowflake trial account
3. Close all worksheets except one blank one
4. Close all browser tabs except Snowflake
5. Pin taskbar (hide desktop icons)
6. Set browser zoom to 100%
7. Maximize Snowflake window

**Test scripts:**
1. Run Module 1 setup scripts (RUN_ALL_SCRIPTS.sql)
2. Verify 588K rows loaded
3. Have scripts ready in VS Code
4. Test semantic model upload

---

## 🎬 Recording Workflow

### **Recording Session Setup (Before Each Module)**

**1. Environment prep (5 minutes):**
```bash
☐ Close all unnecessary programs
☐ Disable notifications (Windows: Focus Assist ON)
☐ Silence phone
☐ Close Slack, email, messaging apps
☐ Clear desktop (hide personal files)
☐ Have water nearby (avoid dry mouth clicks)
☐ Test mic levels in OBS
```

**2. Screen layout:**
```bash
☐ Snowflake Worksheets open (browser maximized)
☐ VS Code with scripts (on second monitor or alt-tab ready)
☐ Module script open (printed or on phone/tablet)
☐ OBS recording indicator visible
```

**3. Do a dry run (10 minutes):**
- Read script aloud (don't record yet)
- Time each section
- Practice screen transitions
- Identify tricky parts

---

### **Module 1 Recording (1.5 hours)**

**File:** `video_scripts/module_01_script.md`

**Recording approach:** Record in segments

**Segment 1: Intro + Snowflake Setup (10 min)**
- [00:00-00:30] Cold open
- [00:30-02:00] Snowflake trial signup
- [02:00-03:30] Verify Cortex access

**Break (2 min):** Review footage, check audio

**Segment 2: Repository + Data Loading (15 min)**
- [03:30-05:30] Clone repository
- [05:30-07:30] Run setup scripts
- [07:30-09:00] Verify data

**Break (2 min):** Check if data loaded correctly

**Segment 3: Stage Setup + Closing (8 min)**
- [09:00-10:30] Set up Cortex Analyst stage
- [10:30-11:30] Test Cortex Analyst
- [11:30-12:00] Recap and next steps

**Tips for Module 1:**
- Speed up script execution (record at normal speed, speed up in edit)
- If setup script fails, pause recording, fix, restart section
- Have backup Snowflake account ready in case of issues

---

### **Module 2 Recording (1.5 hours)**

**File:** `video_scripts/module_02_script.md`

**Segment 1: YAML + SQL Testing (8 min)**
- [00:00-00:30] Cold open (show working app)
- [00:30-02:30] Understanding semantic YAML
- [02:30-05:00] Test Cortex Analyst via SQL

**Break (2 min):** Review YAML explanations

**Segment 2: Build Streamlit App (12 min)**
- [05:00-07:30] Code walkthrough
- [07:30-09:30] Deploy to Snowflake

**Break (2 min):** Verify app deployed correctly

**Segment 3: Demo + Closing (8 min)**
- [09:30-12:00] Test 5 queries in app
- [12:00-13:30] Architecture explanation
- [13:30-15:00] Troubleshooting + next steps

**Tips for Module 2:**
- Pre-test all 5 demo queries before recording
- Have app already deployed (show deployment, but use working app)
- If query fails, pause, fix semantic model, restart section

---

### **Recording Best Practices**

**Voice/Narration:**
- ✅ Speak clearly at moderate pace (140-150 words/min)
- ✅ Pause 2 seconds between sections (easier to cut in edit)
- ✅ If you make a mistake: pause 3 seconds, restart sentence
- ✅ Add emphasis to key concepts ("This is CRITICAL...")
- ✅ Vary tone (don't be monotone)
- ❌ Don't say "um", "uh", "like" (pause instead)
- ❌ Don't apologize for mistakes on camera

**Mouse movements:**
- ✅ Move slowly and deliberately
- ✅ Hover over clickable items for 1 second before clicking
- ✅ Use large cursor (Windows: Settings > Ease of Access > Cursor)
- ❌ Don't zigzag or shake mouse

**Typing:**
- ✅ Type SQL at normal speed (shows you're human)
- ✅ OR paste and explain line-by-line (faster for long scripts)
- ❌ Don't type super fast (viewers can't follow)

**Mistakes are OK:**
- Wrong click? Pause 3 seconds, say "Let me do that again"
- SQL error? Pause, fix, continue
- Lost train of thought? Pause, consult script, continue
- You'll edit out pauses later

---

## ✂️ Post-Production Editing (2 hours total)

### **Option A: Basic Editing with OBS + Free Tools**

**Software needed:**
- OBS Studio (recording) - FREE
- Shotcut (editing) - FREE
- Audacity (audio cleanup) - FREE

**Workflow:**
1. Import recording into Shotcut
2. Cut long pauses (anything >2 seconds)
3. Remove mistakes/restarts
4. Add intro/outro cards (optional)
5. Export as MP4 (1920x1080, 30fps)

**Time:** 1 hour per module (basic cuts only)

---

### **Option B: Professional Editing with Camtasia**

**Software:** Camtasia ($299 or 30-day trial)

**Workflow:**

**1. Import footage (5 min):**
- File > Import > Select recording
- Drag to timeline

**2. Basic edits (30 min per module):**
- Remove long pauses: Select, Delete
- Remove mistakes: Cut at pause, delete segment
- Trim beginning/end for clean start/finish

**3. Add enhancements (30 min per module):**

**Zoom-ins for readability:**
- When showing small text/code
- Animation: Scale up to 150% for 3-4 seconds
- Example: Zooming into YAML syntax

**Text callouts:**
- Key concepts: "Remember: df.columns = [c.lower() for c in df.columns]"
- Error messages: Highlight and annotate
- Code snippets: Add text box with larger font

**Cursor highlighting:**
- Camtasia > Visual Effects > Cursor Effects
- Add subtle yellow glow when clicking

**Speed adjustments:**
- Speed up long-running queries (2x speed)
- Speed up file uploads (2x speed)
- Keep voice at 1x speed

**Transitions:**
- Use fade for section breaks
- Keep it simple (no fancy wipes)

**4. Audio cleanup (15 min per module):**
- Remove background noise: Audio > Remove Noise
- Normalize volume: Audio > Audio Effects > Compressor
- Add subtle background music (optional, low volume)

**5. Chapters/Markers (10 min per module):**
- Add markers at each timestamp from script
- Export marker list for YouTube chapters

**6. Export (10 min per module):**
```
Format: MP4
Resolution: 1920x1080
Frame rate: 30fps
Quality: High (8-10 Mbps)
```

**Total editing time with Camtasia:** ~2 hours (1 hour per module)

---

### **Option C: Outsource Editing (Fiverr)**

**Cost:** $20-50 per video

**Process:**
1. Upload raw footage to Google Drive / Dropbox
2. Hire editor on Fiverr (search "screencast editing")
3. Provide script with timestamps
4. Request: Remove pauses, add zoom-ins, add captions
5. Receive edited video in 2-3 days

**Pros:** Save time, professional result
**Cons:** Cost, slower turnaround

---

## 📤 Publishing to YouTube (30 minutes)

### **Step 1: Create YouTube Channel** (5 min)

**If you don't have one:**
1. Go to YouTube.com
2. Sign in with Google account
3. Click profile icon > "Create a channel"
4. Channel name: "Snowbrix Academy"
5. Add channel description and logo (optional)

---

### **Step 2: Upload Videos** (10 min per video)

**Upload Module 1:**
1. YouTube Studio > Create > Upload video
2. Select: `module_01_edited.mp4`
3. **Title:** Module 1: Set Up Your Snowflake AI Workspace | Cortex Masterclass
4. **Description:**

```
Learn to set up your Snowflake environment for AI data apps with Cortex services.

🎯 What you'll learn:
• Create Snowflake trial account with Cortex enabled
• Load 588,000 rows across 12 tables
• Set up semantic models for Cortex Analyst
• Verify your environment is ready

📚 Course materials:
https://github.com/snowbrix-academy/cortex-masterclass

⏱️ Timestamps:
00:00 Introduction
00:30 Create Snowflake Trial
02:00 Verify Cortex Access
03:30 Clone Repository
05:30 Run Setup Scripts
07:30 Verify Data
09:00 Set Up Stage
10:30 Test Cortex Analyst
11:30 Recap & Next Steps

📋 Lab instructions:
https://github.com/snowbrix-academy/cortex-masterclass/tree/master/labs/module_01

🎓 Join the course:
https://snowbrix-academy.github.io/cortex-masterclass

#Snowflake #DataEngineering #AI #Cortex
```

5. **Thumbnail:** Create simple thumbnail with "Module 1: Setup" text
6. **Playlist:** Create "Snowflake Cortex Masterclass" playlist, add video
7. **Visibility:**
   - **Unlisted** (for course students only) OR
   - **Public** (for marketing / lead generation)
8. Click **Publish**

**Repeat for Module 2**

---

### **Step 3: Create Thumbnails** (10 min - Optional but Recommended)

**Easy method: Canva (Free)**

1. Go to Canva.com
2. Search "YouTube Thumbnail"
3. Template suggestion:
   - Background: Blue gradient (Snowflake colors)
   - Text: "Module 1: Setup" (large, bold)
   - Subtitle: "Snowflake Cortex" (smaller)
   - Icon: Snowflake logo (optional)
4. Download as PNG
5. Upload to YouTube (Edit video > Thumbnail > Upload)

**Consistent style:**
- Module 1: Blue background + "Setup"
- Module 2: Blue background + "Cortex Analyst"

---

### **Step 4: Add YouTube Chapters** (5 min per video)

**YouTube Auto-Chapters from Description:**

YouTube automatically creates chapters if you format timestamps like this in description:

```
00:00 Introduction
00:30 Create Snowflake Trial
02:00 Verify Cortex Access
...
```

Ensure:
- First timestamp is 00:00
- Timestamps are in ascending order
- At least 3 chapters, each >10 seconds

YouTube will show chapter markers in video progress bar.

---

## 🎓 Add Videos to Course Platform

### **Option A: Link to YouTube (Simple)**

In course platform (Teachable, Thinkific, etc.):
1. Create lesson: "Module 1: Video"
2. Add video block
3. Paste YouTube URL (unlisted)
4. Students watch on YouTube

**Pros:** Free hosting, easy
**Cons:** Students can share link

---

### **Option B: Embed in Course (Better)**

1. YouTube video > Share > Embed
2. Copy embed code
3. Course platform > Add HTML block
4. Paste embed code
5. Video plays within course page

**Pros:** Looks professional, can't easily share
**Cons:** Still hosted on YouTube

---

### **Option C: Upload Directly to Platform (Best)**

If your course platform supports native video:
1. Upload MP4 directly (no YouTube)
2. Platform handles streaming

**Pros:** Secure, no external dependencies
**Cons:** Storage limits, bandwidth costs

**Teachable:** 2GB per video (sufficient for 15 min @ 1080p)

---

## ⚡ Quick Start Guide (TL;DR)

**Minimal viable setup (2 hours):**

1. **Install OBS Studio** (10 min)
   - Download, auto-configure for recording

2. **Test microphone** (5 min)
   - Speak, check audio meter hits green zone

3. **Prepare Snowflake** (15 min)
   - Fresh trial, close extra tabs, run setup scripts

4. **Record Module 1** (45 min)
   - Follow script, record in 3 segments
   - Don't worry about perfection

5. **Basic edit with Shotcut** (30 min)
   - Remove long pauses (>3 sec)
   - Trim start/end

6. **Upload to YouTube** (10 min)
   - Unlisted, add description with timestamps

7. **Repeat for Module 2** (1 hour)

**Result:** Both videos recorded, edited, and published in 3 hours.

---

## 🛠️ Troubleshooting

### **Issue: OBS recording is laggy**

**Solution:**
```
Settings > Output > Encoder: Change to "Hardware (NVENC)"
Settings > Video > FPS: Reduce to 24 if 30 is too high
Close Chrome/browser (use Firefox for less resource usage)
```

### **Issue: Microphone sounds muffled**

**Solution:**
```
Windows: Settings > System > Sound > Device properties
Disable "Audio enhancements"
Enable "Noise suppression" (Windows 11)
Move closer to mic (6 inches)
```

### **Issue: Snowflake scripts fail during recording**

**Solution:**
```
PAUSE recording (don't stop)
Fix issue in Snowflake
Resume recording
Say "Let me run that again"
Continue
(Edit out the pause later)
```

### **Issue: File size too large (>2GB)**

**Solution:**
```
Camtasia: Export > Video Settings > Quality: "Medium"
Reduces bitrate from 10Mbps to 5Mbps
OR
Use Handbrake (free) to compress after export
```

---

## 📋 Recording Checklist

**Before recording:**
- [ ] OBS configured (1920x1080, 30fps)
- [ ] Microphone tested (audio levels good)
- [ ] Notifications disabled
- [ ] Snowflake environment clean
- [ ] Scripts ready in VS Code
- [ ] Water nearby
- [ ] Script printed or on second device

**During recording:**
- [ ] Start OBS recording (F9)
- [ ] Follow script section by section
- [ ] Pause 2 seconds between sections
- [ ] If mistake: pause 3 sec, restart sentence
- [ ] Speak clearly, moderate pace
- [ ] Move mouse slowly
- [ ] Stop recording (F10) after each segment

**After recording:**
- [ ] Review footage for major issues
- [ ] Import into editing software
- [ ] Remove pauses >2 seconds
- [ ] Remove mistakes/restarts
- [ ] Add zoom-ins for small text
- [ ] Add text callouts for key concepts
- [ ] Export as MP4 (1920x1080, 30fps)
- [ ] Upload to YouTube
- [ ] Add description + timestamps
- [ ] Create thumbnail
- [ ] Add to course platform

---

## 🎬 Alternative: Screen Recording Only (No Face)

**If you prefer not to show your face:**

The course scripts are designed for **screencast-only** (no webcam).

**Advantages:**
- Simpler setup (no camera, lighting, backdrop)
- Easier to edit (just screen + voice)
- Focus stays on content
- Professional look (Snowflake demos, code)

**To add face later (optional):**
- Record webcam separately
- Add picture-in-picture in bottom-right corner
- Only for intro/outro (not entire video)

---

## 📊 Success Metrics

**Good enough to publish:**
- ✅ Audio is clear (no background noise)
- ✅ Screen is readable (1080p+)
- ✅ Follows script (covers all topics)
- ✅ No major errors (small mistakes are fine)
- ✅ Under 20 minutes (longer = edit more)

**Don't aim for perfection:**
- Small pauses are OK (sounds natural)
- Minor mistakes are OK (shows you're human)
- You can always re-record sections later
- Students care about learning, not production quality

**Launch threshold:** 80% quality is enough for MVP.

---

## ⏱️ Time Breakdown

**Total time investment:**

| Task | Module 1 | Module 2 | Total |
|------|----------|----------|-------|
| Setup (one-time) | 30 min | - | 30 min |
| Recording | 45 min | 45 min | 1.5 hrs |
| Editing (basic) | 30 min | 30 min | 1 hr |
| Editing (pro) | 1 hr | 1 hr | 2 hrs |
| Publishing | 15 min | 15 min | 30 min |
| **Total (basic)** | - | - | **3.5 hrs** |
| **Total (pro)** | - | - | **5 hrs** |

**Recommendation:** Start with basic editing. You can always improve later.

---

**Ready to start recording? Let me know if you need any clarification on the setup!** 🎥
