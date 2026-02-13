# MDF Video Course — Production Guide

## Snowbrix Academy | Production-Grade Data Engineering. No Fluff.

---

## Course Title
**"Build a Metadata-Driven Ingestion Framework in Snowflake — From Zero to Production"**

## Subtitle
One framework. Infinite sources. Zero hardcoded scripts.

---

## Target Audience
| Segment | Experience | What They Get |
|---------|-----------|---------------|
| Data Engineers | 2-7 years | Production-ready framework they can deploy at work |
| Analytics Engineers | 1-5 years | Understanding of ingestion layer they depend on |
| CTOs / VPs of Data | 10+ years | Architecture pattern to standardize their team's work |
| Career Changers | 0-2 years | Portfolio project that stands out in interviews |

## Prerequisites
- Snowflake account (trial works, any edition)
- Basic SQL knowledge (SELECT, INSERT, CREATE TABLE)
- Familiarity with at least one file format (CSV or JSON)
- No Snowflake-specific experience required (we teach everything)

---

## Course Structure

### Total Duration: ~4.5 hours (10 modules)

| # | Module | Video Length | Type | Key Deliverable |
|---|--------|-------------|------|-----------------|
| 01 | Foundation Setup | 25 min | Architecture + Hands-On | 4 databases, 4 warehouses, 5 roles |
| 02 | File Formats & Stages | 20 min | Concept + Hands-On | 10 file formats, 4+ stages |
| 03 | Config Tables (The Brain) | 30 min | Deep Dive + Hands-On | 6 metadata tables, 5 sample configs |
| 04 | Core Stored Procedures | 35 min | Deep Dive + Live Coding | SP_GENERIC_INGESTION engine |
| 05 | CSV Ingestion Lab | 25 min | 100% Hands-On | End-to-end CSV pipeline |
| 06 | JSON & Parquet Lab | 35 min | 100% Hands-On | Semi-structured pipeline + FLATTEN |
| 07 | Error Handling & Audit | 20 min | Pattern + Hands-On | Validation + retry procedures |
| 08 | Automation (Tasks/Streams) | 25 min | Architecture + Hands-On | Scheduled task tree + CDC |
| 09 | Monitoring Dashboards | 20 min | Hands-On + Demo | 7 monitoring views |
| 10 | Schema Evolution & Advanced | 25 min | Advanced + Demo | Multi-client onboarding |

---

## Video Production Specs

### Technical Setup
- **Resolution**: 1920x1080 (1080p) minimum
- **Frame Rate**: 30 fps
- **Audio**: Clear narration, no background music during code sections
- **Screen Recording**: Full screen SQL worksheet (Snowsight or VS Code)
- **Font Size in IDE**: Minimum 16px for readability
- **IDE Theme**: Dark theme (matches brand)

### Per-Video Structure (The Snowbrix Format)

```
[0:00 - 0:15]  THE HOOK
               Show the end result first. A working pipeline. A dashboard. A number.
               "By the end of this module, you'll have [specific outcome]."

[0:15 - 1:30]  THE CONTEXT
               Architecture slide. Where this module fits in the big picture.
               "Here's what we're building and why it matters."

[1:30 - X:00]  THE BUILD
               Live coding. Run every statement. Show the output.
               Pattern interrupts every 90 seconds (switch between slides/code/diagram).

[X:00 - X+2]   THE VERIFICATION
               Run verification queries. Prove it works.
               "Let's confirm everything is in place."

[Last 1:00]    THE BRIDGE
               Recap what was built. Preview next module.
               "That's [X] in production. Next, we'll build [Y]."
```

### Slide Design Rules
- Dark background (#1A1A2E)
- Maximum 5 bullet points per slide
- Code snippets: Fira Code font, syntax highlighted
- Architecture diagrams: ASCII art or clean boxes
- Every slide has the module number in the corner
- No clip art, no stock photos, no gradients

### Narration Style
- Direct, confident, conversational
- Explain the WHY before the HOW
- Use production war stories as context
- No filler words ("um", "basically", "actually")
- Reference real-world scale ("In production, you'll have 200 of these, not 5")

---

## Recording Checklist (Per Module)

### Pre-Recording
- [ ] SQL scripts tested end-to-end in a clean Snowflake account
- [ ] Slides reviewed for typos and accuracy
- [ ] Screen recording tool configured (OBS / Camtasia)
- [ ] Snowsight worksheet open with correct context (role, warehouse, database)
- [ ] Sample data files ready for upload
- [ ] Notes/script printed or on second monitor

### During Recording
- [ ] Start with the hook (show the end result)
- [ ] Show the architecture slide (where are we?)
- [ ] Run every SQL statement live (don't skip)
- [ ] Show the output of every verification query
- [ ] Pause after key concepts (let it sink in)
- [ ] Call out common mistakes and gotchas

### Post-Recording
- [ ] Add chapter markers / timestamps
- [ ] Cut dead air and long pauses (but keep natural pace)
- [ ] Add zoom-ins on important code sections
- [ ] Export slides as PDF backup
- [ ] Upload SQL scripts to course repository

---

## Content Flow Diagram

```
MODULE 01 ──→ MODULE 02 ──→ MODULE 03 ──→ MODULE 04
Foundation     Formats        Config         Procedures
(Setup)        (Storage)      (Brain)        (Engine)
                                                │
                           ┌────────────────────┤
                           │                    │
                      MODULE 05            MODULE 06
                      CSV Lab              JSON Lab
                           │                    │
                           └────────┬───────────┘
                                    │
                              MODULE 07
                              Error Handling
                                    │
                              MODULE 08
                              Automation
                                    │
                              MODULE 09
                              Monitoring
                                    │
                              MODULE 10
                              Advanced
```

Modules 01-04 are sequential (each builds on the previous).
Modules 05-06 can be done in either order.
Modules 07-10 are sequential but depend on 01-06.

---

## Call-to-Action Strategy (Per Video)

| Module | CTA Type | Script |
|--------|----------|--------|
| 01-03 | Community | "Join the Snowbrix Engineering Room on Slack — link in description." |
| 04-06 | Subscribe | "If this is saving you time, subscribe. We go deeper in the next module." |
| 07-08 | Lead Magnet | "Download the complete SQL scripts and sample data — link below." |
| 09-10 | Academy | "This is Module 10 of a complete course inside Snowbrix Academy. Full curriculum at the link." |

---

## File Naming Convention

```
slides/    module_XX_slides.html        (HTML slide deck)
scripts/   module_XX_video_script.md    (Narration script with timing)
```
