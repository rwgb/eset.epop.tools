-- ESET Protect MySQL Initialization Script

-- Create database if not exists (Docker already creates it, but for safety)
CREATE DATABASE IF NOT EXISTS era CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Ensure root user uses mysql_native_password for ODBC compatibility
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';

-- Grant privileges
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON era.* TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
