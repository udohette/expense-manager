# GitHub to GitLab Migration Guide
## For: Eintelix Expense Tracker

**Current Status:**
- Repository: `https://github.com/udohette/expense-manager.git`
- Latest commit: `cff8329` (Refine onboarding, auth flow, and bank alert import)

---

## PHASE 1: PREPARE (Before Migration)

### Step 1.1: Create GitLab Account & Project
1. Go to **https://gitlab.com**
2. Sign up or log in
3. Create a **New Project**:
   - **Project name**: `expense-tracker` (or `eintelix-expense-tracker`)
   - **Visibility**: Private (or Public based on your needs)
   - **Initialize with README**: NO (we'll use existing repo)
   - Click **Create Project**

### Step 1.2: Note Your GitLab URLs
After creation, you'll see:
- **Project URL**: `https://gitlab.com/YOUR_USERNAME/expense-tracker.git`
- **Project ID**: (visible in project settings)
- **SSH option**: `git@gitlab.com:YOUR_USERNAME/expense-tracker.git`

### Step 1.3: Generate GitLab Access Token
For command-line operations:
1. Go to **GitLab Settings → Access Tokens**
2. Create token with scopes: `api`, `read_repository`, `write_repository`
3. **Save this token** (you'll need it)

---

## PHASE 2: MIGRATE REPOSITORY

### Step 2.1: Mirror Clone (Best for Complete History)
This preserves all branches, tags, and history.

```bash
# Clone as a mirror from GitHub
git clone --mirror https://github.com/udohette/expense-manager.git expense-manager.git
cd expense-manager.git

# Push to GitLab (replace YOUR_USERNAME and YOUR_TOKEN)
git push --mirror https://YOUR_USERNAME:YOUR_TOKEN@gitlab.com/YOUR_USERNAME/expense-tracker.git

# Clean up
cd ..
rm -rf expense-manager.git
```

**OR** if using SSH:
```bash
git clone --mirror https://github.com/udohette/expense-manager.git expense-manager.git
cd expense-manager.git
git push --mirror git@gitlab.com:YOUR_USERNAME/expense-tracker.git
cd ..
rm -rf expense-manager.git
```

### Step 2.2: Update Your Local Repository
```bash
# Navigate to your project directory
cd /Users/dsamuel/VS-Code/manage_expense

# Update remote URL from GitHub to GitLab
git remote set-url origin https://YOUR_USERNAME:YOUR_TOKEN@gitlab.com/YOUR_USERNAME/expense-tracker.git

# Verify the change
git remote -v
# Should show GitLab URLs now

# Fetch to sync
git fetch origin
git pull origin main
```

### Step 2.3: Optional - Remove GitHub Completely
```bash
# If you want to stop using GitHub for this project
# Delete the GitHub repository (Settings → Danger Zone → Delete this repository)
# OR just leave it as an archive

# Verify GitLab is your only remote
git remote -v
# Should only show GitLab
```

---

## PHASE 3: SET UP CI/CD IN GITLAB

### Step 3.1: Create `.gitlab-ci.yml`
In your project root, create `.gitlab-ci.yml`:

```yaml
stages:
  - analyze
  - test
  - build
  - deploy

variables:
  FLUTTER_IMAGE: "cirrusci/flutter:3.10.7"

# Code Analysis & Linting
analyze:
  stage: analyze
  image: $FLUTTER_IMAGE
  script:
    - flutter pub get
    - flutter analyze
    - dart format --set-exit-if-changed lib test
  only:
    - merge_requests
    - main
    - develop

# Testing
test:
  stage: test
  image: $FLUTTER_IMAGE
  script:
    - flutter pub get
    - flutter test --coverage
  artifacts:
    paths:
      - coverage/
    expire_in: 30 days
  only:
    - merge_requests
    - main
    - develop

# Build Web
build:web:
  stage: build
  image: $FLUTTER_IMAGE
  script:
    - flutter pub get
    - flutter build web --no-tree-shake-icons --release
  artifacts:
    paths:
      - build/web/
    expire_in: 30 days
  only:
    - main
    - develop

# Build APK
build:apk:
  stage: build
  image: $FLUTTER_IMAGE
  script:
    - flutter pub get
    - flutter build apk --release
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/app-release.apk
    expire_in: 90 days
  only:
    - main
    - tags

# Deploy to Vercel (Manual)
deploy:vercel:
  stage: deploy
  image: node:18
  script:
    - npm install -g vercel
    - |
      if [ "$CI_COMMIT_BRANCH" == "main" ]; then
        vercel --prod --token $VERCEL_TOKEN --confirm
      else
        vercel --token $VERCEL_TOKEN --confirm
      fi
  environment:
    name: production
    url: https://your-vercel-domain.vercel.app
  only:
    - main
  when: manual
```

### Step 3.2: Add CI/CD Variables in GitLab
1. Go to **Settings → CI/CD → Variables**
2. Add these variables:

| Variable | Value | Protected |
|----------|-------|-----------|
| `VERCEL_TOKEN` | Your Vercel token | ✅ Yes |
| `VERCEL_ORG_ID` | Your Vercel org ID | ✅ Yes |
| `VERCEL_PROJECT_ID` | Your Vercel project ID | ✅ Yes |
| `SUPABASE_URL` | Your Supabase URL | ✅ Yes |
| `SUPABASE_PUBLISHABLE_KEY` | Your Supabase key | ✅ Yes |

3. Mark as **Protected** so they only run on protected branches

### Step 3.3: Delete GitHub Workflows (Optional)
Since you're moving to GitLab:

```bash
# Remove GitHub Actions workflows
rm -rf .github/

# Commit the change
git add .
git commit -m "Remove GitHub Actions workflows (migrated to GitLab CI/CD)"
git push origin main
```

---

## PHASE 4: CONFIGURE GITLAB PROJECT SETTINGS

### Step 4.1: Set Up Protected Branches
1. Go to **Settings → Repository → Protected Branches**
2. Protect `main`:
   - ✅ Require all pipelines to succeed
   - ✅ Require code review approval (1-2 reviewers)
   - ✅ Dismiss approvals when new commits pushed
3. Protect `develop`:
   - ✅ Require pipelines to succeed

### Step 4.2: Enable Merge Request Approvals
1. Go to **Settings → Merge requests**
2. Set **Approvals required**: 1-2
3. Enable **Dismiss approvals on new push**

### Step 4.3: Configure Default Branch
1. Go to **Settings → Repository**
2. Set **Default branch**: `main`

### Step 4.4: Add Deploy Keys (Optional, for CI/CD)
If using SSH for deployments:
1. **Settings → Repository → Deploy Keys**
2. Add your CI/CD SSH key for Vercel/other services

---

## PHASE 5: MIGRATE ISSUES & DISCUSSIONS (Optional)

### Option 1: Using GitLab Importer
1. Create new GitLab project
2. Go to **Settings → Integrations → GitHub**
3. Authorize and import GitHub issues/PRs
4. Note: This creates new issues, doesn't migrate them directly

### Option 2: Manual Export/Import
```bash
# Export issues from GitHub using GitHub CLI
gh issue list --repo udohette/expense-manager --format json > issues.json

# Import to GitLab using API (more complex)
# See: https://docs.gitlab.com/ee/api/issues.html
```

### Option 3: Keep Both
- Keep GitHub issues as archive
- Start fresh on GitLab with better structure

---

## PHASE 6: UPDATE DOCUMENTATION

### Step 6.1: Update README.md
Replace GitHub-specific URLs with GitLab:

```markdown
# Eintelix Expense Tracker

**Repository**: [GitLab](https://gitlab.com/YOUR_USERNAME/expense-tracker)

## CI/CD Pipeline
- **Status**: See [GitLab CI/CD](https://gitlab.com/YOUR_USERNAME/expense-tracker/-/pipelines)

## Contributing
- Fork on [GitLab](https://gitlab.com/YOUR_USERNAME/expense-tracker)
- Create a Merge Request
- Ensure CI/CD passes
```

### Step 6.2: Update Team Collaboration
- Update team docs/wiki to point to GitLab
- Set up GitLab Groups if using organization
- Configure email notifications

---

## PHASE 7: VERIFY MIGRATION

### Checklist:
- [ ] GitLab project created
- [ ] Repository pushed to GitLab with all history
- [ ] All branches migrated (`main`, `develop`, feature branches)
- [ ] All tags migrated
- [ ] `.gitlab-ci.yml` created and committed
- [ ] CI/CD variables added
- [ ] Protected branches configured
- [ ] First pipeline runs successfully
- [ ] Team members have access
- [ ] Documentation updated
- [ ] GitHub repo archived or deleted

### Test the Migration:
```bash
# Clone from GitLab
git clone https://gitlab.com/YOUR_USERNAME/expense-tracker.git test-repo
cd test-repo

# Verify history
git log --oneline -5

# Verify all branches
git branch -a

# Verify all tags
git tag -l

# Check CI/CD pipelines
# Go to https://gitlab.com/YOUR_USERNAME/expense-tracker/-/pipelines
```

---

## PHASE 8: CLEANUP

### Remove GitHub (if not needed)
1. Go to GitHub: **Settings → Danger Zone**
2. Click **Delete this repository**
3. Confirm deletion

### OR Archive GitHub
1. Go to GitHub: **Settings**
2. Scroll to **Danger Zone**
3. Click **Archive this repository**
4. Keeps it read-only for reference

---

## TROUBLESHOOTING

### Issue: "fatal: repository not found"
**Solution**: Check your GitLab URL and token/SSH key permissions

### Issue: Large repository push fails
**Solution**: Use `--mirror` clone method (as shown in Step 2.1)

### Issue: CI/CD pipeline not triggering
**Solution**:
1. Check `.gitlab-ci.yml` syntax: `git push` should trigger
2. Go to **CI/CD → Pipelines** to debug
3. Verify runners are available (shared runners are free)

### Issue: Variables not available in pipeline
**Solution**:
1. Mark variables as **Protected** only if on protected branch
2. For feature branches, use non-protected variables
3. Verify job has `only: - main` etc.

---

## ADDITIONAL RESOURCES

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Import from GitHub](https://docs.gitlab.com/ee/user/project/import/github.html)
- [GitLab Runner Setup](https://docs.gitlab.com/runner/install/)
- [GitLab API Docs](https://docs.gitlab.com/ee/api/)

---

## NEXT STEPS

1. **Immediate**: Complete Phase 1-3 (create GitLab project, migrate repo, add CI/CD)
2. **Short-term**: Set up team access and branch protection
3. **Long-term**: Configure runners if using self-hosted
4. **Optional**: Set up issue/discussion migration

---

**Questions?** Reach out to your DevOps team or GitLab support.
