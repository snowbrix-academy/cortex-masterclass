# Mailchimp Setup Checklist for Cortex Masterclass

Complete this checklist to set up email capture and automated PDF delivery.

---

## ☐ Step 1: Create Mailchimp Account (5 minutes)

**Go to:** https://mailchimp.com/signup/

**Account details:**
- Email: [Your email]
- Username: snowbrix-academy (or your choice)
- Plan: **Free** (up to 500 contacts - perfect for waitlist)

**Verify email** and complete onboarding.

---

## ☐ Step 2: Create Audience (5 minutes)

1. **Dashboard > Audience > Create Audience**

2. **Fill in details:**
   ```
   Audience name: Cortex Masterclass Waitlist
   Default from email: [your_email]@gmail.com (or custom domain)
   Default from name: Snowbrix Academy
   Campaign URL: https://snowbrix-academy.github.io/cortex-masterclass
   ```

3. **Company details:**
   ```
   Company: Snowbrix Academy
   Address: [Your address for CAN-SPAM compliance]
   Phone: [Optional]
   ```

4. **Click "Save"**

---

## ☐ Step 3: Create Signup Form (10 minutes)

1. **Audience > Signup forms > Embedded forms**

2. **Form builder - Remove unnecessary fields:**
   - Keep: **Email** (required)
   - Remove: Last name, birthday, address, phone
   - Optional: Add **First Name** (recommended)

3. **Customize form:**
   - Button text: "Join Waitlist"
   - Success message: "Success! Check your email for the interview guide."

4. **Get form code:**
   - Click **"Generate Embed Code"**
   - Copy the code (will look like below)

**Example code structure:**
```html
<!-- Begin Mailchimp Signup Form -->
<div id="mc_embed_signup">
<form action="https://snowbrix.us1.list-manage.com/subscribe/post?u=XXXXXXXX&amp;id=XXXXXXXX"
      method="post"
      id="mc-embedded-subscribe-form"
      name="mc-embedded-subscribe-form"
      class="validate"
      target="_blank">

    <input type="email"
           value=""
           name="EMAIL"
           class="required email"
           id="mce-EMAIL"
           placeholder="Enter your email"
           required>

    <!-- real people should not fill this in -->
    <div style="position: absolute; left: -5000px;" aria-hidden="true">
        <input type="text"
               name="b_XXXXXXXX_XXXXXXXX"
               tabindex="-1"
               value="">
    </div>

    <input type="submit"
           value="Join Waitlist"
           name="subscribe"
           id="mc-embedded-subscribe">
</form>
</div>
<!--End mc_embed_signup-->
```

5. **Save these values** (you'll need them for landing page):
   ```
   Form Action URL: https://snowbrix.usX.list-manage.com/subscribe/post?u=XXXXXXXX&id=XXXXXXXX
   Honeypot field name: b_XXXXXXXX_XXXXXXXX
   ```

---

## ☐ Step 4: Upload PDF to GitHub Releases (10 minutes)

We'll use GitHub Releases for permanent PDF hosting.

1. **Go to:** https://github.com/snowbrix-academy/cortex-masterclass/releases/new

2. **Create release:**
   ```
   Tag: v1.0-waitlist
   Release title: Waitlist Lead Magnet
   Description: 50 Snowflake Cortex Interview Questions PDF for waitlist subscribers
   ```

3. **Attach file:**
   - Upload: `landing_page/50_Snowflake_Cortex_Interview_Questions.pdf`

4. **Publish release**

5. **Copy PDF URL** (will be):
   ```
   https://github.com/snowbrix-academy/cortex-masterclass/releases/download/v1.0-waitlist/50_Snowflake_Cortex_Interview_Questions.pdf
   ```

**Alternative (Google Drive - quicker):**
- Upload PDF to Google Drive
- Right-click > Share > "Anyone with link can view"
- Copy link (e.g., `https://drive.google.com/file/d/FILE_ID/view?usp=sharing`)

---

## ☐ Step 5: Set Up Welcome Automation (20 minutes)

1. **Dashboard > Automations > Create > Welcome new subscribers**

2. **Automation name:** "Waitlist Welcome + PDF Delivery"

3. **Trigger:** Subscribes to audience "Cortex Masterclass Waitlist"

4. **Email details:**
   - **From name:** Snowbrix Academy
   - **From email:** [your verified email]
   - **Subject:** Your Snowflake Cortex Interview Guide 🚀

5. **Email content:** (Use Mailchimp email designer)

```
Subject: Your Snowflake Cortex Interview Guide 🚀

----- EMAIL BODY -----

Hi {{FNAME|default:"there"}},

Thanks for joining the Cortex Masterclass waitlist! 🎉

Here's your free guide as promised:

👉 Download: 50 Snowflake Cortex Interview Questions
[Insert button with PDF link]

This guide covers:
✓ Cortex Analyst (natural language to SQL)
✓ Cortex Agent (autonomous investigations)
✓ Document AI & Cortex Search
✓ Streamlit in Snowflake compatibility
✓ Production patterns

━━━━━━━━━━━━━━━━━━━━━━━━

What's Next?

📅 Launch Date: February 20, 2026
💰 Early Bird: ₹4,999 (Save ₹2,000)
⏰ Limited to first 50 students

You'll get 48-hour early access before the public launch.

━━━━━━━━━━━━━━━━━━━━━━━━

What You'll Build:

1️⃣ Cortex Analyst App
Natural language to SQL using semantic YAML. Let business users query data in plain English.

2️⃣ Data Agent
Multi-step root cause analysis with autonomous tool orchestration.

3️⃣ Document AI + RAG Pipeline
PDF extraction + semantic search for customer support.

━━━━━━━━━━━━━━━━━━━━━━━━

Want a sneak peek?

Check out the full course plan on GitHub:
https://github.com/snowbrix-academy/cortex-masterclass

Questions? Just reply to this email.

Best,
Snowbrix Academy

P.S. You're subscriber #{{CONTACT_COUNT}} on the waitlist. We're aiming for 350 by launch day!

━━━━━━━━━━━━━━━━━━━━━━━━

Production-Grade Data Engineering. No Fluff.
```

6. **Add PDF download button:**
   - In Mailchimp email designer: Insert **Button** block
   - Button text: "Download Interview Guide (PDF)"
   - Button link: [Your PDF URL from Step 4]
   - Button color: Red (#ef4444)

7. **Preview email:**
   - Send test email to yourself
   - Check formatting on mobile
   - Verify PDF link works

8. **Activate automation**

---

## ☐ Step 6: Update Landing Page with Mailchimp Form (15 minutes)

Replace the placeholder form in `landing_page/index.html` with your Mailchimp form.

**Find this section** (around line 296):
```html
<form class="email-form" action="#" method="POST">
  <input type="email" name="email" placeholder="Enter your email" required>
  <button type="submit">Join Waitlist</button>
</form>
```

**Replace with:**
```html
<form class="email-form"
      action="[YOUR_MAILCHIMP_ACTION_URL]"
      method="POST"
      target="_blank">
  <input type="email"
         name="EMAIL"
         placeholder="Enter your email"
         required>

  <!-- Honeypot for spam protection -->
  <div style="position: absolute; left: -5000px;" aria-hidden="true">
    <input type="text"
           name="[YOUR_HONEYPOT_FIELD_NAME]"
           tabindex="-1"
           value="">
  </div>

  <button type="submit">Join Waitlist</button>
</form>
```

**Values to replace:**
- `[YOUR_MAILCHIMP_ACTION_URL]`: From Step 3 (e.g., `https://snowbrix.us1.list-manage.com/subscribe/post?u=XXX&id=XXX`)
- `[YOUR_HONEYPOT_FIELD_NAME]`: From Step 3 (e.g., `b_XXXXXXXX_XXXXXXXX`)

**Also update the JavaScript** (around line 335):

Remove the placeholder alert and update to:
```javascript
// Email form already submits to Mailchimp via form action
// Optionally track submission
document.querySelector('.email-form').addEventListener('submit', function(e) {
    // Track with Google Analytics if set up
    // gtag('event', 'waitlist_signup', {});
});
```

---

## ☐ Step 7: Test End-to-End (10 minutes)

1. **Commit and push updated landing page:**
   ```bash
   git add landing_page/index.html
   git commit -m "Integrate Mailchimp email capture"
   git push origin master
   ```

2. **Wait 2 minutes** for GitHub Pages to rebuild

3. **Test flow:**
   - Go to: https://snowbrix-academy.github.io/cortex-masterclass/
   - Submit your email
   - Should redirect to Mailchimp success page
   - Check email inbox (within 1-2 minutes)
   - Verify welcome email arrives
   - Click PDF download link
   - Verify PDF opens

4. **Check Mailchimp:**
   - Audience > View contacts
   - Your email should appear
   - Automation history should show "Sent"

5. **Test on mobile:**
   - Open landing page on phone
   - Submit email
   - Check email renders correctly on mobile

---

## ☐ Step 8: Soft Launch (30 minutes)

Send to 10-20 friends/colleagues for feedback.

**Email template:**
```
Subject: Need your feedback on my new course landing page

Hi [Name],

I'm launching a Snowflake Cortex course next week and would love your quick feedback on the landing page.

Link: https://snowbrix-academy.github.io/cortex-masterclass/

Specifically:
1. Is the value proposition clear?
2. Would you join the waitlist? Why/why not?
3. Does the pricing seem reasonable?
4. Any confusing parts?

Bonus: If you submit your email, you'll get a free PDF with 50 Snowflake interview questions.

Thanks!
[Your name]
```

**Collect feedback:**
- Value proposition clarity: [1-5]
- Interest level: [1-5]
- Pricing perception: [Too low / About right / Too high]
- Suggestions: [Free text]

**Iterate based on feedback:**
- Common confusion points? Update copy
- Pricing concerns? Emphasize value (12 hours, 3 apps, portfolio-ready)
- Design issues? Fix styling

---

## ☐ Step 9: Marketing Push (Friday)

**LinkedIn Post:**
```
🚀 Launching: Snowflake Cortex Masterclass

Build production AI data apps in 12 hours:
→ Cortex Analyst (natural language to SQL)
→ Data Agent (autonomous root cause analysis)
→ Document AI + RAG pipeline

Launch: Feb 20
Early Bird: ₹4,999 (first 50 students)

Join waitlist (+ get free interview guide):
https://snowbrix-academy.github.io/cortex-masterclass/

#Snowflake #DataEngineering #AI
```

**Twitter/X Post:**
```
New course dropping Feb 20 🚀

Snowflake Cortex Masterclass:
- Build 3 production AI apps
- 12 hours hands-on
- Portfolio-ready projects

Early bird: ₹4,999 (50 spots)

Waitlist: https://snowbrix-academy.github.io/cortex-masterclass/

Free interview guide included 👇
```

**Reddit Posts:**

r/snowflake:
```
Title: [Course] Snowflake Cortex Masterclass - Build Production AI Apps

I'm launching a hands-on course for Snowflake Cortex (Analyst, Agent, Document AI). Reverse-engineered from a real Innovation Summit booth demo.

What you'll build:
- Cortex Analyst app (semantic YAML + natural language queries)
- Data Agent for root cause analysis
- Document AI + RAG pipeline

Early bird: ₹4,999 ($60 USD) for first 50 students
Launch: Feb 20

Waitlist: https://snowbrix-academy.github.io/cortex-masterclass/

Free interview guide (50 Q&A) when you join.

Happy to answer questions!
```

r/dataengineering:
```
Title: Built a Snowflake Cortex course - 12 hours, 3 production apps

Background: Data engineer, turned an Innovation Summit demo into a full course.

Course covers:
1. Cortex Analyst (natural language to SQL)
2. Cortex Agent (multi-step investigations)
3. Document AI (PDF extraction + semantic search)

Progressive labs, GitHub workflows, production patterns.

Launch: Feb 20
Pricing: ₹4,999 early bird (₹6,999 regular)

Waitlist + free interview PDF:
https://snowbrix-academy.github.io/cortex-masterclass/

Feedback welcome!
```

---

## Success Metrics

Track these in a Google Sheet:

**Waitlist Growth:**
- Daily signups: [Target 35/day]
- Total signups: [Target 350 by Feb 19]
- Source breakdown: LinkedIn / Reddit / Twitter / Direct

**Email Performance:**
- Open rate: [Target >40%]
- Click rate (PDF): [Target >60%]
- Unsubscribe rate: [Target <1%]

**Conversion (Waitlist → Enrollment):**
- Early bird: [Target 23% = 80 students]
- Regular: [Target 10% = 30 students]

---

## Next Steps After Mailchimp Setup

1. **Schedule launch emails** (in Mailchimp):
   - Feb 18 (2 days before): "48 hours until launch"
   - Feb 20, 9am: "Course is LIVE - Early bird access"
   - Feb 21, 9am: "Last 24 hours for early bird"
   - Feb 22: "Early bird closed - regular pricing"

2. **Create Week 1 materials:**
   - Module 1 lab
   - Module 2 lab
   - Video recordings

3. **Set up course platform:**
   - Teachable or Udemy
   - Upload materials
   - Configure pricing

---

## Checklist Summary

- ☐ Create Mailchimp account (5 min)
- ☐ Create audience (5 min)
- ☐ Create signup form (10 min)
- ☐ Upload PDF to GitHub Releases (10 min)
- ☐ Set up welcome automation (20 min)
- ☐ Update landing page with form (15 min)
- ☐ Test end-to-end (10 min)
- ☐ Soft launch to friends (30 min)
- ☐ Marketing push (30 min)

**Total time: ~2 hours**

---

**Questions or issues?** Check EMAIL_CAPTURE_SETUP.md for detailed troubleshooting.

**Let's get to 350 waitlist signups! 🚀**
