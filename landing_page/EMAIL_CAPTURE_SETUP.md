# Email Capture Setup Guide

How to integrate Mailchimp or ConvertKit with the Cortex Masterclass landing page.

---

## Option 1: Mailchimp Integration (Recommended)

### Step 1: Create Mailchimp Account

**Go to:** https://mailchimp.com/signup/

**Free Plan:**
- Up to 500 contacts
- 1,000 sends/month
- Perfect for waitlist (target: 350 signups)

### Step 2: Create Audience

1. **Dashboard > Audience > Create Audience**
2. **Audience name:** "Cortex Masterclass Waitlist"
3. **Default from email:** your_email@snowbrix.academy
4. **Campaign URL:** snowbrix.academy/cortex-masterclass

### Step 3: Create Signup Form

1. **Audience > Signup forms > Embedded forms**
2. **Form builder:**
   - **Field:** Email (required)
   - **Field:** First Name (optional)
   - **Field:** LinkedIn Profile (optional)
   - **Button text:** "Join Waitlist"

3. **Get embed code:**
```html
<!-- Copy Mailchimp embed code, looks like: -->
<div id="mc_embed_signup">
  <form action="https://snowbrix.us1.list-manage.com/subscribe/post?u=xxx&id=xxx"
        method="post"
        id="mc-embedded-subscribe-form"
        name="mc-embedded-subscribe-form"
        class="validate"
        target="_blank">
    <input type="email" name="EMAIL" placeholder="Enter your email" required>
    <input type="submit" value="Join Waitlist" name="subscribe">
  </form>
</div>
```

### Step 4: Update Landing Page

Replace placeholder form in `index.html`:

**Before (lines 296-298):**
```html
<form class="email-form" action="#" method="POST">
  <input type="email" name="email" placeholder="Enter your email" required>
  <button type="submit">Join Waitlist</button>
</form>
```

**After:**
```html
<form class="email-form" action="https://snowbrix.us1.list-manage.com/subscribe/post?u=YOUR_USER_ID&id=YOUR_LIST_ID" method="POST" target="_blank">
  <input type="email" name="EMAIL" placeholder="Enter your email" required>
  <div style="position: absolute; left: -5000px;" aria-hidden="true">
    <input type="text" name="b_YOUR_USER_ID_YOUR_LIST_ID" tabindex="-1" value="">
  </div>
  <button type="submit">Join Waitlist</button>
</form>
```

### Step 5: Set Up Automated Welcome Email

1. **Automations > Create Automation > Welcome new subscribers**
2. **Email content:**

```
Subject: Your Snowflake Cortex Interview Guide (+ Early Bird Access)

Hi {{FNAME | fallback: "there"}},

Thanks for joining the waitlist! 🚀

Here's your free guide: **50 Snowflake Cortex Interview Questions**
👉 [Download PDF](https://snowbrix.academy/downloads/50_cortex_questions.pdf)

**What's Next:**
- Course launches February 20, 2026
- Early Bird pricing (₹4,999) for first 50 students (you're #{{CONTACT_COUNT}})
- You'll get 48-hour early access before public launch

**What You'll Build:**
✓ Cortex Analyst app (natural language to SQL)
✓ Data Agent (autonomous root cause analysis)
✓ Document AI + RAG pipeline

Questions? Just reply to this email.

Best,
Snowbrix Academy

P.S. Check out the course plan on GitHub:
https://github.com/snowbrix-academy/cortex-masterclass
```

3. **Attach PDF:**
   - Upload `50_Snowflake_Cortex_Interview_Questions.pdf` to Mailchimp
   - Add download link in email

### Step 6: Test Integration

1. **Submit test email** on landing page
2. **Check:**
   - Email appears in Mailchimp audience
   - Welcome email arrives within 1 minute
   - PDF download link works

### Step 7: Track Metrics

**Mailchimp Dashboard > Reports:**
- **Signup rate:** Target 350 by Feb 19
- **Open rate:** Target >40% (welcome email)
- **Click rate:** Target >20% (PDF download)

---

## Option 2: ConvertKit Integration

### Step 1: Create ConvertKit Account

**Go to:** https://convertkit.com/pricing

**Free Plan:**
- Up to 1,000 subscribers
- Unlimited landing pages & forms

### Step 2: Create Form

1. **Forms > Create Form > Inline**
2. **Form name:** "Cortex Masterclass Waitlist"
3. **Settings:**
   - **Success message:** "Check your email for the interview guide!"
   - **Redirect URL:** (optional) snowbrix.academy/thank-you

### Step 3: Get Embed Code

**Form > Share > Embed:**
```html
<script async data-uid="YOUR_FORM_ID" src="https://convertkit.com/forms/YOUR_FORM_ID/embed.js"></script>
```

### Step 4: Set Up Automation

1. **Automations > New Automation > From scratch**
2. **Trigger:** Subscribes to form "Cortex Masterclass Waitlist"
3. **Action:** Send email

**Email content:**
```
Subject: Your Snowflake Cortex Interview Guide 🚀

Hi {{first_name | default: "there"}},

Welcome to the Cortex Masterclass waitlist!

**Download your free guide:**
[50 Snowflake Cortex Interview Questions](LINK_TO_PDF)

**Early Bird Alert:**
- Launch: February 20, 2026
- Price: ₹4,999 (Save ₹2,000)
- Limited to first 50 students

You'll get 48-hour early access before the public launch.

Questions? Hit reply.

Best,
Snowbrix Academy
```

### Step 5: Tag Subscribers

**Tag:** `cortex-waitlist`
**Segment:** Use for launch announcement email on Feb 20

---

## Option 3: Simple Email Collection (No Tool)

If you want to avoid Mailchimp/ConvertKit initially:

### Step 1: Google Forms

1. **Create Google Form:**
   - Field: Email
   - Field: Name (optional)
   - Response: "Thanks! Check your email for the interview guide."

2. **Update landing page form:**
```html
<form class="email-form" action="https://docs.google.com/forms/d/e/YOUR_FORM_ID/formResponse" method="POST" target="hidden_iframe">
  <input type="email" name="entry.YOUR_ENTRY_ID" placeholder="Enter your email" required>
  <button type="submit">Join Waitlist</button>
</form>
<iframe name="hidden_iframe" style="display:none;"></iframe>
```

### Step 2: Manual Email Sending

1. **Export responses** from Google Sheets (Form > Responses > View in Sheets)
2. **Send welcome email** manually with PDF attached
3. **Track in spreadsheet:** Name, Email, Date Joined, PDF Sent (Y/N)

**Pros:** Free, no setup
**Cons:** Manual work, no automation, doesn't scale

---

## Hosting the PDF

Upload `50_Snowflake_Cortex_Interview_Questions.pdf` to:

**Option A: GitHub Pages**
```bash
# Upload to docs/ folder in GitHub repo
git add docs/50_Snowflake_Cortex_Interview_Questions.pdf
git commit -m "Add interview guide PDF for waitlist"
git push origin master

# Enable GitHub Pages: Settings > Pages > Source: master branch
# Access at: https://snowbrix-academy.github.io/cortex-masterclass/docs/50_Snowflake_Cortex_Interview_Questions.pdf
```

**Option B: AWS S3 (if available)**
```bash
aws s3 cp 50_Snowflake_Cortex_Interview_Questions.pdf s3://snowbrix-assets/cortex-masterclass/ --acl public-read
# Access at: https://snowbrix-assets.s3.amazonaws.com/cortex-masterclass/50_Snowflake_Cortex_Interview_Questions.pdf
```

**Option C: Google Drive (quick option)**
1. Upload PDF to Google Drive
2. **Right-click > Share > Anyone with the link can view**
3. Copy link (e.g., `https://drive.google.com/file/d/FILE_ID/view`)
4. Use in welcome email

---

## Launch Day Email Sequence

### Email 1: Welcome (Immediate)
- Subject: "Your Snowflake Cortex Interview Guide 🚀"
- Deliver PDF
- Explain early bird pricing

### Email 2: Reminder (Feb 18, 2 days before launch)
- Subject: "48 hours until Cortex Masterclass launch"
- Build anticipation
- Preview course modules

### Email 3: Early Bird Launch (Feb 20, 9am)
- Subject: "🚀 Cortex Masterclass is LIVE — Early Bird Access"
- Link to course enrollment
- Emphasize "First 50 students"

### Email 4: Early Bird Closing (Feb 21, 9am)
- Subject: "Last 24 hours — Early Bird ₹4,999 ends tomorrow"
- Create urgency
- Show testimonials (if any)

### Email 5: Regular Pricing (Feb 22)
- Subject: "Early Bird closed — Regular pricing now ₹6,999"
- Standard enrollment link

---

## Metrics to Track

**Waitlist Growth:**
- Daily signups (target: 35/day × 10 days = 350)
- Source tracking (LinkedIn, Reddit, Twitter, direct)

**Email Performance:**
- Open rate (target: >40%)
- Click rate (target: >20%)
- PDF download rate (target: >60%)

**Conversion (Waitlist → Enrollment):**
- Early Bird: Target 23% (80 students from 350 waitlist)
- Regular: Target 10% (additional 30 students)

**Dashboard:**
Use Google Sheets to track:
- Date | Signups | Total | Source | Open Rate | Click Rate | Enrolled

---

## Next Steps

1. **Choose email platform:** Mailchimp (recommended for beginners) or ConvertKit (better automation)
2. **Create account** and set up audience/form
3. **Update landing page** with embed code
4. **Upload PDF** to GitHub Pages or S3
5. **Set up welcome automation** with PDF link
6. **Test end-to-end:** Submit email → Receive welcome → Download PDF
7. **Soft launch** landing page to friends/colleagues (10-20 people) for feedback
8. **Hard launch** on Feb 14 (marketing push starts)

**Estimated time:** 2-3 hours for Mailchimp setup + testing

---

**Questions?** Contact: [your_email@snowbrix.academy]

**Production-Grade Data Engineering. No Fluff.** — Snowbrix Academy
