# Agent Instructions for ESET Protect On-Prem Repository

## Repository Overview

**Repository Name:** eset.epop.tools  
**Purpose:** ESET Protect On-Prem installation automation and deployment tools  
**Owner:** rwgb  
**Current Branch:** dev (also default branch)  
**Last Updated:** January 20, 2026

This repository provides automated installation scripts and Docker containerization for deploying ESET Protect On-Prem (endpoint protection management server) on various platforms.

---

## 📋 Project Structure

```
├── README.md                          # Main installation guide
├── SECURITY.md                        # Security best practices
├── SECURITY-AUDIT-REPORT.md          # Security audit findings
├── docker/                           # Docker POC deployment (NOT production)
│   ├── docker-compose.yml            # Multi-container orchestration
│   ├── Makefile                      # Docker management commands
│   ├── README.md                     # Docker-specific documentation
│   ├── eset-server/                  # ESET Server container
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── supervisord.conf
│   ├── mysql/                        # MySQL 8.0 container
│   │   ├── init.sh
│   │   ├── init.sql
│   │   └── my.cnf
│   └── webconsole/                   # Tomcat web console container
│       ├── Dockerfile
│       ├── entrypoint.sh
│       └── server.xml
├── scripts/                          # Installation automation
│   ├── security-audit.sh             # Security scanning tool
│   ├── linux/
│   │   └── install-eset.sh           # Main Linux installer (1082 lines)
│   └── windows/
│       ├── install-eset-windows.go   # Windows Go-based installer (575 lines)
│       ├── build.bat                 # Windows build script
│       ├── build.sh                  # Cross-platform build script
│       ├── go.mod                    # Go dependencies
│       └── README.md
├── utils/
│   └── logging.sh                    # Logging utilities
└── .github/
    └── workflows/
        └── test-installation.yml     # CI/CD testing pipeline (562 lines)
```

---

## 🎯 Core Components

### 1. Linux Installation Script (`scripts/linux/install-eset.sh`)

**Capabilities:**
- **OS Support:** Ubuntu 20.04/22.04/24.04, Debian 10/11/12, RHEL/CentOS/Rocky/AlmaLinux 8/9, Fedora 38/39/40
- **Automated Detection:** OS type, version, package manager
- **Secure Credential Management:** Interactive password prompts with confirmation
- **Components Installed:**
  - MySQL 8.0 server with optimized configuration
  - ODBC connectors (version 8.0.40)
  - ESET Protect Server (latest from official sources)
  - Apache Tomcat 9.0.85
  - Web Console (latest ERA WAR file)
- **Security Features:**
  - Self-signed SSL/TLS certificate generation
  - HTTPS configuration for web console
  - Secure password handling (no storage in scripts)

**Key Functions:**
- `check_os()` - Detect Linux distribution
- `prompt_credentials()` - Securely collect passwords
- `install_dependencies()` - Install required packages
- `configure_mysql()` - Set up database
- `install_odbc_connector()` - Configure ODBC drivers
- `install_eset_server()` - Deploy ESET server
- `install_tomcat()` - Set up web console

**Configuration Variables:**
```bash
ODBC_VERSION="8.0.40"
ESET_INSTALLER_URL="https://download.eset.com/..."
TOMCAT_VERSION="9.0.85"
MYSQL_ROOT_PASSWORD    # Interactive prompt
ESET_ADMIN_PASSWORD    # Interactive prompt
DB_USER_USERNAME       # Interactive prompt
DB_USER_PASSWORD       # Interactive prompt
```

### 2. Windows Installation Script (`scripts/windows/install-eset-windows.go`)

**Implementation:** Go-based installer with Windows API integration

**Features:**
- Administrator privilege checking
- Download progress tracking
- Secure password input (hidden)
- MSI installation automation
- Colored console output
- Comprehensive logging to `C:\ProgramData\ESET\Logs\Installer`

**Build Process:**
```bash
# Build executable
./scripts/windows/build.sh

# Output: install-eset-windows.exe
```

### 3. Docker Deployment (`docker/`)

**⚠️ IMPORTANT: Proof of Concept Only - NOT Production Ready**

**Architecture:**
- **mysql**: MySQL 8.0 database (port 3306)
- **eset-server**: ESET Protect server (ports 2222, 2223)
- **webconsole**: Tomcat 9 web interface (ports 8080, 8443)

**Environment Variables Required:**
```env
MYSQL_ROOT_PASSWORD     # Strong password
ESET_ADMIN_PASSWORD     # Admin credentials
DB_USER_USERNAME        # Database user (default: erauser)
DB_USER_PASSWORD        # User password
```

**Health Checks:**
- MySQL: `mysqladmin ping`
- ESET Server: `curl -k https://localhost:2223`
- Web Console: `curl http://localhost:8080/era/`

**Management Commands:**
```bash
make up          # Start all services
make down        # Stop all services
make logs        # View logs
make restart     # Restart services
make clean       # Remove all data
```

### 4. Security Audit Script (`scripts/security-audit.sh`)

**Comprehensive Checks:**
1. **Credential Exposure:** API keys, tokens, private keys
2. **Hardcoded Passwords:** Variable assignments, ENV declarations
3. **`.gitignore` Validation:** Required patterns coverage
4. **Sensitive File Protection:** `.env`, `.pem`, `.key`, keystores
5. **File Size Limits:** Prevents large binary commits
6. **Git History Analysis:** Last 100 commits
7. **Docker Security:** Configuration review
8. **GitHub Actions Secrets:** Proper secret management
9. **Dependency Integrity:** Package verification
10. **Shell Script Linting:** ShellCheck validation

**Usage:**
```bash
./scripts/security-audit.sh
```

**Output:** Color-coded report with counts (critical, warnings, info)

### 5. CI/CD Pipeline (`.github/workflows/test-installation.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual workflow dispatch
- Path filters: `scripts/linux/install-eset.sh`, workflow file

**Jobs:**

1. **ShellCheck Validation**
   - Runs on all scripts
   - Severity: warning level
   - Uses: `ludeeus/action-shellcheck@master`

2. **Ubuntu Matrix Testing**
   - Versions: 20.04, 22.04, 24.04
   - Tests: Syntax validation, OS detection
   - Docker-based isolated testing
   - Failure logs uploaded as artifacts

3. **Debian Matrix Testing**
   - Versions: 10, 11, 12
   - Similar test coverage as Ubuntu

4. **RHEL-based Testing**
   - Distributions: Rocky Linux 8/9, AlmaLinux 8/9
   - Fedora: 38, 39, 40

5. **Test Summary Report**
   - Matrix result aggregation
   - Failure log collection
   - Downloadable artifacts

**Continue-on-error:** `true` for matrix jobs to test all versions

---

## 🔒 Security Guidelines

### Critical Rules

1. **NEVER commit `.env` files**
   - Always use `.env.example` templates
   - Real credentials in `.env` (gitignored)

2. **NEVER hardcode passwords/secrets**
   - Use environment variables: `${VAR_NAME}`
   - Use interactive prompts in scripts
   - GitHub Actions: use repository secrets

3. **ALWAYS run security audit before commits**
   ```bash
   ./scripts/security-audit.sh
   ```

4. **Protected Patterns** (must be in `.gitignore`):
   ```
   .env
   .env.*
   !.env.example
   *.log
   logs/
   docker/backups/
   *.pem
   *.key
   *.p12
   *.pfx
   *.jks
   ```

### Pre-Commit Hook

**Location:** `.git/hooks/pre-commit`

**Automated Checks:**
- Credential scanning (API keys, tokens, private keys)
- Hardcoded password detection
- File size limits (5MB max)
- ShellCheck for bash scripts
- Go formatting (`gofmt`, `go vet`)
- Docker Compose validation
- YAML syntax checking

**Installation:**
```bash
# Hook is automatically created
# Manually enable if needed:
chmod +x .git/hooks/pre-commit
```

---

## 🛠️ Development Workflow

### Adding New Features

1. **Create feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes following conventions**
   - Scripts: Use functions, proper logging
   - Docker: Test with `docker-compose up`
   - Documentation: Update relevant README files

3. **Run security audit**
   ```bash
   ./scripts/security-audit.sh
   ```

4. **Test locally**
   ```bash
   # Linux scripts
   shellcheck scripts/linux/*.sh
   
   # Windows Go code
   cd scripts/windows
   go fmt ./...
   go vet ./...
   go build
   ```

5. **Commit with descriptive messages**
   ```bash
   git add .
   git commit -m "feat: description of feature"
   ```

6. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

### Testing Installation Scripts

**DO NOT run full installations in CI** - they require:
- Actual ESET license
- Real database setup
- Service installation permissions

**CI Tests Focus On:**
- ✅ Syntax validation
- ✅ OS detection accuracy
- ✅ Function definition checks
- ✅ ShellCheck compliance
- ❌ Full installation (manual testing only)

**Manual Testing:**
```bash
# Test in clean VM/container
docker run -it ubuntu:24.04 bash
# Copy and run install script
```

### Modifying Docker Setup

**Remember:** Docker deployment is **EXPERIMENTAL**

When modifying:
1. Update `docker-compose.yml`
2. Rebuild images: `make rebuild`
3. Test startup sequence: `make up`
4. Check health checks: `docker ps`
5. Review logs: `make logs`
6. Update `docker/README.md`

**Common Issues:**
- Service start order (use `depends_on` with `condition: service_healthy`)
- Environment variable propagation
- Volume permissions
- Network connectivity between containers

---

## 📝 Code Style & Conventions

### Bash Scripts

**Header Template:**
```bash
#!/usr/bin/bash

#######################################
# Script Purpose
# Description of what it does
#######################################

set -e              # Exit on error
set -o pipefail     # Exit on pipe failure
```

**Logging:**
```bash
log_info "Information message"
log_warn "Warning message"
log_error "Error message"
log_step "Major step in process"
```

**Functions:**
- Use descriptive names: `install_mysql_server()` not `install_db()`
- Add comments explaining purpose
- Return early on errors
- Use local variables

**Error Handling:**
```bash
command || error_exit "Description of what failed"
```

### Go Code (Windows Installer)

**Style:**
- Follow standard Go formatting (`go fmt`)
- Use meaningful variable names
- Create custom types for complex structures
- Comprehensive error handling

**Logger Pattern:**
```go
logger.Info("Starting process...")
logger.Warn("Non-critical issue")
logger.Error("Critical failure: %v", err)
logger.Step("Major milestone")
```

### Docker Files

**Best Practices:**
- Use specific image tags (not `latest`)
- Multi-stage builds where applicable
- Minimize layers
- Use `.dockerignore`
- Include health checks
- Document exposed ports

### Documentation

**Markdown:**
- Use headers hierarchically
- Include code examples with language tags
- Add warnings with emoji/formatting: **⚠️ WARNING**
- Link to related docs: `[text](file.md)`

**README Structure:**
1. Title & Quick Description
2. Prerequisites
3. Installation/Usage
4. Configuration
5. Troubleshooting
6. Security Considerations

---

## 🧪 Testing Strategy

### Unit Testing
- **Bash:** Function-level testing with mock data
- **Go:** Standard `go test` framework
- **Docker:** Container health checks

### Integration Testing
- **CI/CD:** Matrix testing across OS versions
- **Manual:** Full installation in VMs

### Security Testing
- Automated: `security-audit.sh` on every commit
- Manual: Periodic penetration testing review
- Dependency scanning: GitHub Dependabot

---

## 🚀 Release Process

### Versioning
- Not currently using semantic versioning
- Branch-based: `dev` (default), `main` (stable)
- Tags: Create for major milestones

### Release Checklist
1. ✅ All CI tests passing
2. ✅ Security audit clean
3. ✅ Documentation updated
4. ✅ Manual testing on target platforms
5. ✅ CHANGELOG.md updated (if exists)
6. ✅ Merge to `main`
7. ✅ Create release tag

---

## 📚 Key Files Reference

### Must-Read Files
1. **[README.md](README.md)** - Main installation guide (759 lines)
2. **[SECURITY.md](SECURITY.md)** - Security practices (272 lines)
3. **[docker/README.md](docker/README.md)** - Docker deployment (297 lines)

### Configuration Files
- `docker/docker-compose.yml` - Container orchestration
- `docker/.env.example` - Environment template
- `docker/mysql/my.cnf` - MySQL configuration
- `docker/webconsole/server.xml` - Tomcat settings

### Scripts
- `scripts/linux/install-eset.sh` - Main installer (1082 lines)
- `scripts/windows/install-eset-windows.go` - Windows installer (575 lines)
- `scripts/security-audit.sh` - Security scanner (294 lines)

### CI/CD
- `.github/workflows/test-installation.yml` - Testing pipeline (562 lines)

---

## 🔧 Troubleshooting Guide

### Common Issues

#### 1. MySQL Connection Failures
**Symptoms:** ESET server can't connect to database

**Solutions:**
- Check MySQL is running: `systemctl status mysql`
- Verify credentials in config
- Test connection: `mysql -u root -p`
- Review logs: `/var/log/mysql/error.log`

#### 2. ODBC Driver Issues
**Symptoms:** "ODBC driver not found" errors

**Solutions:**
- Verify installation: `odbcinst -q -d`
- Check odbc.ini: `/etc/odbc.ini`
- Reinstall connector: Re-run ODBC installation step

#### 3. Tomcat Won't Start
**Symptoms:** Web console inaccessible

**Solutions:**
- Check Java installation: `java -version`
- Review Tomcat logs: `/opt/tomcat/logs/catalina.out`
- Verify port availability: `netstat -tuln | grep 8080`
- Check file permissions on Tomcat directory

#### 4. Docker Container Crashes
**Symptoms:** Containers constantly restarting

**Solutions:**
- Check logs: `docker logs <container-name>`
- Verify health checks: `docker inspect <container-name>`
- Ensure environment variables set: `docker exec <container> env`
- Check resource limits: `docker stats`

#### 5. Permission Denied Errors
**Symptoms:** Script fails with permission errors

**Solutions:**
- Run with sudo: `sudo ./install-eset.sh`
- Check file permissions: `ls -la`
- SELinux issues: `setenforce 0` (temporary)

---

## 🎓 Learning Resources

### ESET Documentation
- Official ESET Protect Admin Guide
- Download page: https://download.eset.com/
- Support portal: https://support.eset.com/

### Technologies Used
- **Shell Scripting:** Advanced Bash Programming Guide
- **Go:** Official Go documentation
- **Docker:** Docker Compose documentation
- **MySQL 8.0:** MySQL 8.0 Reference Manual
- **Apache Tomcat 9:** Tomcat 9 Configuration Reference

### Security Best Practices
- OWASP Top 10
- CIS Docker Benchmarks
- GitHub Secret Scanning documentation

---

## 🤝 Contributing Guidelines

### For AI Agents

When working with this repository:

1. **ALWAYS prioritize security**
   - Run security audit before suggesting commits
   - Never expose credentials in any form
   - Use environment variables for sensitive data

2. **Test before committing**
   - Validate syntax for all scripts
   - Run ShellCheck on bash files
   - Format Go code with `gofmt`

3. **Document changes**
   - Update relevant README files
   - Add comments to complex code
   - Include examples for new features

4. **Follow existing patterns**
   - Use established logging functions
   - Match existing code style
   - Maintain consistency across files

5. **Consider backwards compatibility**
   - Don't break existing installations
   - Provide migration paths for breaking changes
   - Test on all supported OS versions (via CI)

### For Human Contributors

- Fork the repository
- Create feature branch
- Follow code style guidelines
- Write clear commit messages
- Submit PR with description
- Respond to review feedback

---

## 📞 Support & Contact

**Repository Owner:** rwgb  
**Issues:** Use GitHub Issues for bug reports  
**Security Issues:** Report via GitHub Security Advisory (private)

---

## ⚖️ License & Legal

- Check LICENSE file for terms
- ESET Protect is commercial software (requires valid license)
- This repository provides installation automation only
- Not affiliated with or endorsed by ESET

---

## 🔄 Maintenance Notes

### Regular Tasks

**Weekly:**
- Review GitHub Issues
- Check for security audit failures
- Monitor CI/CD pipeline health

**Monthly:**
- Update ESET installer URLs if needed
- Review and update dependencies
- Check for new OS version support

**Quarterly:**
- Full manual testing on all supported platforms
- Security audit review
- Documentation accuracy check

**Annually:**
- Review and update security policies
- Evaluate new installation methods
- Consider deprecated OS version removal

### Dependencies to Monitor

1. **ESET Protect Versions**
   - Server installer URL may change
   - Web console WAR file updates
   - Compatibility with MySQL versions

2. **System Dependencies**
   - MySQL ODBC connector updates
   - Apache Tomcat security patches
   - OpenSSL updates

3. **Build Tools**
   - Go version compatibility
   - Docker base images
   - GitHub Actions updates

---

## 📊 Metrics & KPIs

### Code Quality
- ShellCheck: No warnings/errors
- Go: `go vet` clean
- Security Audit: Zero critical findings

### Testing
- CI Pass Rate: Target 100%
- OS Coverage: All supported versions
- Manual Test Success: Document results

### Security
- Secret Exposure: Zero tolerance
- Vulnerability Scan: Monthly
- Dependency Updates: Within 30 days

---

## 🎯 Project Goals

1. **Automation:** Reduce manual installation steps to single command
2. **Compatibility:** Support major Linux distributions and Windows
3. **Security:** Zero credential exposure, automated scanning
4. **Documentation:** Clear, comprehensive, up-to-date guides
5. **Testing:** Automated validation across platforms
6. **Maintainability:** Clean, well-structured, commented code

---

## Version Information

**Agent Instructions Version:** 1.0  
**Last Updated:** January 20, 2026  
**Repository Branch:** dev  
**Target ESET Version:** Latest (auto-download)

---

**End of Agent Instructions**
