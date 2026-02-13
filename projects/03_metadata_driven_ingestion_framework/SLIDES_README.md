# MDF Course Slides - Presentation Guide

## Overview

Professional PowerPoint presentation for the **Metadata-Driven Ingestion Framework** course. This 14-slide deck covers all 10 hands-on lab modules plus architecture and key features.

**File**: `MDF_Course_Slides.pptx`
**Target Audience**: Data Engineers (2-7 years experience), CTOs, VPs
**Duration**: 45-60 minute presentation

---

## Slide Breakdown

### Opening (Slides 1-2)
1. **Title Slide** - Course branding with Snowflake icon
2. **Course Overview** - 10 modules, 4-5 hours, multi-format support

### Module Details (Slides 3-12)
Each module slide includes:
- Duration badge (top right)
- Learning objectives (3 items)
- Key concepts (4-5 items)
- Deliverables checklist (6-7 items)

**Modules:**
3. Foundation Setup (20 min) - Databases, warehouses, RBAC
4. File Formats & Stages (15 min) - CSV/JSON/Parquet/Avro/ORC
5. Config Tables (20 min) - INGESTION_CONFIG drives behavior
6. Core Stored Procedures (30 min) - SP_GENERIC_INGESTION engine
7. CSV Ingestion Lab (30 min) - Hands-on structured data
8. Semi-Structured Data (45 min) - JSON with FLATTEN
9. Error Handling & Audit (25 min) - Retry logic and lineage
10. Automation (25 min) - Tasks + Streams
11. Monitoring & Dashboards (20 min) - 7 operational views
12. Schema Evolution (30 min) - Dynamic DDL and INFER_SCHEMA

### Closing (Slides 13-14)
13. **Architecture** - Visual diagram of 4-tier database design
14. **Key Features** - Production-ready capabilities

---

## Design Specifications

### Color Palette (Midnight Executive)
- **Primary**: #1E2761 (Deep Navy) - Headers, title slide
- **Secondary**: #CADCFC (Ice Blue) - Subtitles, accents
- **Accent**: #29B5E8 (Snowflake Blue) - Icons, badges
- **Background**: White/Light Gray for content slides

### Typography
- **Titles**: Arial Black, 40-44pt
- **Headers**: Arial, 20-22pt
- **Body**: Calibri, 14-15pt

### Layout Principles
- Module slides use consistent two-column layout
- Visual elements on every slide (no text-only slides)
- Deliverables highlighted in accent-bordered boxes
- Footer branding on all slides

---

## Usage Guide

### For Instructors
1. **Course Kickoff**: Use slides 1-2 to introduce the framework
2. **Module Previews**: Show relevant module slide before starting each lab
3. **Architecture Review**: Use slide 13 to explain system design
4. **Wrap-Up**: End with slide 14 to emphasize production readiness

### For Students
- Review slides before starting labs
- Reference module slides for learning objectives and deliverables
- Use architecture slide as mental model while coding

### For Marketing
- Slides 1-2 and 14 work as standalone course overview
- Architecture slide (13) demonstrates technical sophistication
- All slides follow Snowbrix Academy brand guidelines

---

## Customization

### Easy Updates
- **Duration badges**: Change time estimates in module header bars
- **Deliverables**: Add/remove checkmarks as needed
- **Branding**: Footer text is consistent across all slides
- **Colors**: All colors use defined palette (easy to swap)

### Adding Slides
If adding new modules, follow this pattern:
- Module header bar with duration badge
- Learning Objectives section (left)
- Key Concepts section (left)
- Deliverables box (right, light gray background)
- Footer with branding

---

## Technical Details

**File Format**: PowerPoint (.pptx)
**Compatibility**: PowerPoint 2013+, Google Slides, Keynote
**File Size**: ~385 KB
**Slide Count**: 14
**Aspect Ratio**: 10:7.5 (standard PowerPoint)

---

## Export Recommendations

### PDF for Distribution
```bash
# Using PowerPoint: File > Export > Create PDF
# Results in read-only format for student handouts
```

### Images for Web
```bash
# Export individual slides as JPG/PNG
# Use for course landing pages or thumbnails
```

### Speaker Notes
- No speaker notes included (slides are self-explanatory)
- Add notes in PowerPoint if needed for instructor script

---

## Alignment with Course Materials

### LAB_GUIDE.md
- Module titles match exactly
- Learning objectives align with lab content
- Durations match LAB_GUIDE.md specifications

### Project Memory
✅ Brand voice: "Production-Grade Data Engineering. No Fluff."
✅ No banned phrases (game-changer, revolutionary, etc.)
✅ Target audience: Data Engineers (2-7yr exp)
✅ MDF framework conventions (4 databases, SP_GENERIC_INGESTION)

---

## Quality Assurance

**Content Verification**: All 10 modules represented with accurate details
**Design Consistency**: Uniform layout, colors, and typography
**Brand Compliance**: Snowbrix Academy guidelines followed
**Visual Elements**: No text-only slides, all include shapes/icons
**Accuracy**: Durations sum to 4-5 hours as specified

See `MDF_Slides_QA_Report.md` for detailed verification checklist.

---

## Contact & Feedback

For questions or updates:
- Review `LAB_GUIDE.md` for course content
- Check `MDF_Slides_QA_Report.md` for QA details
- Modify `create_mdf_slides.js` to regenerate with changes

---

*Snowbrix Academy — Production-Grade Data Engineering. No Fluff.*
