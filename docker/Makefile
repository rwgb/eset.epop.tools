.PHONY: help build up down restart logs clean rebuild

# Default target
help:
	@echo "ESET Protect Docker POC - Available Commands:"
	@echo ""
	@echo "  make build       - Build all Docker images"
	@echo "  make up          - Start all containers"
	@echo "  make down        - Stop all containers"
	@echo "  make restart     - Restart all containers"
	@echo "  make logs        - View logs from all containers"
	@echo "  make logs-eset   - View ESET server logs"
	@echo "  make logs-web    - View web console logs"
	@echo "  make logs-db     - View MySQL logs"
	@echo "  make clean       - Stop and remove all containers and volumes (⚠️  DESTROYS DATA)"
	@echo "  make rebuild     - Rebuild and restart all containers"
	@echo "  make shell-eset  - Open shell in ESET server container"
	@echo "  make shell-web   - Open shell in web console container"
	@echo "  make shell-db    - Open shell in MySQL container"
	@echo "  make status      - Show container status"
	@echo "  make backup      - Backup MySQL and ESET data"
	@echo ""

# Build Docker images
build:
	docker-compose build

# Start containers
up:
	docker-compose up -d

# Stop containers
down:
	docker-compose down

# Restart containers
restart:
	docker-compose restart

# View all logs
logs:
	docker-compose logs -f

# View ESET server logs
logs-eset:
	docker-compose logs -f eset-server

# View web console logs
logs-web:
	docker-compose logs -f webconsole

# View MySQL logs
logs-db:
	docker-compose logs -f mysql

# Clean everything (⚠️ DESTROYS DATA)
clean:
	@echo "⚠️  WARNING: This will delete all containers and volumes!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "✅ Cleanup complete"; \
	else \
		echo "Cancelled"; \
	fi

# Rebuild everything
rebuild:
	docker-compose down
	docker-compose build --no-cache
	docker-compose up -d

# Open shell in ESET server container
shell-eset:
	docker exec -it eset-server /bin/bash

# Open shell in web console container
shell-web:
	docker exec -it eset-webconsole /bin/bash

# Open shell in MySQL container
shell-db:
	docker exec -it eset-mysql /bin/bash

# Show container status
status:
	docker-compose ps
	@echo ""
	@echo "Health Status:"
	@docker inspect --format='{{.Name}}: {{.State.Health.Status}}' eset-server eset-webconsole eset-mysql 2>/dev/null || echo "Health checks not yet initialized"

# Backup data
backup:
	@echo "Creating backups..."
	@mkdir -p backups
	@docker run --rm -v eset_mysql-data:/data -v $$(pwd)/backups:/backup ubuntu tar czf /backup/mysql-backup-$$(date +%Y%m%d-%H%M%S).tar.gz /data
	@docker run --rm -v eset_eset-data:/data -v $$(pwd)/backups:/backup ubuntu tar czf /backup/eset-backup-$$(date +%Y%m%d-%H%M%S).tar.gz /data
	@echo "✅ Backups created in ./backups/"
	@ls -lh backups/
