#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Wait for MySQL to be ready
log_info "Waiting for MySQL to be ready..."
until mysql -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; do
    log_info "MySQL is unavailable - sleeping"
    sleep 5
done
log_info "MySQL is ready"

# Check if ESET is already installed
if [ -f "/var/opt/eset/RemoteAdministrator/.installed" ]; then
    log_info "ESET Protect already installed, skipping installation"
else
    log_info "Installing ESET Protect On-Prem..."
    
    # Run ESET installer
    /opt/eset/installers/server_linux_x86_64.sh \
        --skip-license \
        --db-type="MySQL Server" \
        --db-driver="MySQL ODBC 8.0 Driver" \
        --db-hostname="${MYSQL_HOST}" \
        --db-port="${MYSQL_PORT}" \
        --db-admin-username=root \
        --db-admin-password="${MYSQL_ROOT_PASSWORD}" \
        --server-root-password="${ESET_ADMIN_PASSWORD}" \
        --db-user-username="${DB_USER_USERNAME}" \
        --db-user-password="${DB_USER_PASSWORD}" \
        --cert-hostname="*" \
        || log_error "ESET installation failed, but continuing..."
    
    # Mark installation as complete
    touch /var/opt/eset/RemoteAdministrator/.installed
    log_info "ESET Protect installation completed"
fi

# Find ESET server executable
ESET_SERVER_BIN=""
for path in /opt/eset/RemoteAdministrator/Server/ERAServer \
            /usr/local/bin/ERAServer \
            /opt/eset/eraagent/Server/ERAServer; do
    if [ -x "$path" ]; then
        ESET_SERVER_BIN="$path"
        break
    fi
done

if [ -z "$ESET_SERVER_BIN" ]; then
    log_error "ESET Server executable not found"
    exit 1
fi

log_info "ESET Server executable found at: $ESET_SERVER_BIN"
export ESET_SERVER_BIN

# Execute the main command
log_info "Starting ESET Protect services..."
exec "$@"
