# Setup Guide — Snowflake Cortex Masterclass

Complete setup instructions to get started with the course.

---

## Prerequisites

- Basic SQL knowledge (SELECT, JOIN, WHERE clauses)
- Computer with internet connection (Windows, Mac, or Linux)
- Email account for Snowflake trial signup

---

## Step 1: Create Snowflake Trial Account (5 Minutes)

### 1.1 Sign Up for Free Trial

**Go to:** https://signup.snowflake.com/

**Fill in the form:**
- Email: (your email)
- First Name, Last Name
- Company: (can use "Personal" or your company name)
- Role: Data Engineer
- Country: India (or your location)

**Choose Edition:**
- Select **"Enterprise"** (recommended for Cortex features)
- Cloud Provider: **AWS** (recommended)
- Region: **US East (N. Virginia)** or **US West (Oregon)** (Cortex is available in these regions)

**Click "Continue"** and verify your email.

### 1.2 Activate Account

- Check your email for activation link
- Create strong password
- Accept terms and conditions
- Click "Get Started"

### 1.3 Verify Cortex Access

Once logged in, run these SQL commands in a new worksheet:

```sql
-- Check if Cortex Analyst is enabled
SELECT SYSTEM$CORTEX_ANALYST_STATUS();
-- Expected output: 'ENABLED'

-- Check if Cortex Agent is enabled
SELECT SYSTEM$CORTEX_AGENT_STATUS();
-- Expected output: 'ENABLED'

-- Check if Cortex Search is enabled
SELECT SYSTEM$CORTEX_SEARCH_STATUS();
-- Expected output: 'ENABLED'

-- Check your current region
SELECT CURRENT_REGION();
-- Should be us-east-1 or us-west-2
```

**If any return 'DISABLED':**
Enable cross-region Cortex (requires ACCOUNTADMIN):

```sql
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

---

## Step 2: Fork Course Repository (2 Minutes)

### 2.1 Create GitHub Account (if needed)

**Go to:** https://github.com/join

Sign up with email, create username, set password.

### 2.2 Fork the Course Repository

**Go to:** https://github.com/snowbrix-academy/cortex-masterclass

**Click "Fork" button** (top-right)

**Configure fork:**
- Owner: (your username)
- Repository name: `cortex-masterclass` (keep same name)
- Description: "My Snowflake Cortex Masterclass labs"
- ✅ Check "Copy the master branch only"

**Click "Create fork"**

### 2.3 Clone Your Fork Locally

```bash
# Replace YOUR-USERNAME with your GitHub username
git clone https://github.com/YOUR-USERNAME/cortex-masterclass.git

cd cortex-masterclass

# Add upstream remote (to pull updates from instructor)
git remote add upstream https://github.com/snowbrix-academy/cortex-masterclass.git

# Verify remotes
git remote -v
# Should show:
#   origin    https://github.com/YOUR-USERNAME/cortex-masterclass.git
#   upstream  https://github.com/snowbrix-academy/cortex-masterclass.git
```

---

## Step 3: Install Development Tools (10 Minutes)

### 3.1 Install Git (if not already installed)

**Windows:**
- Download: https://git-scm.com/download/win
- Run installer, use default settings
- Verify: Open Command Prompt, run `git --version`

**Mac:**
```bash
# Install via Homebrew
brew install git

# Or download from: https://git-scm.com/download/mac
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install git

# Fedora
sudo dnf install git
```

### 3.2 Install Python 3.11+ (for local testing)

**Windows:**
- Download: https://www.python.org/downloads/
- Run installer, **CHECK "Add Python to PATH"**
- Verify: `python --version` (should show 3.11+)

**Mac:**
```bash
brew install python@3.11
```

**Linux:**
```bash
sudo apt-get install python3.11
```

### 3.3 Install Visual Studio Code (Recommended)

**Download:** https://code.visualstudio.com/

**Install Extensions:**
- Snowflake (official extension)
- Python (Microsoft)
- YAML (Red Hat)
- GitLens

**Configure Snowflake Extension:**
1. Open VS Code
2. Click Snowflake icon in sidebar
3. Add account connection:
   - Account URL: `https://YOUR-ACCOUNT.snowflakecomputing.com`
   - Username: (your Snowflake username)
   - Password: (your Snowflake password)
   - Warehouse: `COMPUTE_WH` (default)

---

## Step 4: Run Course Setup Scripts (5 Minutes)

### 4.1 Set Up Snowflake Environment

Open Snowflake Worksheets and run:

```sql
-- Run the infrastructure setup script
-- This creates databases, schemas, warehouses, roles for the course
-- Copy contents of sql_scripts/01_infrastructure.sql and execute
```

### 4.2 Load Sample Data

```sql
-- Run all data loading scripts
-- Copy contents of sql_scripts/RUN_ALL_SCRIPTS.sql and execute
-- This loads 588K rows across 12 tables (< 2 minutes)
```

### 4.3 Verify Data Loaded

```sql
-- Run verification script
-- Copy contents of sql_scripts/VERIFY_ALL.sql and execute
-- Expected output: All tables with correct row counts
```

---

## Step 5: Test Your Setup (5 Minutes)

### 5.1 Test SQL Access

```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Test query
SELECT COUNT(*) FROM CUSTOMERS;
-- Expected: 1000 rows
```

### 5.2 Test Streamlit App Access

In Snowflake UI:
1. Go to **Projects > Streamlit**
2. Check if you can access Streamlit apps section
3. (Apps will be deployed in Module 2)

### 5.3 Test Git Workflow

```bash
# Create a test branch
git checkout -b test-setup

# Create a test file
echo "# Test Setup" > test.md

# Commit
git add test.md
git commit -m "Test: Verify git setup"

# Push to your fork
git push origin test-setup

# Delete test branch (cleanup)
git checkout master
git branch -D test-setup
git push origin --delete test-setup
```

---

## Troubleshooting

### "CORTEX services not available in this region"

**Solution:** Use `us-east-1` or `us-west-2` regions. Or enable cross-region:

```sql
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

### "Insufficient privileges to CREATE DATABASE"

**Solution:** Snowflake trial accounts have ACCOUNTADMIN by default. Verify:

```sql
SHOW GRANTS TO USER CURRENT_USER();
```

If missing privileges, contact your Snowflake admin.

### "Git clone failed: Permission denied"

**Solution:** Set up SSH keys or use HTTPS with personal access token:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitHub: Settings > SSH and GPG keys > New SSH key
# Then clone using SSH URL
```

### "Python version too old"

**Solution:** Install Python 3.11+ from python.org. Verify:

```bash
python --version  # or python3 --version
```

---

## Next Steps

✅ Setup complete! You're ready to start Module 1.

**Go to:** `labs/module_01/README.md` to begin your first lab.

**Need help?** Check [troubleshooting.md](troubleshooting.md) or open a [GitHub Issue](https://github.com/snowbrix-academy/cortex-masterclass/issues).

---

**Setup time:** ~30 minutes total
**You're ready to build production AI data apps in Snowflake!** 🚀
