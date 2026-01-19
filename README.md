# ESET Protect On-Prem Installation Guide

## Quick Start (Automated Installation)

The automated installation script supports multiple Linux distributions and handles all installation steps automatically.

### Using the Automated Script

```bash
# Download the installation script
wget https://raw.githubusercontent.com/your-repo/eset-protect/main/scripts/install-eset.sh

# Make it executable
chmod +x install-eset.sh

# Run the installer (will prompt for credentials)
./install-eset.sh
```

The script will:
- Detect your Linux distribution automatically
- Prompt for MySQL root password
- Prompt for ESET administrator password
- Prompt for database credentials
- Install all dependencies
- Configure MySQL
- Install ODBC connectors
- Install ESET Protect server
- Install and configure Apache Tomcat 9
- Deploy the Web Console
- Configure HTTPS with self-signed certificate

### Supported Distributions

- **Ubuntu** 20.04, 22.04, 24.04 LTS
- **Debian** 10, 11, 12
- **RHEL/CentOS/Rocky Linux/AlmaLinux** 8, 9
- **Fedora** 38, 39, 40

---

## Manual Installation

### Ubuntu/Debian Installation

This guide provides step-by-step instructions for installing ESET Protect On-Prem server on Ubuntu/Debian systems.

### Prerequisites

- Ubuntu 20.04+ or Debian 10+ server
- Root or sudo access
- Internet connectivity
- Minimum 4GB RAM, 20GB disk space

### Installation Steps

#### Step 1: Update System Packages

Update your system to ensure all packages are current:

```bash
apt -y update && apt -y upgrade
```

#### Step 2: Install Required Dependencies

Install all prerequisite packages needed for ESET Protect:

```bash
apt-get install -y xvfb xauth cifs-utils krb5-user ldap-utils snmp lshw openssl mysql-server-8.0 unixodbc odbcinst
```

**Package descriptions:**
- `xvfb` - Virtual framebuffer X server
- `xauth` - X authentication utility
- `cifs-utils` - Common Internet File System utilities
- `krb5-user` - Kerberos client tools (kinit, klist)
- `ldap-utils` - LDAP client utilities (ldapsearch)
- `snmp` - SNMP tools (snmptrap)
- `lshw` - Hardware lister
- `openssl` - SSL/TLS toolkit
- `mysql-server-8.0` - MySQL database server
- `unixodbc`, `odbcinst` - ODBC driver manager

#### Step 3: Configure MySQL

Edit the MySQL configuration file to set required parameters:

```bash
nano /etc/mysql/my.cnf
```

Add the following under the `[mysqld]` section:

```ini
[mysqld]
max_allowed_packet=33M
log_bin_trust_function_creators=1
innodb_log_file_size=100M
innodb_log_files_in_group=2
```

Save and exit the editor.

#### Step 4: Restart MySQL Service

Apply the configuration changes:

```bash
systemctl restart mysql
```

Verify MySQL is running:

```bash
systemctl status mysql
```

#### Step 5: Secure MySQL Installation

Configure MySQL root password and remove insecure defaults. Set your desired root password:

```bash
# Set your desired root password
MYSQL_ROOT_PASSWORD="your_secure_password"

# Run MySQL security commands
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
```

**Important:** The `WITH mysql_native_password` clause is required for ODBC compatibility.

#### Step 6: Install MySQL ODBC Connector

Download and install the MySQL ODBC connector compatible with Ubuntu 24.04:

```bash
# Download the connector
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-8.0.40-linux-glibc2.28-x86-64bit.tar.gz

# Extract the archive
tar xzf mysql-connector-odbc-8.0.40-linux-glibc2.28-x86-64bit.tar.gz
cd mysql-connector-odbc-8.0.40-linux-glibc2.28-x86-64bit

# Copy binaries and libraries
cp bin/* /usr/local/bin/
cp lib/* /usr/local/lib/

# Configure library path and update cache
echo "/usr/local/lib" > /etc/ld.so.conf.d/mysql-odbc.conf
ldconfig

# Verify libraries are loaded
ldconfig -p | grep myodbc

# Register ODBC drivers
myodbc-installer -a -d -n "MySQL ODBC 8.0 Driver" -t "Driver=/usr/local/lib/libmyodbc8w.so"
myodbc-installer -a -d -n "MySQL ODBC 8.0" -t "Driver=/usr/local/lib/libmyodbc8a.so"

# List registered drivers
myodbc-installer -d -l
odbcinst -q -d
```

You should see "MySQL ODBC 8.0 Driver" in the output.

#### Step 7: Download ESET Protect Installer

Download the latest ESET Protect On-Prem server installer:

```bash
wget https://download.eset.com/com/eset/apps/business/era/server/linux/latest/server_linux_x86_64.sh
chmod +x server_linux_x86_64.sh
```

#### Step 8: Run the ESET Protect Installation

Create an installation script with your configuration:

```bash
nano install_eset.sh
```

Add the following content (update passwords as needed):

```bash
#!/usr/bin/bash
./server_linux_x86_64.sh \
--skip-license \
--db-type="MySQL Server" \
--db-driver="MySQL ODBC 8.0 Driver" \
--db-hostname=localhost \
--db-port=3306 \
--db-admin-username=root \
--db-admin-password=your_secure_password \
--server-root-password=eset_admin_password \
--db-user-username=era_user \
--db-user-password=era_user_password \
--cert-hostname="*"
```

**Parameter descriptions:**
- `--skip-license` - Skip license acceptance prompt
- `--db-type` - Database type (MySQL Server)
- `--db-driver` - ODBC driver name (must match registered driver)
- `--db-hostname` - MySQL server hostname
- `--db-port` - MySQL server port (default: 3306)
- `--db-admin-username` - MySQL admin user (for database creation)
- `--db-admin-password` - MySQL admin password
- `--server-root-password` - ESET Protect administrator password
- `--db-user-username` - ESET database user to create
- `--db-user-password` - ESET database user password
- `--cert-hostname` - SSL certificate hostname (* for wildcard)

Make the script executable and run it:

```bash
chmod +x install_eset.sh
./install_eset.sh
```

#### Step 9: Verify Installation

Check the installation log for any errors:

```bash
cat /var/log/eset/RemoteAdministrator/EraServerInstaller.log
```

Check the ESET service status:

```bash
systemctl status eraserver
```

#### Step 10: Install Java (Required for Web Console)

Install Java 11 JDK:

```bash
apt-get install -y openjdk-11-jdk
```

Verify installation:

```bash
java -version
```

#### Step 11: Install Apache Tomcat 9

**Note:** Use Tomcat 9, not Tomcat 10. ESET Web Console requires Java EE (javax.servlet), which is only in Tomcat 9.

```bash
# Create tomcat user
useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat

# Download Tomcat 9
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.85/bin/apache-tomcat-9.0.85.tar.gz

# Extract and install
tar xzf apache-tomcat-9.0.85.tar.gz
mv apache-tomcat-9.0.85 /opt/tomcat

# Set ownership
chown -R tomcat:tomcat /opt/tomcat
chmod -R u+x /opt/tomcat/bin
```

Create systemd service:

```bash
cat > /etc/systemd/system/tomcat.service <<'EOF'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
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
```

Start Tomcat:

```bash
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
systemctl status tomcat
```

#### Step 12: Deploy ESET Web Console

Download and deploy the WAR file:

```bash
# Stop Tomcat for clean deployment
systemctl stop tomcat

# Remove any old deployments
rm -rf /opt/tomcat/webapps/era*

# Download Web Console
wget -O /opt/tomcat/webapps/era.war https://download.eset.com/com/eset/apps/business/era/webconsole/latest/era_x64.war

# Set ownership
chown tomcat:tomcat /opt/tomcat/webapps/era.war

# Start Tomcat (will auto-deploy)
systemctl start tomcat

# Wait for deployment (check logs)
tail -f /opt/tomcat/logs/catalina.out
```

Verify deployment:

```bash
ls -la /opt/tomcat/webapps/era/
```

#### Step 13: Configure HTTPS for Web Console

Generate self-signed certificate:

```bash
# Generate keystore
keytool -genkey -noprompt \
  -alias tomcat \
  -dname "CN=$(hostname -I | awk '{print $1}'), OU=IT, O=ESET, L=City, S=State, C=US" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 365 \
  -keystore /opt/tomcat/conf/keystore.jks \
  -storepass changeit \
  -keypass changeit

# Set ownership
chown tomcat:tomcat /opt/tomcat/conf/keystore.jks
chmod 600 /opt/tomcat/conf/keystore.jks
```

Configure HTTPS connector in `/opt/tomcat/conf/server.xml`:

```bash
# Backup original
cp /opt/tomcat/conf/server.xml /opt/tomcat/conf/server.xml.backup

# Add HTTPS connector before </Service> tag
# Insert this configuration manually or use sed
```

Add this connector configuration:

```xml
<!-- HTTPS Connector -->
<Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
           maxThreads="150" SSLEnabled="true">
    <SSLHostConfig>
        <Certificate certificateKeystoreFile="conf/keystore.jks"
                     certificateKeystorePassword="changeit"
                     type="RSA" />
    </SSLHostConfig>
</Connector>
```

Restart Tomcat:

```bash
systemctl restart tomcat
```

#### Step 14: Access the Web Console

Once installation is complete, access the ESET Protect web console:

**HTTPS (Recommended):**
```
https://<server-ip>:8443/era
```

**HTTP:**
```
http://<server-ip>:8080/era
```

**Server Console:**
```
https://<server-ip>:2223
```

Default credentials:
- Username: `Administrator`
- Password: The password you set with `--server-root-password`

**Note:** For HTTPS, your browser will show a security warning because of the self-signed certificate. This is expected - click "Advanced" and "Proceed" to accept it.

---

## RHEL/CentOS/Rocky Linux Installation

For Red Hat-based distributions, the process is similar with different package names.

### Prerequisites

- RHEL/CentOS/Rocky Linux 8 or 9
- Root access
- Internet connectivity

### Package Installation

```bash
# Update system
dnf -y update

# Install dependencies
dnf install -y \
  xorg-x11-server-Xvfb \
  xorg-x11-xauth \
  cifs-utils \
  krb5-workstation \
  openldap-clients \
  net-snmp-utils \
  lshw \
  openssl \
  mysql-server \
  unixODBC \
  java-11-openjdk \
  java-11-openjdk-devel \
  wget \
  tar
```

### MySQL Configuration

```bash
# Start and enable MySQL
systemctl enable mysqld
systemctl start mysqld

# Configure MySQL
cat >> /etc/my.cnf.d/eset.cnf <<EOF
[mysqld]
max_allowed_packet=33M
log_bin_trust_function_creators=1
innodb_log_file_size=100M
innodb_log_files_in_group=2
EOF

# Restart MySQL
systemctl restart mysqld

# Secure MySQL (adjust for mysqld service name)
MYSQL_ROOT_PASSWORD="your_secure_password"

mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
```

### ODBC Connector Installation

The ODBC connector installation is the same as Ubuntu/Debian:

```bash
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-8.0.40-linux-glibc2.28-x86-64bit.tar.gz
tar xzf mysql-connector-odbc-8.0.40-linux-glibc2.28-x86-64bit.tar.gz
cd mysql-connector-odbc-8.0.40-linux-glibc2.28-x86-64bit

cp bin/* /usr/local/bin/
cp lib/* /usr/local/lib/

echo "/usr/local/lib" > /etc/ld.so.conf.d/mysql-odbc.conf
ldconfig

myodbc-installer -a -d -n "MySQL ODBC 8.0 Driver" -t "Driver=/usr/local/lib/libmyodbc8w.so"
myodbc-installer -a -d -n "MySQL ODBC 8.0" -t "Driver=/usr/local/lib/libmyodbc8a.so"

odbcinst -q -d
```

### Tomcat Installation (RHEL)

```bash
# Create tomcat user
useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat

# Download and install Tomcat 9
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.85/bin/apache-tomcat-9.0.85.tar.gz
tar xzf apache-tomcat-9.0.85.tar.gz
mv apache-tomcat-9.0.85 /opt/tomcat

chown -R tomcat:tomcat /opt/tomcat
chmod -R u+x /opt/tomcat/bin

# Create systemd service (adjust JAVA_HOME for RHEL)
cat > /etc/systemd/system/tomcat.service <<'EOF'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk"
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

systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
```

### SELinux Considerations (RHEL/CentOS)

If SELinux is enabled, you may need to configure policies:

```bash
# Check SELinux status
sestatus

# Option 1: Set to permissive mode (temporary)
setenforce 0

# Option 2: Configure SELinux policies (recommended)
# Allow Tomcat to bind to ports
semanage port -a -t http_port_t -p tcp 8080
semanage port -a -t http_port_t -p tcp 8443

# Allow ESET server ports
semanage port -a -t http_port_t -p tcp 2222
semanage port -a -t http_port_t -p tcp 2223
```

### Firewall Configuration (RHEL/CentOS)

```bash
# Configure firewalld
firewall-cmd --permanent --add-port=2222/tcp
firewall-cmd --permanent --add-port=2223/tcp
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=8443/tcp
firewall-cmd --reload
```

---

## Common Configuration (All Distributions)

### ESET Protect Server Installation

The ESET server installation is the same across all distributions:

```bash
wget https://download.eset.com/com/eset/apps/business/era/server/linux/latest/server_linux_x86_64.sh
chmod +x server_linux_x86_64.sh

./server_linux_x86_64.sh \
  --skip-license \
  --db-type="MySQL Server" \
  --db-driver="MySQL ODBC 8.0 Driver" \
  --db-hostname=localhost \
  --db-port=3306 \
  --db-admin-username=root \
  --db-admin-password=your_mysql_password \
  --server-root-password=your_eset_admin_password \
  --db-user-username=era_user \
  --db-user-password=era_db_password \
  --cert-hostname="*"
```

### Web Console Deployment

Deploy the web console (same for all distributions):

```bash
systemctl stop tomcat
rm -rf /opt/tomcat/webapps/era*

wget -O /opt/tomcat/webapps/era.war \
  https://download.eset.com/com/eset/apps/business/era/webconsole/latest/era_x64.war

chown tomcat:tomcat /opt/tomcat/webapps/era.war

systemctl start tomcat
```

---

### Troubleshooting

#### Web Console Shows 404 Error

**Issue:** Tomcat 10 is incompatible with ESET Web Console.

**Solution:** Ensure you're using Tomcat 9, not Tomcat 10:

```bash
# Check Tomcat version
grep "Apache Tomcat" /opt/tomcat/RELEASE-NOTES

# If it shows Tomcat 10, remove and install Tomcat 9
systemctl stop tomcat
rm -rf /opt/tomcat
# Follow Step 11 to install Tomcat 9
```

#### Web Console Deployment Failed

**Check deployment logs:**

```bash
tail -100 /opt/tomcat/logs/catalina.out
tail -50 /opt/tomcat/logs/localhost.$(date +%Y-%m-%d).log
```

**Common issues:**
- WAR file corrupted: Re-download the WAR file
- Insufficient disk space: Check with `df -h`
- Permission issues: Ensure tomcat user owns all files in /opt/tomcat

#### ODBC Driver Not Found

If you see "Can't open lib" errors:

```bash
# Verify library is registered
ldconfig -p | grep myodbc

# If not found, re-run ldconfig
echo "/usr/local/lib" > /etc/ld.so.conf.d/mysql-odbc.conf
ldconfig

# Verify driver registration
odbcinst -q -d
```

#### MySQL Access Denied (Error 1698)

Ensure root user uses `mysql_native_password` authentication:

```bash
mysql -u root -p
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your_password';
FLUSH PRIVILEGES;
```

#### ESET Server Service Won't Start

Check service logs:

```bash
journalctl -u eraserver -f
cat /var/log/eset/RemoteAdministrator/Server.log
```

#### Port Already in Use

Check what's using the ports:

```bash
# Check port 8080 or 8443
netstat -tlnp | grep 8080
ss -tlnp | grep 8080

# Check ESET ports
netstat -tlnp | grep -E '222[23]'
```

#### Certificate Warnings

The self-signed certificate will trigger browser warnings. This is normal. To use a proper certificate:

```bash
# Import your certificate into the keystore
keytool -delete -alias tomcat -keystore /opt/tomcat/conf/keystore.jks -storepass changeit
keytool -import -alias tomcat -file your-cert.pem -keystore /opt/tomcat/conf/keystore.jks -storepass changeit
```

### Diagnostic Tool

Use the diagnostic script to collect troubleshooting information:

```bash
# Download and run diagnostic script
wget https://raw.githubusercontent.com/your-repo/eset-protect/main/scripts/utils/logging.sh
chmod +x logging.sh
./logging.sh

# Review the generated log file
cat webconsole-diagnostic-*.log
```

### Post-Installation

1. Configure firewall rules if needed:
   ```bash
   ufw allow 2223/tcp  # ESET Web Console
   ufw allow 2222/tcp  # ESET Server port
   ```

2. Set up regular database backups
3. Configure ESET policies and install agents on client machines

### Additional Resources

- [ESET Protect Documentation](https://help.eset.com/protect_install/)
- ESET Support Portal