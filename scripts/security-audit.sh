#!/bin/bash
#
# Security Audit Script for ESET Protect Repository
# Run this script to perform a comprehensive security scan
#
# Usage: ./scripts/security-audit.sh
#

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ESET Protect Repository Security Audit          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}\n"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ISSUES_FOUND=0
WARNINGS_FOUND=0

# ============================================================================
# 1. Check for exposed credentials
# ============================================================================
echo -e "${YELLOW}[1/10] Scanning for exposed credentials...${NC}"

# Check if .env files are properly ignored
if git ls-files | grep -E '^\.env$|/\.env$' | grep -v '\.env\.example'; then
    echo -e "${RED}CRITICAL: .env files are tracked by git!${NC}"
    git ls-files | grep -E '^\.env$|/\.env$' | grep -v '\.env\.example'
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No .env files in git${NC}"
fi

# Scan for hardcoded secrets in tracked files
echo "  Scanning for API keys and tokens..."
if git grep -E 'sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35}' 2>/dev/null; then
    echo -e "${RED}CRITICAL: API keys or tokens detected!${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No API keys detected${NC}"
fi

echo "  Scanning for private keys..."
if git grep -E 'BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY' 2>/dev/null; then
    echo -e "${RED}CRITICAL: Private keys detected!${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No private keys detected${NC}"
fi

echo ""

# ============================================================================
# 2. Check for hardcoded passwords
# ============================================================================
echo -e "${YELLOW}[2/10] Checking for hardcoded passwords...${NC}"

# Scan for password assignments (excluding variable declarations and prompts)
if git grep -E 'password\s*=\s*["\x27][^"\x27]{3,}["\x27]' | \
   grep -v 'password.*prompt\|read.*password\|input.*password\|your_password\|example\|changeit\|TODO'; then
    echo -e "${YELLOW}WARNING: Potential hardcoded passwords found${NC}"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
fi

# Check Docker files specifically
if git grep -E 'ENV.*PASSWORD.*=' docker/ 2>/dev/null | \
   grep -v '\${.*}\|changeme\|your_.*password\|example'; then
    echo -e "${YELLOW}WARNING: Check Docker ENV password declarations${NC}"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
else
    echo -e "${GREEN}✓ No hardcoded passwords in Docker files${NC}"
fi

echo ""

# ============================================================================
# 3. Validate .gitignore coverage
# ============================================================================
echo -e "${YELLOW}[3/10] Validating .gitignore...${NC}"

REQUIRED_PATTERNS=(
    ".env"
    ".env.*"
    "!.env.example"
    "*.log"
    "logs/"
    ".DS_Store"
    "*.swp"
    "docker/backups/"
)

for pattern in "${REQUIRED_PATTERNS[@]}"; do
    if ! grep -q "^${pattern}$" .gitignore; then
        echo -e "${RED}MISSING: .gitignore should include: $pattern${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

echo -e "${GREEN}✓ .gitignore validation complete${NC}\n"

# ============================================================================
# 4. Check for sensitive files in repository
# ============================================================================
echo -e "${YELLOW}[4/10] Checking for sensitive files...${NC}"

SENSITIVE_FILES=(
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
    "*.jks"
    "id_rsa"
    "id_dsa"
    ".aws/credentials"
    ".ssh/config"
)

for pattern in "${SENSITIVE_FILES[@]}"; do
    if git ls-files | grep -E "$pattern"; then
        echo -e "${RED}CRITICAL: Sensitive file type detected: $pattern${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

echo -e "${GREEN}✓ No sensitive file types found${NC}\n"

# ============================================================================
# 5. Check for IP addresses and hostnames
# ============================================================================
echo -e "${YELLOW}[5/10] Scanning for hardcoded IPs and hostnames...${NC}"

# Find IPs (excluding localhost, examples, and comments)
if git grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
   grep -v 'localhost\|127.0.0.1\|0.0.0.0\|255.255.255\|example\|TODO\|#.*[0-9]\|README' | \
   grep -v '192.168\|10.\|172.1[6-9]\|172.2[0-9]\|172.3[0-1]' | \
   head -10; then
    echo -e "${YELLOW}WARNING: Public IP addresses found (review above)${NC}"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
fi

echo -e "${GREEN}✓ IP address check complete${NC}\n"

# ============================================================================
# 6. Check file permissions
# ============================================================================
echo -e "${YELLOW}[6/10] Checking file permissions...${NC}"

# Check for world-writable files
if find . -type f -perm -002 2>/dev/null | grep -v '.git/'; then
    echo -e "${YELLOW}WARNING: World-writable files detected${NC}"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
else
    echo -e "${GREEN}✓ No world-writable files${NC}"
fi

# Check shell scripts are executable
NON_EXEC_SCRIPTS=$(find scripts -name "*.sh" ! -perm -u+x 2>/dev/null || true)
if [ -n "$NON_EXEC_SCRIPTS" ]; then
    echo -e "${YELLOW}WARNING: Shell scripts without execute permission:${NC}"
    echo "$NON_EXEC_SCRIPTS"
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
else
    echo -e "${GREEN}✓ All shell scripts are executable${NC}"
fi

echo ""

# ============================================================================
# 7. Check Docker security
# ============================================================================
echo -e "${YELLOW}[7/10] Docker security checks...${NC}"

if [ -f "docker/docker-compose.yml" ]; then
    # Check for privileged containers
    if grep -q 'privileged.*true' docker/docker-compose.yml; then
        echo -e "${YELLOW}WARNING: Privileged containers detected${NC}"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    else
        echo -e "${GREEN}✓ No privileged containers${NC}"
    fi
    
    # Check for host network mode
    if grep -q 'network_mode.*host' docker/docker-compose.yml; then
        echo -e "${YELLOW}WARNING: Host network mode detected${NC}"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    else
        echo -e "${GREEN}✓ No host network mode${NC}"
    fi
    
    # Verify .env.example exists
    if [ ! -f "docker/.env.example" ]; then
        echo -e "${RED}MISSING: docker/.env.example template${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}✓ .env.example template exists${NC}"
    fi
fi

echo ""

# ============================================================================
# 8. Check GitHub Actions security
# ============================================================================
echo -e "${YELLOW}[8/10] GitHub Actions security...${NC}"

if [ -d ".github/workflows" ]; then
    # Check for hardcoded secrets
    if grep -r 'password\|token\|secret' .github/workflows/*.yml | \
       grep -v 'secrets\.\|github.token\|GITHUB_TOKEN\|description\|input'; then
        echo -e "${YELLOW}WARNING: Review GitHub Actions for hardcoded secrets${NC}"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    else
        echo -e "${GREEN}✓ No hardcoded secrets in workflows${NC}"
    fi
    
    # Check for write permissions
    if grep -r 'permissions:' .github/workflows/*.yml | grep -q 'write'; then
        echo -e "${YELLOW}INFO: Write permissions used in workflows (review)${NC}"
    fi
fi

echo ""

# ============================================================================
# 9. Dependency security
# ============================================================================
echo -e "${YELLOW}[9/10] Checking dependencies...${NC}"

# Check Go dependencies
GO_MODS=$(find . -name "go.mod" -not -path "*/.*")
if [ -n "$GO_MODS" ]; then
    for mod in $GO_MODS; do
        dir=$(dirname "$mod")
        if [ -f "$dir/go.sum" ]; then
            echo -e "${GREEN}✓ $mod has go.sum${NC}"
        else
            echo -e "${RED}MISSING: go.sum for $mod${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done
fi

echo ""

# ============================================================================
# 10. Check git history for secrets
# ============================================================================
echo -e "${YELLOW}[10/10] Scanning git history (last 100 commits)...${NC}"

echo "  Checking for accidentally committed .env files..."
if git log --all --full-history -100 --pretty=format: --name-only | \
   grep -E '^\.env$|/\.env$' | grep -v '\.env\.example' | head -5; then
    echo -e "${RED}CRITICAL: .env files found in git history!${NC}"
    echo -e "${YELLOW}These must be removed using git filter-branch or BFG Repo-Cleaner${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ No .env files in recent history${NC}"
fi

echo ""

# ============================================================================
# Summary Report
# ============================================================================
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Security Audit Summary                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}\n"

if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ No security issues detected!${NC}"
    echo -e "${GREEN}Repository is ready for public sharing.${NC}"
    exit 0
else
    echo -e "${RED}Critical Issues: $ISSUES_FOUND${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS_FOUND${NC}\n"
    
    if [ $ISSUES_FOUND -gt 0 ]; then
        echo -e "${RED}⚠️  CRITICAL ISSUES MUST BE RESOLVED${NC}"
        echo -e "${YELLOW}Do NOT push to public repository until fixed.${NC}"
        exit 1
    else
        echo -e "${YELLOW}⚠️  Review warnings before publishing${NC}"
        exit 0
    fi
fi
