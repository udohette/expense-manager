# Quick GitHub → GitLab Migration Checklist

## ⚡ Fast Track (30 minutes)

### 1️⃣ Create GitLab Project (2 min)
```bash
# Go to https://gitlab.com
# Click "New Project"
# Name: expense-tracker
# Visibility: Private
# Don't initialize with README
# Click "Create Project"
```

### 2️⃣ Mirror Clone & Push (5 min)
```bash
# Clone as mirror from GitHub
git clone --mirror https://github.com/udohette/expense-manager.git expense-mirror.git
cd expense-mirror.git

# Push to GitLab (use HTTPS with token or SSH key)
git push --mirror https://YOUR_USERNAME:YOUR_TOKEN@gitlab.com/YOUR_USERNAME/expense-tracker.git

# Cleanup
cd ..
rm -rf expense-mirror.git
```

**Where to get token:**
- GitLab Profile → Access Tokens → Create token (check: api, read_repository, write_repository)

### 3️⃣ Update Your Local Repository (2 min)
```bash
# Navigate to your project folder
cd /Users/dsamuel/VS-Code/manage_expense

# Update remote URL
git remote set-url origin https://YOUR_USERNAME:YOUR_TOKEN@gitlab.com/YOUR_USERNAME/expense-tracker.git

# Or use SSH (if you have SSH key configured)
git remote set-url origin git@gitlab.com:YOUR_USERNAME/expense-tracker.git

# Verify
git remote -v
# Should show GitLab URLs

# Pull to ensure sync
git pull origin main
```

### 4️⃣ Add CI/CD Configuration (3 min)
**Files already created for you:**
- `.gitlab-ci.yml` - Add to repo
- `GITLAB_MIGRATION_GUIDE.md` - Reference guide

```bash
# These files are ready in your workspace
# Just commit them:
git add .gitlab-ci.yml GITLAB_MIGRATION_GUIDE.md
git commit -m "Add GitLab CI/CD configuration"
git push origin main
```

### 5️⃣ Configure GitLab Project Settings (10 min)

**A. Add CI/CD Variables**
1. GitLab Project → Settings → CI/CD → Variables
2. Add these (mark as Protected):
   - `VERCEL_TOKEN` - from Vercel account
   - `VERCEL_ORG_ID` - from Vercel
   - `VERCEL_PROJECT_ID` - from Vercel
   - `SUPABASE_URL` - from Supabase
   - `SUPABASE_PUBLISHABLE_KEY` - from Supabase

**B. Protect Main Branch**
1. Settings → Repository → Protected Branches
2. Click "Protect" on `main`
3. ✅ Require all pipelines to succeed
4. ✅ Require approvals (1-2)
5. ✅ Dismiss approvals on new push

**C. Set Default Branch**
1. Settings → Repository
2. Default branch → Set to `main`

### 6️⃣ Verify Pipeline Runs (3 min)
1. Push any change to trigger pipeline:
   ```bash
   git commit --allow-empty -m "Trigger initial GitLab pipeline"
   git push origin main
   ```
2. Go to Project → CI/CD → Pipelines
3. Watch pipeline run through all stages
4. Verify ✅ analyze, ✅ test, ✅ build stages pass

### 7️⃣ Optional - Clean Up GitHub (2 min)
```bash
# Option A: Archive (keep as read-only)
# GitHub Repo → Settings → Danger Zone → Archive this repository

# Option B: Delete completely
# GitHub Repo → Settings → Danger Zone → Delete this repository
```

---

## 📋 Validation Checklist

After migration, verify everything:

- [ ] GitLab project created at `https://gitlab.com/YOUR_USERNAME/expense-tracker`
- [ ] All branches visible in GitLab (main, develop, feature branches)
- [ ] All tags visible in GitLab
- [ ] `.gitlab-ci.yml` in main branch
- [ ] First pipeline completed successfully
- [ ] CI/CD variables configured
- [ ] Protected branches set up
- [ ] Team members have access
- [ ] Can commit & push to GitLab
- [ ] Pipeline triggers on push/MR
- [ ] Vercel variables available in pipeline

---

## 🔧 Useful GitLab Commands

```bash
# Check remote
git remote -v

# Verify all history migrated
git log --oneline -10

# Check all branches
git branch -a

# Check all tags
git tag -l | head -10

# Pull all branches locally
git fetch --all

# Switch to develop branch
git checkout develop
```

---

## ❓ Common Issues & Fixes

| Problem | Solution |
|---------|----------|
| `fatal: repository not found` | Check GitLab URL and token/SSH key |
| Pipeline not triggering | Check `.gitlab-ci.yml` syntax, try git push |
| Variables not available | Mark as Protected only for protected branches |
| Large push fails | Use `--mirror` clone method |
| Can't push to GitLab | Check SSH key or use HTTPS with token |

---

## 📞 Support Resources

- **GitLab Docs**: https://docs.gitlab.com/ee/ci/
- **GitLab Import from GitHub**: https://docs.gitlab.com/ee/user/project/import/github.html
- **GitLab Runner Setup**: https://docs.gitlab.com/runner/

---

## 🎯 What's Next After Migration?

1. **Team Setup**: Add team members to GitLab project (Settings → Members)
2. **Automation**: Set up scheduled pipelines (CI/CD → Schedules)
3. **Notifications**: Configure Slack/email alerts (Integrations → Slack)
4. **Runners**: Use shared runners (free) or set up self-hosted
5. **Monitoring**: View pipeline metrics and coverage reports

---

**Estimated total time: 30 minutes**
**⚠️ Make sure you have:**
- GitLab account
- Vercel token
- Supabase credentials
- Access to GitHub repo (to migrate)
