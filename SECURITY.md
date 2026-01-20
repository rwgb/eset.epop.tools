# Security Best Practices

This document outlines the security measures and best practices implemented in this repository.

## 🔒 Automated Security Controls

### Pre-Commit Hook

A comprehensive pre-commit hook (`.git/hooks/pre-commit`) automatically runs before every commit to:

1. **Scan for Sensitive Data**
   - API keys (OpenAI, GitHub, AWS, Google)
   - Private keys (RSA, DSA, EC, PGP)
   - Hardcoded passwords and tokens
   - IP addresses (with exceptions for localhost/documentation)

2. **Validate File Protection**
   - Ensures `.env` files are not committed
   - Validates `.gitignore` includes critical patterns
   - Checks for sensitive file types (.pem, .key, .p12, etc.)

3. **Code Quality Checks**
   - Shell script linting with `shellcheck`
   - Go code formatting with `gofmt`
   - Go static analysis with `go vet`
   - Docker Compose syntax validation
   - YAML syntax validation

4. **File Size Limits**
   - Prevents commits of files larger than 5MB
   - Suggests Git LFS for large binary files

### Manual Security Audit

Run the security audit script anytime:

```bash
./scripts/security-audit.sh
```

This performs a comprehensive scan including:
- Credential exposure detection
- Git history analysis (last 100 commits)
- Docker security configuration review
- GitHub Actions secret management check
- Dependency integrity validation

## 🛡️ Protected Sensitive Data

### Environment Variables

All sensitive configuration is stored in `.env` files that are:
- ✅ Listed in `.gitignore`
- ✅ Never committed to git
- ✅ Provided as `.env.example` templates
- ✅ Checked by pre-commit hooks

**Protected files:**
```
.env
.env.*
docker/.env
```

**Template files (safe to commit):**
```
docker/.env.example
```

### Credentials Required

The following credentials are user-provided and never stored in the repository:

| Credential | Location | Purpose |
|------------|----------|---------|
| MySQL Root Password | `.env` or script prompt | Database administration |
| ESET Admin Password | `.env` or script prompt | Web console login |
| Database User Password | `.env` or script prompt | Application database access |

## 🔐 Secure Credential Management

### For Development

1. **Copy the template:**
   ```bash
   cp docker/.env.example docker/.env
   ```

2. **Edit with secure values:**
   ```bash
   # Use a secure editor that doesn't save to history
   vim docker/.env  # or nano, code, etc.
   ```

3. **Verify protection:**
   ```bash
   git check-ignore docker/.env
   # Should output: .gitignore:2:.env    docker/.env
   ```

### For Production

**DO NOT** store production credentials in:
- Git repository (obviously)
- Local `.env` files committed to git
- Shell history
- Log files
- CI/CD workflow files

**DO** use:
- GitHub Secrets for CI/CD workflows
- Environment variables in production
- Secret management tools (Vault, AWS Secrets Manager, etc.)
- Encrypted password managers for manual entry

## 🚨 What Gets Blocked

The security controls will prevent commits containing:

### Critical (Blocks Commit)
- ✋ API keys matching known patterns
- ✋ Private key files (.pem, .key, id_rsa, etc.)
- ✋ `.env` files with real credentials
- ✋ Files over 5MB
- ✋ Invalid YAML/Docker syntax

### Warnings (Review Required)
- ⚠️ Hardcoded passwords in code
- ⚠️ Public IP addresses
- ⚠️ Shell scripts with linting errors
- ⚠️ Go code formatting issues

## 🔍 How to Verify Security

### Before First Push

```bash
# Run the security audit
./scripts/security-audit.sh

# Check what files will be committed
git status

# Verify .env is not tracked
git ls-files | grep "\.env$"
# Should return nothing (or only .env.example)

# Check .gitignore is working
git check-ignore docker/.env
# Should show it's ignored
```

### Before Every Commit

The pre-commit hook runs automatically, but you can also:

```bash
# Run manually
.git/hooks/pre-commit

# Bypass if absolutely necessary (NOT RECOMMENDED)
git commit --no-verify
```

## 📋 Security Checklist

Before making repository public:

- [ ] Run `./scripts/security-audit.sh` with 0 critical issues
- [ ] Verify no `.env` files in `git ls-files`
- [ ] Check `git log --all --name-only` for historical leaks
- [ ] Review all `docker-compose.yml` environment variables use `${VAR}` syntax
- [ ] Confirm `.env.example` has placeholder values only
- [ ] Test pre-commit hook: `git commit` (should run checks)
- [ ] Remove any personal/production data from logs
- [ ] Review README for accidental IP/hostname exposure

## 🛠️ Tools Used

### Required
- `bash` - Shell script execution
- `git` - Version control

### Optional (Enhanced Security)
- `shellcheck` - Shell script linting
- `go` - Go code validation
- `docker-compose` - Docker syntax validation
- `python3` - YAML validation

Install optional tools:

**macOS:**
```bash
brew install shellcheck go docker-compose python3
```

**Ubuntu/Debian:**
```bash
sudo apt-get install shellcheck golang docker-compose python3
```

**RHEL/CentOS:**
```bash
sudo yum install ShellCheck golang docker-compose python3
```

## 🚑 Emergency Procedures

### If Credentials Are Committed

1. **DO NOT** push to remote repository
2. **Immediately** change all exposed credentials
3. **Remove from git history:**

   ```bash
   # Using git filter-branch (slower but built-in)
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch docker/.env' \
     --prune-empty --tag-name-filter cat -- --all
   
   # OR using BFG Repo-Cleaner (faster)
   # Download from: https://rtyley.github.io/bfg-repo-cleaner/
   java -jar bfg.jar --delete-files .env
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```

4. **Force push** (if already pushed):
   ```bash
   git push --force --all
   git push --force --tags
   ```

5. **Rotate credentials immediately**

### If Repository Already Public

1. **Revoke/rotate all credentials** in the repository immediately
2. **Delete the repository** from GitHub
3. **Clean git history** as shown above
4. **Re-create** as new repository
5. **Audit** access logs for unauthorized use

## 📚 Additional Resources

- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
- [Git Filter-Branch](https://git-scm.com/docs/git-filter-branch)
- [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## 🎯 Quick Reference

### Safe to Commit
✅ `.env.example` (template with placeholders)  
✅ Scripts that prompt for passwords  
✅ Docker files using `${VARIABLE}` syntax  
✅ Documentation mentioning "password" conceptually  
✅ README files with example values

### Never Commit
❌ `.env` (actual credentials)  
❌ `id_rsa`, `.pem`, `.key` files  
❌ API keys or tokens  
❌ Hardcoded passwords in code  
❌ Production database dumps  
❌ Private SSL certificates

---

**Last Updated:** January 2026  
**Maintained By:** Repository Security Team
