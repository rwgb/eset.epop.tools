# ESET Protect On-Prem Docker POC

**⚠️ PROOF OF CONCEPT - NOT FOR PRODUCTION USE**

This is an experimental Docker setup for ESET Protect On-Prem. ESET does not officially support containerized deployments, so use this at your own risk for development/testing purposes only.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                Docker Network                    │
│                                                  │
│  ┌──────────┐    ┌──────────────┐    ┌────────┐│
│  │  MySQL   │◄───┤ ESET Server  │───►│  Web   ││
│  │  8.0     │    │ (Ubuntu 24)  │    │Console ││
│  │          │    │              │    │(Tomcat)││
│  └──────────┘    └──────────────┘    └────────┘│
│       :3306           :2222/:2223      :8080/   │
│                                        :8443    │
└─────────────────────────────────────────────────┘
```

## Components

1. **MySQL** - Database server with ODBC compatibility
2. **ESET Server** - Core ESET Protect server (Ubuntu 24.04 + supervisord)
3. **Web Console** - Tomcat 9 serving the ESET web interface

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available for containers
- 20GB free disk space

## Quick Start

1. **Clone and navigate to the docker directory:**
   ```bash
   cd docker/
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` with your passwords:**
   ```bash
   # Use strong passwords!
   MYSQL_ROOT_PASSWORD=your_secure_mysql_password
   ESET_ADMIN_PASSWORD=your_secure_eset_admin_password
   DB_USER_USERNAME=erauser
   DB_USER_PASSWORD=your_secure_db_user_password
   ```

4. **Build and start containers:**
   ```bash
   docker-compose up -d
   ```

5. **Monitor installation progress:**
   ```bash
   # Watch ESET server logs
   docker-compose logs -f eset-server
   
   # Check all container status
   docker-compose ps
   ```

6. **Access the web console:**
   - HTTP: http://localhost:8080/era
   - HTTPS: https://localhost:8443/era (self-signed certificate warning expected)
   
   Default credentials:
   - Username: `Administrator`
   - Password: Value you set for `ESET_ADMIN_PASSWORD`

## Management Commands

### Start/Stop

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Stop and remove all data (⚠️ destroys volumes)
docker-compose down -v
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f eset-server
docker-compose logs -f mysql
docker-compose logs -f webconsole
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart eset-server
```

### Rebuild Containers

```bash
# Rebuild all containers
docker-compose build --no-cache

# Rebuild and restart
docker-compose up -d --build
```

## Troubleshooting

### ESET Server Won't Start

Check the logs:
```bash
docker-compose logs eset-server
docker exec -it eset-server cat /var/log/eset/RemoteAdministrator/Server.log
```

### Web Console 404 Error

1. Check if WAR deployed correctly:
   ```bash
   docker exec -it eset-webconsole ls -la /usr/local/tomcat/webapps/era/
   ```

2. Check Tomcat logs:
   ```bash
   docker-compose logs webconsole
   docker exec -it eset-webconsole cat /usr/local/tomcat/logs/catalina.out
   ```

### Database Connection Issues

1. Verify MySQL is running:
   ```bash
   docker-compose ps mysql
   ```

2. Test database connection:
   ```bash
   docker exec -it eset-mysql mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW DATABASES;"
   ```

3. Check ODBC driver registration:
   ```bash
   docker exec -it eset-server odbcinst -q -d
   ```

### Container Health Checks

```bash
# View health status
docker-compose ps

# Inspect specific container health
docker inspect --format='{{json .State.Health}}' eset-server | jq
```

## Known Limitations

⚠️ **Important Limitations:**

1. **Not Production Ready** - This is a POC and lacks:
   - High availability
   - Proper backup/restore procedures
   - Performance tuning
   - Official ESET support

2. **systemd Workaround** - Uses supervisord instead of systemd, which may cause:
   - Service management differences
   - Potential compatibility issues

3. **Certificate Management** - Uses self-signed certificates:
   - Browser warnings expected
   - Not suitable for production use

4. **Resource Constraints** - May not handle large deployments:
   - Limited to single-node setup
   - No load balancing

5. **Updates** - Manual process:
   - No automatic ESET updates
   - Requires rebuilding containers

## Data Persistence

All important data is stored in Docker volumes:

- `mysql-data` - MySQL database
- `eset-data` - ESET configuration and data
- `eset-logs` - ESET logs
- `eset-certs` - SSL certificates
- `webconsole-logs` - Tomcat logs

**Backup volumes:**
```bash
# Backup MySQL data
docker run --rm -v eset_mysql-data:/data -v $(pwd):/backup ubuntu tar czf /backup/mysql-backup-$(date +%Y%m%d).tar.gz /data

# Backup ESET data
docker run --rm -v eset_eset-data:/data -v $(pwd):/backup ubuntu tar czf /backup/eset-backup-$(date +%Y%m%d).tar.gz /data
```

## Network Ports

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| MySQL | 3306 | TCP | Database |
| ESET Server | 2222 | TCP | Agent communication |
| ESET Server | 2223 | TCP | Server Console (HTTPS) |
| Web Console | 8080 | TCP | HTTP interface |
| Web Console | 8443 | TCP | HTTPS interface |

## Advanced Configuration

### Custom ESET Installer Version

Edit `docker-compose.yml` or `.env`:
```yaml
environment:
  ESET_INSTALLER_URL: https://download.eset.com/path/to/specific/version.sh
```

### Increase Memory Limits

Edit `docker-compose.yml`:
```yaml
services:
  eset-server:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

### External Database

To use an external MySQL server instead of the containerized one:

1. Remove the `mysql` service from `docker-compose.yml`
2. Update `MYSQL_HOST` environment variable in `eset-server` service
3. Ensure the external MySQL has ODBC compatibility configured

## Comparison: Docker vs Bare Metal

| Feature | Docker POC | Bare Metal (install-eset.sh) |
|---------|------------|------------------------------|
| Installation Time | ~10 minutes | ~15 minutes |
| Isolation | Excellent | None |
| Portability | High | Low |
| Resource Overhead | ~500MB extra | Minimal |
| systemd Support | Emulated (supervisord) | Native |
| Official Support | ❌ No | ✅ Yes |
| Production Ready | ❌ No | ✅ Yes |
| Easy Updates | ❌ Rebuild required | ✅ Standard upgrade |
| Backup/Restore | Volume snapshots | File-based |

## Recommendation

**For Production:** Use the bare-metal installation script ([install-eset.sh](../scripts/install-eset.sh))

**For Development/Testing:** This Docker POC can be useful for:
- Quick testing environments
- Development and integration testing
- Learning ESET Protect architecture
- Isolated test instances

## Support

This is an unofficial proof of concept. For production deployments:
- Use the official ESET installation methods
- Contact ESET support for assistance
- Refer to official ESET documentation

## License

This Docker POC is provided as-is without warranty. ESET Protect On-Prem is a commercial product subject to ESET's licensing terms.
