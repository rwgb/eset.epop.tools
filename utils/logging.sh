#!/usr/bin/bash

#######################################
# ESET Web Console Diagnostic Script
# Collects logs and information for troubleshooting
#######################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/webconsole-diagnostic-$(date +%Y%m%d-%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}ESET Web Console Diagnostic Tool${NC}"
echo -e "${BLUE}Log file: ${LOG_FILE}${NC}"
echo ""

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "========================================"
echo "ESET Web Console Diagnostic Report"
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo "========================================"
echo ""

separator() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

separator "1. WAR File and Deployment Directory Status"
echo "Checking /opt/tomcat/webapps/ for era files:"
ls -lh /opt/tomcat/webapps/ | grep era || echo "No era files found"
echo ""

if [[ -f /opt/tomcat/webapps/era.war ]]; then
    echo "WAR file details:"
    file /opt/tomcat/webapps/era.war
    echo "WAR file size: $(stat -f%z /opt/tomcat/webapps/era.war 2>/dev/null || stat -c%s /opt/tomcat/webapps/era.war 2>/dev/null) bytes"
else
    echo "WARNING: era.war not found"
fi

separator "2. ERA Deployment Directory Contents"
if [[ -d /opt/tomcat/webapps/era/ ]]; then
    echo "ERA directory exists. Contents:"
    ls -la /opt/tomcat/webapps/era/ | head -20
    echo ""
    
    if [[ -d /opt/tomcat/webapps/era/WEB-INF/ ]]; then
        echo "WEB-INF directory contents:"
        ls -la /opt/tomcat/webapps/era/WEB-INF/
    else
        echo "WARNING: WEB-INF directory not found - deployment likely incomplete"
    fi
else
    echo "ERROR: /opt/tomcat/webapps/era/ directory does not exist"
    echo "This indicates the WAR file was not deployed"
fi

separator "3. Tomcat Service Status"
systemctl status tomcat --no-pager

separator "4. Tomcat Catalina Log (Last 100 Lines)"
if [[ -f /opt/tomcat/logs/catalina.out ]]; then
    tail -100 /opt/tomcat/logs/catalina.out
else
    echo "ERROR: catalina.out not found"
fi

separator "5. Tomcat Localhost Application Log"
LOCALHOST_LOG=$(ls -t /opt/tomcat/logs/localhost.*.log 2>/dev/null | head -1)
if [[ -n "$LOCALHOST_LOG" ]]; then
    echo "Log file: $LOCALHOST_LOG"
    echo ""
    tail -50 "$LOCALHOST_LOG"
else
    echo "No localhost log files found"
fi

separator "6. Errors and Exceptions in Catalina Log"
if [[ -f /opt/tomcat/logs/catalina.out ]]; then
    echo "Recent errors/exceptions:"
    grep -i "error\|exception\|failed" /opt/tomcat/logs/catalina.out | tail -20 || echo "No errors found"
else
    echo "catalina.out not found"
fi

separator "7. HTTP Response Tests"
echo "Testing http://localhost:8080/ :"
curl -I http://localhost:8080/ 2>&1 | head -10
echo ""

echo "Testing http://localhost:8080/era :"
curl -I http://localhost:8080/era 2>&1 | head -10
echo ""

echo "Testing https://localhost:8443/era :"
curl -k -I https://localhost:8443/era 2>&1 | head -10
echo ""

separator "8. Tomcat Webapps Directory Full Listing"
ls -la /opt/tomcat/webapps/

separator "9. Tomcat Configuration Check"
echo "Checking server.xml for connectors:"
grep -A 5 "Connector port=" /opt/tomcat/conf/server.xml | grep -v "<!--"

separator "10. Java Version"
java -version 2>&1

separator "11. Tomcat Process Information"
ps aux | grep tomcat | grep -v grep

separator "12. Port Listening Status"
echo "Checking if ports 8080 and 8443 are listening:"
netstat -tlnp 2>/dev/null | grep -E '8080|8443' || ss -tlnp | grep -E '8080|8443'

separator "13. Disk Space"
df -h /opt/tomcat

separator "14. Recent System Logs for Tomcat"
journalctl -u tomcat --no-pager -n 50

separator "END OF DIAGNOSTIC REPORT"
echo ""
echo "========================================"
echo "Diagnostic complete!"
echo "Log saved to: ${LOG_FILE}"
echo "========================================"
echo ""
echo -e "${YELLOW}To share this log, run:${NC}"
echo -e "${GREEN}cat ${LOG_FILE}${NC}"
