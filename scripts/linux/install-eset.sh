#!/usr/bin/bash

#######################################
# ESET Protect On-Prem Installation Script
# For Ubuntu 24.04 LTS
#######################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Static Configuration
ODBC_VERSION="8.0.40"
ODBC_URL="https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-${ODBC_VERSION}-linux-glibc2.28-x86-64bit.tar.gz"
ESET_INSTALLER_URL="https://download.eset.com/com/eset/apps/business/era/server/linux/latest/server_linux_x86_64.sh"
ESET_WEBCONSOLE_URL="https://download.eset.com/com/eset/apps/business/era/webconsole/latest/era_x64.war"
TOMCAT_VERSION="9.0.85"
TOMCAT_DOWNLOAD_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

# User-configured variables (will be set by prompts)
MYSQL_ROOT_PASSWORD=""
ESET_ADMIN_PASSWORD=""
DB_USER_USERNAME=""
DB_USER_PASSWORD=""

# OS Detection variables
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""
JAVA_HOME_PATH=""

# Logging setup
LOG_DIR="/var/log/eset-install"
LOG_FILE="${LOG_DIR}/installation-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#######################################
# Logging Functions
#######################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

log_step() {
    echo "" | tee -a "${LOG_FILE}"
    echo "========================================" | tee -a "${LOG_FILE}"
    echo -e "${GREEN}STEP: $*${NC}" | tee -a "${LOG_FILE}"
    echo "========================================" | tee -a "${LOG_FILE}"
}

error_exit() {
    log_error "$1"
    log_error "Installation failed. Check log: ${LOG_FILE}"
    exit 1
}

#######################################
# User Input Functions
#######################################

prompt_credentials() {
    log_step "Configuration Setup"
    
    echo -e "${YELLOW}Please provide the following configuration details:${NC}"
    echo ""
    
    # MySQL Root Password
    while [[ -z "${MYSQL_ROOT_PASSWORD}" ]]; do
        read -sp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
        echo ""
        if [[ -z "${MYSQL_ROOT_PASSWORD}" ]]; then
            echo -e "${RED}Password cannot be empty${NC}"
        else
            read -sp "Confirm MySQL root password: " MYSQL_ROOT_PASSWORD_CONFIRM
            echo ""
            if [[ "${MYSQL_ROOT_PASSWORD}" != "${MYSQL_ROOT_PASSWORD_CONFIRM}" ]]; then
                echo -e "${RED}Passwords do not match${NC}"
                MYSQL_ROOT_PASSWORD=""
            fi
        fi
    done
    log_info "MySQL root password set"
    
    # ESET Admin Password
    while [[ -z "${ESET_ADMIN_PASSWORD}" ]]; do
        read -sp "Enter ESET Protect administrator password: " ESET_ADMIN_PASSWORD
        echo ""
        if [[ -z "${ESET_ADMIN_PASSWORD}" ]]; then
            echo -e "${RED}Password cannot be empty${NC}"
        else
            read -sp "Confirm ESET administrator password: " ESET_ADMIN_PASSWORD_CONFIRM
            echo ""
            if [[ "${ESET_ADMIN_PASSWORD}" != "${ESET_ADMIN_PASSWORD_CONFIRM}" ]]; then
                echo -e "${RED}Passwords do not match${NC}"
                ESET_ADMIN_PASSWORD=""
            fi
        fi
    done
    log_info "ESET administrator password set"
    
    # Database User Username
    while [[ -z "${DB_USER_USERNAME}" ]]; do
        read -p "Enter ESET database username [era_user]: " DB_USER_USERNAME
        DB_USER_USERNAME=${DB_USER_USERNAME:-era_user}
        if [[ ! "${DB_USER_USERNAME}" =~ ^[a-zA-Z0-9_]+$ ]]; then
            echo -e "${RED}Username must contain only alphanumeric characters and underscores${NC}"
            DB_USER_USERNAME=""
        fi
    done
    log_info "Database username set to: ${DB_USER_USERNAME}"
    
    # Database User Password
    while [[ -z "${DB_USER_PASSWORD}" ]]; do
        read -sp "Enter ESET database user password: " DB_USER_PASSWORD
        echo ""
        if [[ -z "${DB_USER_PASSWORD}" ]]; then
            echo -e "${RED}Password cannot be empty${NC}"
        else
            read -sp "Confirm ESET database user password: " DB_USER_PASSWORD_CONFIRM
            echo ""
            if [[ "${DB_USER_PASSWORD}" != "${DB_USER_PASSWORD_CONFIRM}" ]]; then
                echo -e "${RED}Passwords do not match${NC}"
                DB_USER_PASSWORD=""
            fi
        fi
    done
    log_info "Database user password set"
    
    echo ""
    echo -e "${GREEN}Configuration complete!${NC}"
    echo ""
}

#######################################
# Prerequisite Checks
#######################################

check_root() {
    log_step "Checking root privileges"
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root"
    fi
    log_info "Root privileges confirmed"
}

check_os() {
    log_step "Detecting operating system"
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Cannot detect OS version. /etc/os-release not found."
    fi
    
    source /etc/os-release
    log_info "Detected OS: ${NAME} ${VERSION}"
    
    # Determine OS type and package manager
    case "${ID}" in
        ubuntu|debian)
            OS_TYPE="debian"
            PKG_MANAGER="apt-get"
            log_info "OS Family: Debian/Ubuntu"
            ;;
        rhel|centos|rocky|almalinux)
            OS_TYPE="rhel"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            log_info "OS Family: RHEL/CentOS/Rocky/AlmaLinux"
            log_info "Package Manager: ${PKG_MANAGER}"
            ;;
        fedora)
            OS_TYPE="fedora"
            PKG_MANAGER="dnf"
            log_info "OS Family: Fedora"
            ;;
        *)
            log_warn "OS '${ID}' is not officially tested. Attempting to continue with best guess..."
            # Default to apt-get for Debian-like systems
            if command -v apt-get &> /dev/null; then
                OS_TYPE="debian"
                PKG_MANAGER="apt-get"
            elif command -v dnf &> /dev/null; then
                OS_TYPE="rhel"
                PKG_MANAGER="dnf"
            elif command -v yum &> /dev/null; then
                OS_TYPE="rhel"
                PKG_MANAGER="yum"
            else
                error_exit "Cannot determine package manager for OS: ${ID}"
            fi
            ;;
    esac
    
    # Export for potential use in external scripts
    export OS_VERSION="${VERSION_ID}"
    
    # Detect Java home path
    detect_java_home
}

detect_java_home() {
    log_info "Detecting Java installation path"
    
    # Common Java paths for different distributions
    local java_paths=(
        "/usr/lib/jvm/java-11-openjdk-amd64"
        "/usr/lib/jvm/java-11-openjdk"
        "/usr/lib/jvm/jre-11-openjdk"
        "/usr/lib/jvm/java-11"
        "/usr/lib/jvm/java-1.11.0-openjdk"
        "/usr/lib/jvm/jre-11"
    )
    
    for path in "${java_paths[@]}"; do
        if [[ -d "$path" ]]; then
            JAVA_HOME_PATH="$path"
            log_info "Java home set to: ${JAVA_HOME_PATH}"
            return 0
        fi
    done
    
    # If not found in common paths, try to detect from java command
    if command -v java &> /dev/null; then
        local java_exec
        java_exec=$(command -v java)
        JAVA_HOME_PATH=$(dirname "$(dirname "$(readlink -f "$java_exec")")") 
        log_info "Java home detected from command: ${JAVA_HOME_PATH}"
        return 0
    fi
    
    log_warn "Could not detect Java home path. Will be set after Java installation."
}

cleanup_mysql_repo() {
    log_step "Cleaning up conflicting MySQL repositories"
    
    case "${OS_TYPE}" in
        debian)
            # Remove MySQL APT configuration if it exists
            if [[ -f /etc/apt/sources.list.d/mysql.list ]]; then
                log_info "Removing MySQL APT repository configuration"
                rm -f /etc/apt/sources.list.d/mysql.list
            fi
            
            # Remove MySQL APT config package if installed
            if dpkg -l | grep -q mysql-apt-config; then
                log_info "Removing mysql-apt-config package"
                apt-get purge -y mysql-apt-config >> "${LOG_FILE}" 2>&1 || true
            fi
            
            # Remove downloaded MySQL APT config files
            for file in /tmp/mysql-apt-config*.deb; do
                if [[ -f "$file" ]]; then
                    rm -f "$file"
                fi
            done
            ;;
        rhel|fedora)
            # Remove MySQL repository if it exists
            if [[ -f /etc/yum.repos.d/mysql-community.repo ]]; then
                log_info "Removing MySQL community repository"
                rm -f /etc/yum.repos.d/mysql-community.repo
            fi
            ;;
    esac
    
    log_info "MySQL repository cleanup complete"
}

#######################################
# Installation Steps
#######################################

step1_update_packages() {
    log_step "Step 1: Updating system packages"
    
    case "${OS_TYPE}" in
        debian)
            if apt -y update >> "${LOG_FILE}" 2>&1; then
                log_info "Package lists updated"
            else
                error_exit "Failed to update package lists"
            fi
            
            if apt -y upgrade >> "${LOG_FILE}" 2>&1; then
                log_info "System packages upgraded"
            else
                log_warn "Package upgrade had issues, continuing..."
            fi
            ;;
        rhel|fedora)
            if ${PKG_MANAGER} -y update >> "${LOG_FILE}" 2>&1; then
                log_info "System packages updated"
            else
                log_warn "Package update had issues, continuing..."
            fi
            ;;
    esac
}

step2_install_dependencies() {
    log_step "Step 2: Installing required dependencies"
    
    local packages=()
    
    case "${OS_TYPE}" in
        debian)
            packages=(
                "xvfb"
                "xauth"
                "cifs-utils"
                "krb5-user"
                "ldap-utils"
                "snmp"
                "lshw"
                "openssl"
                "mysql-server"
                "unixodbc"
                "odbcinst"
                "openjdk-11-jdk"
                "wget"
                "tar"
            )
            
            log_info "Installing: ${packages[*]}"
            
            if DEBIAN_FRONTEND=noninteractive ${PKG_MANAGER} install -y "${packages[@]}" >> "${LOG_FILE}" 2>&1; then
                log_info "All dependencies installed successfully"
            else
                error_exit "Failed to install dependencies"
            fi
            ;;
        rhel|fedora)
            packages=(
                "xorg-x11-server-Xvfb"
                "xorg-x11-xauth"
                "cifs-utils"
                "krb5-workstation"
                "openldap-clients"
                "net-snmp-utils"
                "lshw"
                "openssl"
                "mysql-server"
                "unixODBC"
                "java-11-openjdk"
                "java-11-openjdk-devel"
                "wget"
                "tar"
            )
            
            log_info "Installing: ${packages[*]}"
            
            if ${PKG_MANAGER} install -y "${packages[@]}" >> "${LOG_FILE}" 2>&1; then
                log_info "All dependencies installed successfully"
            else
                error_exit "Failed to install dependencies"
            fi
            ;;
    esac
    
    # Re-detect Java home after installation
    detect_java_home
    
    # Verify Java installation
    if java -version >> "${LOG_FILE}" 2>&1; then
        log_info "Java installed: $(java -version 2>&1 | head -n 1)"
    else
        error_exit "Java installation verification failed"
    fi
}

step3_configure_mysql() {
    log_step "Step 3: Configuring MySQL"
    
    local mysql_config="/etc/mysql/my.cnf"
    
    # Backup original config
    if [[ -f "${mysql_config}" ]]; then
        cp "${mysql_config}" "${mysql_config}.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backed up MySQL configuration"
    fi
    
    # Check if configuration already exists
    if grep -q "ESET Protect Configuration" "${mysql_config}" 2>/dev/null; then
        log_warn "MySQL configuration already appears to be set, skipping"
        return 0
    fi
    
    # Add configuration
    cat >> "${mysql_config}" <<EOF

# ESET Protect Configuration
[mysqld]
max_allowed_packet=33M
log_bin_trust_function_creators=1
innodb_log_file_size=100M
innodb_log_files_in_group=2
EOF
    
    log_info "MySQL configuration updated"
}

step4_restart_mysql() {
    log_step "Step 4: Restarting MySQL service"
    
    local mysql_service="mysql"
    
    # RHEL/CentOS may use mysqld instead of mysql
    if [[ "${OS_TYPE}" =~ ^(rhel|fedora)$ ]]; then
        if systemctl list-unit-files | grep -q "mysqld.service"; then
            mysql_service="mysqld"
        fi
    fi
    
    if systemctl restart ${mysql_service} >> "${LOG_FILE}" 2>&1; then
        log_info "MySQL service (${mysql_service}) restarted"
    else
        error_exit "Failed to restart MySQL service"
    fi
    
    # Wait for MySQL to be ready
    sleep 3
    
    if systemctl is-active --quiet ${mysql_service}; then
        log_info "MySQL service is running"
    else
        error_exit "MySQL service is not running"
    fi
}

step5_secure_mysql() {
    log_step "Step 5: Securing MySQL installation"
    
    log_info "Setting MySQL root password and securing installation"
    
    # Check if root already has a password
    if ! mysql -u root -e "SELECT 1;" >> "${LOG_FILE}" 2>&1; then
        log_info "MySQL root already has a password set"
        
        # Test if it's the configured password
        if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >> "${LOG_FILE}" 2>&1; then
            log_info "MySQL is already secured with the configured password"
            
            # Still run cleanup commands to ensure fully secured
            mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF >> "${LOG_FILE}" 2>&1
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
            log_info "MySQL security verified"
            return 0
        else
            error_exit "MySQL root has a password, but it's not the configured password. Please update MYSQL_ROOT_PASSWORD in the script or reset MySQL root password manually."
        fi
    fi
    
    # Fresh install - set password and secure
    log_info "Configuring MySQL security for fresh installation"
    
    # Execute MySQL security commands
    if mysql -u root <<EOF >> "${LOG_FILE}" 2>&1
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    then
        log_info "MySQL secured successfully"
    else
        error_exit "Failed to secure MySQL"
    fi
    
    # Test connection with new password
    if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >> "${LOG_FILE}" 2>&1; then
        log_info "MySQL root authentication verified"
    else
        error_exit "Cannot authenticate to MySQL with configured password"
    fi
}

step6_install_odbc_connector() {
    log_step "Step 6: Installing MySQL ODBC Connector"
    
    local work_dir="/tmp/odbc-install-$$"
    mkdir -p "${work_dir}"
    cd "${work_dir}"
    
    local odbc_file="mysql-connector-odbc-${ODBC_VERSION}-linux-glibc2.28-x86-64bit.tar.gz"
    local odbc_dir="${odbc_file%.tar.gz}"
    
    # Download ODBC connector
    log_info "Downloading ODBC connector version ${ODBC_VERSION}"
    if wget -q "${ODBC_URL}" >> "${LOG_FILE}" 2>&1; then
        log_info "ODBC connector downloaded"
    else
        error_exit "Failed to download ODBC connector from ${ODBC_URL}"
    fi
    
    # Extract
    log_info "Extracting ODBC connector"
    if tar xzf "${odbc_file}" >> "${LOG_FILE}" 2>&1; then
        log_info "ODBC connector extracted"
    else
        error_exit "Failed to extract ODBC connector"
    fi
    
    cd "${odbc_dir}"
    
    # Copy binaries and libraries
    log_info "Installing ODBC binaries and libraries"
    cp -r bin/* /usr/local/bin/ 2>/dev/null || cp bin/* /usr/local/bin/
    cp -r lib/* /usr/local/lib/ 2>/dev/null || true
    
    # Copy individual library files (skip directories)
    find lib -maxdepth 1 -type f -exec cp {} /usr/local/lib/ \;
    
    # Configure library path
    echo "/usr/local/lib" > /etc/ld.so.conf.d/mysql-odbc.conf
    ldconfig >> "${LOG_FILE}" 2>&1
    
    # Verify libraries are loaded
    if ldconfig -p | grep -q myodbc; then
        log_info "ODBC libraries loaded successfully"
    else
        error_exit "ODBC libraries not found in library cache"
    fi
    
    # Register ODBC drivers
    log_info "Registering ODBC drivers"
    
    myodbc-installer -a -d -n "MySQL ODBC 8.0 Driver" \
        -t "Driver=/usr/local/lib/libmyodbc8w.so" >> "${LOG_FILE}" 2>&1
    
    myodbc-installer -a -d -n "MySQL ODBC 8.0" \
        -t "Driver=/usr/local/lib/libmyodbc8a.so" >> "${LOG_FILE}" 2>&1
    
    # List registered drivers
    log_info "Registered ODBC drivers:"
    myodbc-installer -d -l | tee -a "${LOG_FILE}"
    
    # Verify driver registration
    if odbcinst -q -d | grep -q "MySQL ODBC 8.0 Driver"; then
        log_info "ODBC driver 'MySQL ODBC 8.0 Driver' registered successfully"
    else
        error_exit "ODBC driver registration failed"
    fi
    
    # Cleanup
    cd /
    rm -rf "${work_dir}"
}

step7_download_eset_installer() {
    log_step "Step 7: Downloading ESET Protect installer"
    
    local installer_path="/tmp/server_linux_x86_64.sh"
    
    # Remove old installer if exists
    [[ -f "${installer_path}" ]] && rm -f "${installer_path}"
    
    log_info "Downloading ESET Protect installer"
    if wget -O "${installer_path}" "${ESET_INSTALLER_URL}" >> "${LOG_FILE}" 2>&1; then
        log_info "ESET installer downloaded"
    else
        error_exit "Failed to download ESET installer from ${ESET_INSTALLER_URL}"
    fi
    
    # Make executable
    chmod +x "${installer_path}"
    
    log_info "Installer ready at: ${installer_path}"
}

step8_install_eset_protect() {
    log_step "Step 8: Installing ESET Protect On-Prem"
    
    local installer_path="/tmp/server_linux_x86_64.sh"
    
    if [[ ! -f "${installer_path}" ]]; then
        error_exit "ESET installer not found at ${installer_path}"
    fi
    
    log_info "Running ESET Protect installation"
    log_info "This may take several minutes..."
    
    if "${installer_path}" \
        --skip-license \
        --db-type="MySQL Server" \
        --db-driver="MySQL ODBC 8.0 Driver" \
        --db-hostname=localhost \
        --db-port=3306 \
        --db-admin-username=root \
        --db-admin-password="${MYSQL_ROOT_PASSWORD}" \
        --server-root-password="${ESET_ADMIN_PASSWORD}" \
        --db-user-username="${DB_USER_USERNAME}" \
        --db-user-password="${DB_USER_PASSWORD}" \
        --cert-hostname="*" >> "${LOG_FILE}" 2>&1
    then
        log_info "ESET Protect installed successfully"
    else
        log_error "ESET installation failed"
        log_error "Check ESET installer log: /var/log/eset/RemoteAdministrator/EraServerInstaller.log"
        error_exit "ESET Protect installation failed"
    fi
}

step9_verify_installation() {
    log_step "Step 9: Verifying installation"
    
    # Check ESET service
    log_info "Checking ESET service status"
    
    sleep 5  # Wait for service to start
    
    if systemctl is-active --quiet eraserver 2>/dev/null; then
        log_info "ESET server service is running"
    else
        log_warn "ESET server service is not running, attempting to start"
        if systemctl start eraserver >> "${LOG_FILE}" 2>&1; then
            log_info "ESET server service started"
        else
            log_error "Failed to start ESET server service"
        fi
    fi
    
    # Check installation log
    if [[ -f /var/log/eset/RemoteAdministrator/EraServerInstaller.log ]]; then
        if grep -q "Error:" /var/log/eset/RemoteAdministrator/EraServerInstaller.log; then
            log_warn "Errors found in ESET installer log"
            log_warn "Review: /var/log/eset/RemoteAdministrator/EraServerInstaller.log"
        fi
    fi
    
    log_info "Installation verification complete"
}

step10_install_tomcat() {
    log_step "Step 10: Installing Apache Tomcat 9"
    
    # Check if Tomcat 10 is installed (wrong version) and remove it
    if [[ -d /opt/tomcat ]] && grep -q "10.1.20" /opt/tomcat/RELEASE-NOTES 2>/dev/null; then
        log_warn "Tomcat 10 detected - removing (incompatible with ESET Web Console)"
        systemctl stop tomcat 2>/dev/null || true
        systemctl disable tomcat 2>/dev/null || true
        rm -rf /opt/tomcat
        log_info "Tomcat 10 removed"
    fi
    
    # Check if correct Tomcat version is already installed
    if [[ -d /opt/tomcat ]]; then
        if grep -q "Apache Tomcat/9" /opt/tomcat/RELEASE-NOTES 2>/dev/null; then
            log_info "Tomcat 9 already installed"
            if systemctl is-active --quiet tomcat 2>/dev/null; then
                log_info "Tomcat service is already running"
                return 0
            fi
        else
            log_warn "Unknown Tomcat version found, removing"
            systemctl stop tomcat 2>/dev/null || true
            rm -rf /opt/tomcat
        fi
    fi
    
    # Create tomcat user if doesn't exist
    if ! id -u tomcat >/dev/null 2>&1; then
        log_info "Creating tomcat user"
        useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat >> "${LOG_FILE}" 2>&1
    else
        log_info "Tomcat user already exists"
    fi
    
    # Download Tomcat 9
    local work_dir="/tmp/tomcat-install-$$"
    mkdir -p "${work_dir}"
    cd "${work_dir}"
    
    log_info "Downloading Apache Tomcat ${TOMCAT_VERSION}"
    if wget -q "${TOMCAT_DOWNLOAD_URL}" >> "${LOG_FILE}" 2>&1; then
        log_info "Tomcat 9 downloaded"
    else
        # Try alternative mirror
        log_warn "Primary mirror failed, trying archive mirror"
        TOMCAT_DOWNLOAD_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
        if wget -q "${TOMCAT_DOWNLOAD_URL}" >> "${LOG_FILE}" 2>&1; then
            log_info "Tomcat 9 downloaded from archive"
        else
            error_exit "Failed to download Tomcat 9"
        fi
    fi
    
    # Extract Tomcat
    log_info "Extracting Tomcat 9"
    tar xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz" >> "${LOG_FILE}" 2>&1
    
    # Install to /opt/tomcat
    log_info "Installing Tomcat 9 to /opt/tomcat"
    rm -rf /opt/tomcat
    mv "apache-tomcat-${TOMCAT_VERSION}" /opt/tomcat
    
    # Set ownership
    chown -R tomcat:tomcat /opt/tomcat
    chmod -R u+x /opt/tomcat/bin
    
    # Create systemd service
    log_info "Creating Tomcat systemd service"
    cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=${JAVA_HOME_PATH}"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"

Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload >> "${LOG_FILE}" 2>&1
    
    # Enable and start Tomcat
    log_info "Starting Tomcat 9 service"
    if systemctl enable tomcat >> "${LOG_FILE}" 2>&1; then
        log_info "Tomcat service enabled"
    fi
    
    if systemctl start tomcat >> "${LOG_FILE}" 2>&1; then
        log_info "Tomcat service started"
    else
        error_exit "Failed to start Tomcat service"
    fi
    
    # Wait for Tomcat to start
    sleep 10
    
    # Verify Tomcat is running
    if systemctl is-active --quiet tomcat; then
        log_info "Tomcat 9 is running on port 8080"
        log_info "Version: Apache Tomcat 9 (Java EE compatible)"
    else
        error_exit "Tomcat service failed to start"
    fi
    
    # Cleanup
    cd /
    rm -rf "${work_dir}"
}

step11_install_webconsole() {
    log_step "Step 11: Installing ESET Protect Web Console"
    
    local war_path="/opt/tomcat/webapps/era.war"
    
    # Stop Tomcat before deploying
    log_info "Stopping Tomcat for clean deployment"
    systemctl stop tomcat >> "${LOG_FILE}" 2>&1
    sleep 3
    
    # Remove old deployment if exists
    rm -rf /opt/tomcat/webapps/era
    rm -rf /opt/tomcat/webapps/era.war
    
    # Download ESET Web Console WAR file
    log_info "Downloading ESET Protect Web Console"
    if wget -O "${war_path}" "${ESET_WEBCONSOLE_URL}" >> "${LOG_FILE}" 2>&1; then
        log_info "Web Console WAR file downloaded"
    else
        error_exit "Failed to download ESET Web Console from ${ESET_WEBCONSOLE_URL}"
    fi
    
    # Verify download
    if [[ ! -f "${war_path}" ]]; then
        error_exit "WAR file not found after download"
    fi
    
    local file_size
    file_size=$(stat -f%z "${war_path}" 2>/dev/null || stat -c%s "${war_path}" 2>/dev/null)
    log_info "WAR file size: ${file_size} bytes"
    
    if [[ ${file_size} -lt 1000000 ]]; then
        log_error "WAR file seems too small (${file_size} bytes), may be corrupted"
        cat "${war_path}" | head -n 20 >> "${LOG_FILE}"
        error_exit "Downloaded WAR file appears to be invalid"
    fi
    
    # Set ownership
    chown tomcat:tomcat "${war_path}"
    chmod 644 "${war_path}"
    
    # Start Tomcat
    log_info "Starting Tomcat for WAR deployment"
    systemctl start tomcat >> "${LOG_FILE}" 2>&1
    sleep 5
    
    log_info "Waiting for Tomcat to deploy the web application..."
    
    # Wait up to 120 seconds for deployment
    local count=0
    local max_wait=120
    while [[ ! -d /opt/tomcat/webapps/era ]] && [[ $count -lt $max_wait ]]; do
        sleep 5
        ((count+=5))
        if [[ $((count % 15)) -eq 0 ]]; then
            log_info "Still waiting for deployment... ${count}s / ${max_wait}s"
            
            # Check if Tomcat is still running
            if ! systemctl is-active --quiet tomcat; then
                log_error "Tomcat stopped unexpectedly during deployment"
                log_error "Last 50 lines of catalina.out:"
                tail -n 50 /opt/tomcat/logs/catalina.out >> "${LOG_FILE}"
                error_exit "Tomcat crashed during web console deployment"
            fi
        fi
    done
    
    # Check if WAR was deployed
    if [[ -d /opt/tomcat/webapps/era ]]; then
        log_info "Web Console deployed successfully"
        
        # Verify key files exist
        if [[ -f /opt/tomcat/webapps/era/WEB-INF/web.xml ]]; then
            log_info "Deployment structure verified (web.xml found)"
        else
            log_warn "Deployment may be incomplete - web.xml not found"
        fi
    else
        log_error "Web Console directory not found after ${max_wait} seconds"
        log_error "Checking Tomcat logs for errors..."
        
        # Show relevant log sections
        echo "=== Last 100 lines of catalina.out ===" >> "${LOG_FILE}"
        tail -n 100 /opt/tomcat/logs/catalina.out >> "${LOG_FILE}"
        
        local today
        today=$(date +%Y-%m-%d)
        if [[ -f "/opt/tomcat/logs/localhost.${today}.log" ]]; then
            echo "=== Localhost log ===" >> "${LOG_FILE}"
            tail -n 50 "/opt/tomcat/logs/localhost.${today}.log" >> "${LOG_FILE}"
        fi
        
        log_error "Check full Tomcat logs at: /opt/tomcat/logs/"
        log_error "WAR file location: ${war_path}"
        log_error "Expected deployment dir: /opt/tomcat/webapps/era"
        
        # Check if WAR file still exists (might have been deleted after failed deployment)
        if [[ -f "${war_path}" ]]; then
            log_error "WAR file still exists - deployment may have failed"
        else
            log_error "WAR file was removed - check if it was corrupted"
        fi
        
        error_exit "Web Console deployment failed - check logs above"
    fi
    
    # Give it a moment to fully initialize
    sleep 5
}

step12_configure_https() {
    log_step "Step 12: Configuring HTTPS for Tomcat"
    
    local keystore_path="/opt/tomcat/conf/keystore.jks"
    local keystore_password="changeit"
    local server_hostname
    server_hostname=$(hostname -I | awk '{print $1}')
    
    # Generate self-signed certificate
    log_info "Generating self-signed SSL certificate"
    
    if keytool -genkey -noprompt \
        -alias tomcat \
        -dname "CN=${server_hostname}, OU=IT, O=ESET, L=City, S=State, C=US" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 365 \
        -keystore "${keystore_path}" \
        -storepass "${keystore_password}" \
        -keypass "${keystore_password}" >> "${LOG_FILE}" 2>&1; then
        log_info "SSL certificate generated"
    else
        error_exit "Failed to generate SSL certificate"
    fi
    
    # Set ownership
    chown tomcat:tomcat "${keystore_path}"
    chmod 600 "${keystore_path}"
    
    # Backup original server.xml
    cp /opt/tomcat/conf/server.xml /opt/tomcat/conf/server.xml.backup
    
    # Configure HTTPS connector in server.xml
    log_info "Configuring HTTPS connector in Tomcat"
    
    # Remove existing HTTPS connector if present
    sed -i '/<Connector port="8443"/,/<\/Connector>/d' /opt/tomcat/conf/server.xml
    
    # Add HTTPS connector before the closing </Service> tag
    sed -i '/<\/Service>/i \
    <!-- HTTPS Connector -->\
    <Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"\
               maxThreads="150" SSLEnabled="true">\
        <SSLHostConfig>\
            <Certificate certificateKeystoreFile="conf/keystore.jks"\
                         certificateKeystorePassword="changeit"\
                         type="RSA" />\
        </SSLHostConfig>\
    </Connector>' /opt/tomcat/conf/server.xml
    
    # Also redirect HTTP to HTTPS for the era application
    log_info "Configuring HTTP to HTTPS redirect"
    
    # Create web.xml override if it doesn't exist
    mkdir -p /opt/tomcat/webapps/era/WEB-INF
    
    # Add security constraint to force HTTPS (will be applied after deployment)
    cat > /opt/tomcat/conf/Catalina/localhost/era.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context path="/era">
    <!-- Force HTTPS -->
</Context>
EOF
    
    chown -R tomcat:tomcat /opt/tomcat/conf/Catalina
    
    # Restart Tomcat to apply changes
    log_info "Restarting Tomcat to apply HTTPS configuration"
    systemctl restart tomcat >> "${LOG_FILE}" 2>&1
    
    sleep 10
    
    if systemctl is-active --quiet tomcat; then
        log_info "Tomcat restarted successfully with HTTPS enabled"
        log_info "HTTPS available on port 8443"
    else
        error_exit "Tomcat failed to restart after HTTPS configuration"
    fi
}

#######################################
# Post-Installation Information
#######################################

display_summary() {
    log_step "Installation Summary"
    
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')
    
    cat <<EOF | tee -a "${LOG_FILE}"

${GREEN}╔════════════════════════════════════════════════════════════════╗
║         ESET Protect On-Prem Installation Complete            ║
╚════════════════════════════════════════════════════════════════╝${NC}

${GREEN}Installation Details:${NC}
  - Installation Log: ${LOG_FILE}
  - ESET Log: /var/log/eset/RemoteAdministrator/EraServerInstaller.log
  
${GREEN}Access Information:${NC}
  - Server Web Console: https://${server_ip}:2223
  - Web Console (HTTPS): https://${server_ip}:8443/era
  - Web Console (HTTP):  http://${server_ip}:8080/era
  - Username: Administrator
  - Password: ${ESET_ADMIN_PASSWORD}

${YELLOW}Note:${NC} The HTTPS certificate is self-signed. Your browser will show a security warning.
      You can safely proceed by accepting the certificate.

${GREEN}Database Configuration:${NC}
  - MySQL Root Password: ${MYSQL_ROOT_PASSWORD}
  - ESET DB User: ${DB_USER_USERNAME}
  - ESET DB Password: ${DB_USER_PASSWORD}

${GREEN}Service Management:${NC}
  - ESET Server: 
    * Check status: systemctl status eraserver
    * View logs: journalctl -u eraserver -f
    * Restart: systemctl restart eraserver
  - Tomcat:
    * Check status: systemctl status tomcat
    * View logs: tail -f /opt/tomcat/logs/catalina.out
    * Restart: systemctl restart tomcat

${GREEN}SSL Certificate:${NC}
  - Keystore: /opt/tomcat/conf/keystore.jks
  - Password: changeit
  - To replace with proper certificate, use keytool to import your cert

${GREEN}Next Steps:${NC}
  1. Access the web console using HTTPS URL: https://${server_ip}:8443/era
  2. Accept the self-signed certificate warning in your browser
  3. Complete initial setup wizard
  4. Configure firewall if needed:
     - ufw allow 2223/tcp  (ESET Web Console)
     - ufw allow 2222/tcp  (ESET Server Port)
     - ufw allow 8443/tcp  (Tomcat HTTPS)
     - ufw allow 8080/tcp  (Tomcat HTTP - optional)
  5. Deploy ESET agents to client machines

${YELLOW}Security Reminder:${NC}
  - Change default passwords immediately
  - Replace self-signed certificate with proper SSL certificate
  - Configure firewall rules
  - Set up regular database backups
  - Consider disabling HTTP port 8080 after testing

EOF
}

#######################################
# Main Execution
#######################################

main() {
    log_info "ESET Protect On-Prem Installation Started"
    log_info "Log file: ${LOG_FILE}"
    
    check_root
    check_os
    prompt_credentials
    cleanup_mysql_repo
    
    step1_update_packages
    step2_install_dependencies
    step3_configure_mysql
    step4_restart_mysql
    step5_secure_mysql
    step6_install_odbc_connector
    step7_download_eset_installer
    step8_install_eset_protect
    step9_verify_installation
    step10_install_tomcat
    step11_install_webconsole
    step12_configure_https
    
    display_summary
    
    log_info "Installation completed successfully!"
}

# Run main function
main "$@"