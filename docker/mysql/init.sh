#!/bin/bash
# ESET Protect MySQL Initialization Script

set -e

echo "Running ESET Protect MySQL initialization..."

# Wait for MySQL to be ready
until mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

# Run initialization SQL
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
-- Create database if not exists (Docker already creates it, but for safety)
CREATE DATABASE IF NOT EXISTS era CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Ensure root user uses mysql_native_password for ODBC compatibility
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';

-- Ensure the non-root user also uses mysql_native_password
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PASSWORD}';

-- Grant privileges
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON era.* TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
EOF

echo "MySQL initialization completed successfully!"
