# GitHub Workflow Guide — Snowflake Cortex Masterclass

How to submit labs using Git and GitHub.

---

## Overview: Feature Branch Workflow

**For each module:**
1. Create feature branch (`lab-module-XX`)
2. Complete lab (Part A + Part B)
3. Commit changes with descriptive messages
4. Push to your fork
5. Create Pull Request (PR) to your own `master`
6. Automated checks run (SQL lint, Python lint, YAML validation)
7. If checks pass ✅ → Merge PR → Module complete

---

## One-Time Setup

### 1. Fork the Course Repository

**Go to:** https://github.com/snowbrix-academy/cortex-masterclass

Click **"Fork"** button (top-right).

### 2. Clone Your Fork

```bash
# Replace YOUR-USERNAME with your GitHub username
git clone https://github.com/YOUR-USERNAME/cortex-masterclass.git
cd cortex-masterclass

# Add upstream remote (to pull instructor updates)
git remote add upstream https://github.com/snowbrix-academy/cortex-masterclass.git

# Verify
git remote -v
# Should show:
#   origin    https://github.com/YOUR-USERNAME/cortex-masterclass.git (your fork)
#   upstream  https://github.com/snowbrix-academy/cortex-masterclass.git (instructor)
```

---

## Per-Module Workflow

### Step 1: Start New Module

```bash
# Ensure you're on master and up-to-date
git checkout master
git pull origin master

# Pull any instructor updates
git pull upstream master

# Create feature branch for Module 2
git checkout -b lab-module-02
```

---

### Step 2: Complete Lab

**Do the lab work:**
- Read `labs/module_02/README.md`
- Complete Part A (guided lab)
- Complete Part B (open-ended challenge)
- Take screenshots of working app
- Test your code

**Add your files:**
```bash
# Add your lab files to the labs/module_02/ folder
# Example structure:
# labs/module_02/
#   ├── app_analyst.py (your Streamlit app)
#   ├── semantic_model.yaml (your semantic YAML)
#   └── screenshots/
#       └── query_results.png
```

---

### Step 3: Commit Changes (Atomic Commits)

**Make small, focused commits:**

```bash
# Add semantic YAML
git add labs/module_02/semantic_model.yaml
git commit -m "Add semantic YAML with 5-table model for Cortex Analyst"

# Add Streamlit app
git add labs/module_02/app_analyst.py
git commit -m "Add Cortex Analyst app with REST API integration"

# Add screenshots
git add labs/module_02/screenshots/
git commit -m "Add screenshots of working Analyst app query results"
```

**Good commit messages:**
- Start with verb (Add, Fix, Update, Remove)
- Be specific (not "Update files" but "Add semantic YAML with 5-table model")
- Keep under 72 characters for subject line

**Bad commit messages:**
- ❌ "Updated everything"
- ❌ "asdf"
- ❌ "fix"
- ❌ "more changes"

---

### Step 4: Push to Your Fork

```bash
# Push feature branch to your fork
git push origin lab-module-02
```

**If first time pushing branch:**
```bash
git push -u origin lab-module-02
```

---

### Step 5: Create Pull Request

**Go to:** `https://github.com/YOUR-USERNAME/cortex-masterclass`

**GitHub will show:** "lab-module-02 had recent pushes. Compare & pull request"

**Click "Compare & pull request"**

**Configure PR:**
- **Base repository:** `YOUR-USERNAME/cortex-masterclass` (your fork, NOT upstream!)
- **Base branch:** `master`
- **Compare branch:** `lab-module-02`

**Fill out PR template:**

```markdown
## Module 2 Lab Submission

### What I Built
- [x] Part A: Deployed Cortex Analyst app with 5 tables
- [x] Part B: Added custom verified query for regional AOV

**Key Artifacts:**
- `semantic_model.yaml` (5 tables: CUSTOMERS, PRODUCTS, ORDERS, ORDER_ITEMS, REGIONS)
- `app_analyst.py` (Streamlit app with REST API to Cortex Analyst)
- Screenshots showing query results

### What I Learned
- Semantic YAML relationships enable multi-table joins without explicit SQL
- Streamlit in Snowflake requires st.text_input (not st.chat_input)
- Pandas returns UPPERCASE columns from Snowflake (must normalize with .lower())

### Challenges I Faced
- **Challenge 1:** YAML indentation error caused 404 API response
  - **How I solved:** Used yamllint to validate, switched to 2-space indentation

- **Challenge 2:** KeyError: 'revenue' when accessing dataframe column
  - **How I solved:** Added df.columns = [c.lower() for c in df.columns] after query

### Questions for Instructor (Optional)
- None (or: "Should I use EMBED_TEXT_768 or EMBED_TEXT_1024 for Cortex Search?")

### Time Spent
- Part A: 1.5 hours
- Part B: 1 hour
- Total: 2.5 hours
```

**Click "Create pull request"**

---

### Step 6: Automated Checks Run

GitHub Actions automatically runs 4 checks:

1. ✅ **SQL Syntax** (sqlfluff) — No syntax errors
2. ✅ **Python Formatting** (black) — Consistent formatting
3. ✅ **Python Linting** (flake8) — No unused imports, undefined vars
4. ✅ **YAML Validation** (yamllint) — Correct indentation, syntax

**View check status:** Click "Details" next to each check to see output.

**If checks pass ✅:** PR is ready to merge!

**If checks fail ❌:**

```bash
# See what failed in GitHub Actions logs
# Fix issues locally

# Example: SQL syntax error
sqlfluff lint labs/module_02/*.sql --dialect snowflake
sqlfluff fix labs/module_02/*.sql --dialect snowflake

# Example: Python formatting
black labs/module_02/*.py

# Commit fixes
git add labs/module_02/
git commit -m "Fix SQL syntax and Python formatting issues"

# Push again (PR updates automatically)
git push origin lab-module-02

# Checks re-run automatically
```

---

### Step 7: Merge PR

**Once all checks pass ✅:**

Click **"Merge pull request"** → **"Confirm merge"**

**Result:** Your lab is now in your `master` branch. Module complete! 🎉

---

### Step 8: Clean Up

```bash
# Switch back to master
git checkout master

# Pull merged changes
git pull origin master

# Delete feature branch (local)
git branch -D lab-module-02

# Delete feature branch (remote)
git push origin --delete lab-module-02
```

---

### Step 9: Start Next Module

Repeat the process for Module 3:

```bash
git checkout master
git checkout -b lab-module-03
# Complete lab, commit, push, PR...
```

---

## Common Workflows

### Pull Instructor Updates

**Instructor releases new modules or solutions:**

```bash
# Pull from upstream (instructor repo)
git checkout master
git pull upstream master

# Push to your fork
git push origin master
```

---

### Fix Mistakes in Commits

**Wrong commit message:**

```bash
# Amend last commit message (only if not pushed yet)
git commit --amend -m "Correct commit message here"

# If already pushed, just make a new commit
git commit -m "Fix: Clarify previous commit - added YAML validation"
```

**Committed wrong files:**

```bash
# Unstage file
git reset HEAD .env

# Remove from Git (but keep local file)
git rm --cached .env

# Add to .gitignore
echo ".env" >> .gitignore

# Commit
git commit -m "Remove .env from version control"
```

**Need to undo last commit:**

```bash
# Undo commit but keep changes (can re-commit)
git reset --soft HEAD~1

# Undo commit and discard changes (⚠️ DESTRUCTIVE)
git reset --hard HEAD~1
```

---

## Collaboration: Asking for Help

**Option 1: GitHub Issues**

**Create issue:** https://github.com/snowbrix-academy/cortex-masterclass/issues/new

**Template:**
```markdown
**Module:** 2 (Cortex Analyst)
**Issue:** YAML indentation error causing 404

**What I tried:**
- Used 2-space indentation
- Validated with yamllint (passes)
- Checked table names match Snowflake

**Error message:**
HTTP 404: Cortex Analyst API endpoint not found

**YAML snippet:**
(paste relevant YAML lines)

**Request:** Can someone review my semantic model?
```

---

**Option 2: GitHub Discussions**

**Start discussion:** https://github.com/snowbrix-academy/cortex-masterclass/discussions

**Categories:**
- Q&A: Ask questions
- Show and tell: Share completed projects
- Ideas: Suggest improvements

---

## Git Best Practices

### ✅ DO:

- **Commit often** (small, atomic commits)
- **Write descriptive messages** (others understand what changed)
- **Test before committing** (run checks locally first)
- **Use feature branches** (one branch per module)
- **Pull before pushing** (avoid merge conflicts)

### ❌ DON'T:

- **Commit secrets** (.env files, passwords, API keys)
- **Force push to master** (`git push --force` destroys history)
- **Commit giant files** (node_modules, large datasets, videos)
- **Work directly on master** (always use feature branches)
- **Push without testing** (check code works before pushing)

---

## Troubleshooting

### "Git push rejected: non-fast-forward"

**Cause:** Remote has commits you don't have locally.

**Fix:**
```bash
# Pull remote changes first
git pull origin master

# Resolve conflicts if any (edit files, then)
git add .
git commit -m "Resolve merge conflicts"

# Push
git push origin master
```

---

### "PR shows 200 changed files (I only changed 3)"

**Cause:** Branch not up-to-date with master.

**Fix:**
```bash
# Update your branch with latest master
git checkout lab-module-02
git merge master

# Resolve conflicts if any
git add .
git commit -m "Merge master into lab-module-02"

# Push
git push origin lab-module-02

# PR now shows only your changes
```

---

### "GitHub Actions checks never run"

**Cause:** Workflow file missing or disabled.

**Fix:**
1. Check `.github/workflows/lab-checks.yml` exists
2. Go to GitHub repo > Actions tab
3. Enable workflows if disabled
4. Close and re-open PR (triggers checks)

---

## Interview Trap: "How do you handle Git merge conflicts?"

**Wrong Answer:**
"I don't know, I just delete the file and start over."

**Correct Answer (From Course):**
"3-step merge conflict resolution:
1. **Pull latest changes:** `git pull origin master` (Git marks conflicts in files)
2. **Edit conflicted files:** Open file, search for `<<<<<<<` markers, choose which version to keep (or merge both), remove markers
3. **Commit resolution:** `git add .`, `git commit -m 'Resolve merge conflicts'`, `git push`

**Prevention:** Pull before starting new work (`git pull origin master` before `git checkout -b lab-module-XX`). Small, frequent commits reduce conflict likelihood."

---

## Summary: Per-Module Checklist

- [ ] Checkout master, pull latest: `git checkout master && git pull upstream master`
- [ ] Create feature branch: `git checkout -b lab-module-XX`
- [ ] Complete lab (Part A + Part B)
- [ ] Commit changes (atomic, descriptive messages)
- [ ] Push to fork: `git push origin lab-module-XX`
- [ ] Create PR (to your own master, fill out template)
- [ ] Wait for automated checks ✅
- [ ] Merge PR
- [ ] Cleanup: Delete branch, switch to master
- [ ] Start next module!

---

**Git workflow time:** ~5 minutes per module (once you're comfortable)
**Focus on learning, not Git!** 🚀
