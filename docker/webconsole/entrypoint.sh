#!/bin/bash
set -e

GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_info "Waiting for ESET Server to be ready..."
# Wait for ESET server to be available
until curl -k -s https://${ESET_SERVER_HOST}:${ESET_SERVER_PORT} > /dev/null 2>&1; do
    log_info "ESET Server is unavailable - sleeping"
    sleep 10
done
log_info "ESET Server is ready"

log_info "Starting Tomcat Web Console..."
exec "$@"
