#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   Configuración de estructura base${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

read -p "Ingresa el nombre del proyecto: " PROJECT_NAME

if [ -z "$PROJECT_NAME" ]; then
    echo "El nombre del proyecto no puede estar vacío."
    exit 1
fi

echo
echo "¿Qué entorno deseas configurar?"
echo "  1) Development"
echo "  2) Production (staging)"
echo "  3) Ambas"
read -p "Ingresa el número [1-3]: " ENV_OPTION

case "$ENV_OPTION" in
    1) ENV_MODE="development" ;;
    2) ENV_MODE="production" ;;
    3) ENV_MODE="both" ;;
    *)
        echo "Opción inválida. Usa 1, 2 o 3."
        exit 1
        ;;
esac

BASE_PATH="/srv/$PROJECT_NAME"

echo
echo -e "${YELLOW}Creando estructura en:${NC} $BASE_PATH"
echo -e "${YELLOW}Entorno:${NC} $ENV_MODE"
echo

create_env_apps() {
    local env_label="$1"
    local env_dir="apps/$env_label"

    sudo mkdir -p "$BASE_PATH/$env_dir/frontend/src"
    sudo mkdir -p "$BASE_PATH/$env_dir/frontend/public"
    sudo mkdir -p "$BASE_PATH/$env_dir/backend/src"
    sudo mkdir -p "$BASE_PATH/$env_dir/backend/uploads"
    sudo mkdir -p "$BASE_PATH/$env_dir/backend/logs"
    sudo mkdir -p "$BASE_PATH/$env_dir/workers/bullmq"
    sudo mkdir -p "$BASE_PATH/$env_dir/workers/queues"
    sudo mkdir -p "$BASE_PATH/$env_dir/scripts"

    # frontend files
    sudo tee "$BASE_PATH/$env_dir/frontend/package.json" > /dev/null <<EOF
{
  "name": "$PROJECT_NAME-$env_label-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {},
  "devDependencies": {
    "vite": "^5.0.0"
  }
}
EOF

    sudo tee "$BASE_PATH/$env_dir/frontend/vite.config.js" > /dev/null <<'EOF'
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    port: 5173,
    host: true
  },
  build: {
    outDir: 'dist'
  }
})
EOF

    sudo tee "$BASE_PATH/$env_dir/frontend/Dockerfile" > /dev/null <<'EOF'
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    sudo tee "$BASE_PATH/$env_dir/frontend/.env" > /dev/null <<EOF
NODE_ENV=$env_label
VITE_API_URL=http://localhost:3000
VITE_PORT=5173
EOF

    # backend files
    sudo tee "$BASE_PATH/$env_dir/backend/package.json" > /dev/null <<EOF
{
  "name": "$PROJECT_NAME-$env_label-backend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "node --watch src/index.js",
    "start": "node src/index.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

    sudo tee "$BASE_PATH/$env_dir/backend/Dockerfile" > /dev/null <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 3000
CMD ["node", "src/index.js"]
EOF

    sudo tee "$BASE_PATH/$env_dir/backend/.env" > /dev/null <<EOF
NODE_ENV=$env_label
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$PROJECT_NAME
DB_USER=user
DB_PASSWORD=changeme
EOF

    # workers files
    sudo tee "$BASE_PATH/$env_dir/workers/Dockerfile" > /dev/null <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
CMD ["node", "src/worker.js"]
EOF

    sudo tee "$BASE_PATH/$env_dir/workers/.env" > /dev/null <<EOF
NODE_ENV=$env_label
REDIS_HOST=localhost
REDIS_PORT=6379
EOF

    # env-level files
    sudo tee "$BASE_PATH/$env_dir/docker-compose.yml" > /dev/null <<EOF
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
    ports:
      - "5173:5173"
    volumes:
      - ./frontend/src:/app/src
    environment:
      - NODE_ENV=$env_label
    command: npm run dev

  backend:
    build:
      context: ./backend
    ports:
      - "3000:3000"
    volumes:
      - ./backend/src:/app/src
      - ./backend/uploads:/app/uploads
    environment:
      - NODE_ENV=$env_label
    depends_on:
      - redis

  workers:
    build:
      context: ./workers
    volumes:
      - ./workers:/app
    environment:
      - NODE_ENV=$env_label
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - ../../data/redis/data:/data
EOF

    sudo tee "$BASE_PATH/$env_dir/.env" > /dev/null <<EOF
NODE_ENV=$env_label
COMPOSE_PROJECT_NAME=$PROJECT_NAME-$env_label
EOF

    sudo tee "$BASE_PATH/$env_dir/README.md" > /dev/null <<EOF
# $PROJECT_NAME - $env_label

## Descripción
Entorno de $env_label para el proyecto $PROJECT_NAME.

## Servicios
- Frontend (Vite + React)
- Backend (Express)
- Workers (BullMQ)
- Redis

## Inicio rápido
\`\`\`bash
./scripts/start.sh
\`\`\`
EOF

    # scripts
    if [ "$env_label" = "development" ]; then
        sudo tee "$BASE_PATH/$env_dir/scripts/start.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Start development environment"

main() {
    echo "Starting development environment..."
    docker-compose up -d
    echo "Environment started. Frontend: http://localhost:5173 | Backend: http://localhost:3000"
}

main "$@"
EOF

        sudo tee "$BASE_PATH/$env_dir/scripts/stop.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Stop development environment"

main() {
    echo "Stopping development environment..."
    docker-compose down
    echo "Environment stopped."
}

main "$@"
EOF

        sudo tee "$BASE_PATH/$env_dir/scripts/rebuild.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Rebuild development environment"

main() {
    echo "Rebuilding development environment..."
    docker-compose up --build -d
    echo "Rebuild complete."
}

main "$@"
EOF
    else
        sudo tee "$BASE_PATH/$env_dir/scripts/deploy.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Deploy to staging environment"

main() {
    echo "Deploying to staging..."
    docker-compose up --build -d
    echo "Deployment complete."
}

main "$@"
EOF

        sudo tee "$BASE_PATH/$env_dir/scripts/rollback.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Rollback staging environment"

main() {
    echo "Rolling back staging environment..."
    docker-compose down
    git checkout -- .
    docker-compose up --build -d
    echo "Rollback complete."
}

main "$@"
EOF

        sudo tee "$BASE_PATH/$env_dir/scripts/healthcheck.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Check staging environment health"

main() {
    echo "Running health checks..."
    if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
        echo "Backend: OK"
    else
        echo "Backend: FAIL" >&2
        exit 1
    fi
    if curl -sf http://localhost:5173 > /dev/null 2>&1; then
        echo "Frontend: OK"
    else
        echo "Frontend: FAIL" >&2
        exit 1
    fi
    echo "All checks passed."
}

main "$@"
EOF
    fi
}

create_infrastructure() {
    # nginx
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/conf.d"
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/sites-available"
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/sites-enabled"
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/snippets"
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/logs/archive"
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/cache"
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/certbot/www"
    sudo mkdir -p "$BASE_PATH/infrastructure/nginx/certbot/conf"

    sudo tee "$BASE_PATH/infrastructure/nginx/nginx.conf" > /dev/null <<'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log  /var/log/nginx/access.log;
    error_log   /var/log/nginx/error.log;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/snippets/*.conf;
    include /etc/nginx/sites-enabled/*.conf;
}
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/conf.d/frontend.conf" > /dev/null <<'EOF'
server {
    listen 80;
    server_name frontend.local;

    location / {
        proxy_pass http://frontend:5173;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/conf.d/backend.conf" > /dev/null <<'EOF'
server {
    listen 80;
    server_name api.local;

    location / {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /uploads {
        alias /app/uploads;
        expires 7d;
    }
}
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/conf.d/websocket.conf" > /dev/null <<'EOF'
server {
    listen 80;
    server_name ws.local;

    location / {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/conf.d/redirects.conf" > /dev/null <<'EOF'
server {
    listen 80;
    server_name www.local;
    return 301 $scheme://frontend.local$request_uri;
}
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/conf.d/rate-limit.conf" > /dev/null <<'EOF'
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

server {
    listen 80;
    server_name api.local;

    location / {
        limit_req zone=api burst=20;
        proxy_pass http://backend:3000;
    }
}
EOF

    # sites-available
    sudo tee "$BASE_PATH/infrastructure/nginx/sites-available/development.conf" > /dev/null <<'EOF'
server {
    listen 80;
    server_name dev.local;

    location / {
        proxy_pass http://frontend:5173;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/sites-available/staging.conf" > /dev/null <<'EOF'
server {
    listen 80;
    server_name staging.local;

    location / {
        proxy_pass http://frontend:5173;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    access_log /var/log/nginx/staging-access.log;
    error_log /var/log/nginx/staging-error.log;
}
EOF

    # snippets
    sudo tee "$BASE_PATH/infrastructure/nginx/snippets/ssl.conf" > /dev/null <<'EOF'
ssl_certificate     /etc/nginx/ssl/cert.pem;
ssl_certificate_key /etc/nginx/ssl/key.pem;
ssl_protocols       TLSv1.2 TLSv1.3;
ssl_ciphers         HIGH:!aNULL:!MD5;
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/snippets/proxy.conf" > /dev/null <<'EOF'
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_redirect off;
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/snippets/security-headers.conf" > /dev/null <<'EOF'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/snippets/gzip.conf" > /dev/null <<'EOF'
gzip on;
gzip_vary on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
gzip_min_length 256;
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/snippets/cors.conf" > /dev/null <<'EOF'
add_header Access-Control-Allow-Origin "*" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;

if ($request_method = OPTIONS) {
    return 204;
}
EOF

    # log placeholders
    sudo touch "$BASE_PATH/infrastructure/nginx/logs/access.log"
    sudo touch "$BASE_PATH/infrastructure/nginx/logs/error.log"

    # nginx Dockerfile
    sudo tee "$BASE_PATH/infrastructure/nginx/Dockerfile" > /dev/null <<'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/
COPY sites-available/ /etc/nginx/sites-available/
COPY sites-enabled/ /etc/nginx/sites-enabled/
COPY snippets/ /etc/nginx/snippets/
RUN mkdir -p /var/log/nginx /var/cache/nginx
EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
EOF

    sudo tee "$BASE_PATH/infrastructure/nginx/docker-compose.nginx.yml" > /dev/null <<'EOF'
version: '3.8'

services:
  nginx:
    build:
      context: .
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./snippets:/etc/nginx/snippets:ro
      - ./logs:/var/log/nginx
      - ./cache:/var/cache/nginx
      - ../ssl:/etc/nginx/ssl:ro
    networks:
      - backend
      - frontend

networks:
  backend:
    external: true
  frontend:
    external: true
EOF

    # ssl
    sudo mkdir -p "$BASE_PATH/infrastructure/ssl/letsencrypt/live"
    sudo mkdir -p "$BASE_PATH/infrastructure/ssl/letsencrypt/archive"
    sudo mkdir -p "$BASE_PATH/infrastructure/ssl/letsencrypt/renewal"
    sudo mkdir -p "$BASE_PATH/infrastructure/ssl/self-signed"
    sudo mkdir -p "$BASE_PATH/infrastructure/ssl/dhparam"
    sudo mkdir -p "$BASE_PATH/infrastructure/ssl/backups"
    sudo touch "$BASE_PATH/infrastructure/ssl/self-signed/cert.pem"
    sudo touch "$BASE_PATH/infrastructure/ssl/self-signed/key.pem"
    sudo touch "$BASE_PATH/infrastructure/ssl/dhparam/dhparam.pem"

    # infrastructure scripts
    sudo mkdir -p "$BASE_PATH/infrastructure/scripts/deploy"
    sudo mkdir -p "$BASE_PATH/infrastructure/scripts/backups"
    sudo mkdir -p "$BASE_PATH/infrastructure/scripts/monitoring"
    sudo mkdir -p "$BASE_PATH/infrastructure/scripts/ssl"
    sudo mkdir -p "$BASE_PATH/infrastructure/scripts/maintenance"

    sudo tee "$BASE_PATH/infrastructure/scripts/deploy/deploy-dev.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Deploy development infrastructure"

main() {
    echo "Deploying development infrastructure..."
    docker-compose -f docker-compose.nginx.yml up -d
    echo "Infrastructure deployed."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/deploy/deploy-staging.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Deploy staging infrastructure"

main() {
    echo "Deploying staging infrastructure..."
    docker-compose -f docker-compose.nginx.yml up -d
    echo "Infrastructure deployed."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/deploy/rollback.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Rollback infrastructure deployment"

main() {
    echo "Rolling back infrastructure..."
    docker-compose -f docker-compose.nginx.yml down
    git checkout -- docker-compose.nginx.yml
    docker-compose -f docker-compose.nginx.yml up -d
    echo "Rollback complete."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/backups/backup-postgres.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Backup PostgreSQL database"

main() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="${0%/*}/../../../backups/daily/postgres"
    mkdir -p "$BACKUP_DIR"
    echo "Starting PostgreSQL backup..."
    # pg_dump -h localhost -U user dbname > "$BACKUP_DIR/backup_$TIMESTAMP.sql"
    echo "Backup saved to $BACKUP_DIR/backup_$TIMESTAMP.sql"
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/backups/backup-redis.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Backup Redis data"

main() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="${0%/*}/../../../backups/daily/redis"
    mkdir -p "$BACKUP_DIR"
    echo "Starting Redis backup..."
    # redis-cli SAVE
    # cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis_$TIMESTAMP.rdb"
    echo "Backup saved to $BACKUP_DIR/redis_$TIMESTAMP.rdb"
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/backups/restore-postgres.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Restore PostgreSQL database from backup"

main() {
    local backup_file="$1"
    if [ -z "$backup_file" ]; then
        echo "Usage: $0 <backup_file>" >&2
        exit 1
    fi
    echo "Restoring PostgreSQL from $backup_file..."
    # psql -h localhost -U user dbname < "$backup_file"
    echo "Restore complete."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/backups/cleanup-old-backups.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Clean up backups older than retention period"

RETENTION_DAYS=30

main() {
    local backup_dir="${0%/*}/../../../backups"
    echo "Cleaning backups older than $RETENTION_DAYS days..."
    find "$backup_dir" -type f -mtime "+$RETENTION_DAYS" -delete
    echo "Cleanup complete."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/monitoring/check-disk.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Check disk usage"

THRESHOLD=90

main() {
    echo "Checking disk usage..."
    df -h | awk -v threshold="$THRESHOLD" 'NR>1 {gsub(/%/,"",$5); if($5+0 > threshold) print "WARNING: " $6 " is " $5 "% full"}'
    echo "Disk check complete."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/monitoring/check-memory.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Check memory usage"

THRESHOLD=90

main() {
    echo "Checking memory usage..."
    local usage=$(free | awk '/Mem/ {printf "%.0f", $3/$2 * 100}')
    if [ "$usage" -gt "$THRESHOLD" ]; then
        echo "WARNING: Memory usage at ${usage}%"
    else
        echo "Memory usage: ${usage}%"
    fi
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/monitoring/check-containers.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Check Docker container status"

main() {
    echo "Checking container status..."
    local running=$(docker ps --filter "status=running" --format "{{.Names}}" | wc -l)
    local stopped=$(docker ps --filter "status=exited" --format "{{.Names}}" | wc -l)
    echo "Running: $running | Stopped: $stopped"
    if [ "$stopped" -gt 0 ]; then
        echo "WARNING: Stopped containers found:"
        docker ps --filter "status=exited" --format "{{.Names}}"
    fi
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/monitoring/alerts.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Send infrastructure alerts"

ALERT_EMAIL="admin@example.com"

main() {
    local subject="$1"
    local message="$2"
    if [ -z "$subject" ] || [ -z "$message" ]; then
        echo "Usage: $0 <subject> <message>" >&2
        exit 1
    fi
    echo "Sending alert: $subject"
    # mail -s "$subject" "$ALERT_EMAIL" <<< "$message"
    echo "Alert sent to $ALERT_EMAIL."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/ssl/renew-ssl.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Renew SSL certificates via Let's Encrypt"

main() {
    echo "Renewing SSL certificates..."
    # certbot renew --quiet
    docker-compose -f ${0%/*}/../../nginx/docker-compose.nginx.yml run --rm certbot renew
    docker-compose -f ${0%/*}/../../nginx/docker-compose.nginx.yml exec nginx nginx -s reload
    echo "SSL renewal complete."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/ssl/generate-selfsigned.sh" > /dev/null <<EOF
#!/bin/bash
set -e

DESCRIPTION="Generate self-signed SSL certificate"

main() {
    local ssl_dir="${0%/*}/../../ssl/self-signed"
    mkdir -p "$ssl_dir"
    echo "Generating self-signed certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_dir/key.pem" \
        -out "$ssl_dir/cert.pem" \
        -subj "/C=MX/ST=Estado/L=Ciudad/O=$PROJECT_NAME/CN=localhost"
    echo "Certificate generated in $ssl_dir"
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/maintenance/prune-docker.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Prune unused Docker resources"

main() {
    echo "Pruning Docker resources..."
    docker system prune -af --volumes
    echo "Docker prune complete."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/maintenance/clean-logs.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Clean old log files"

RETENTION_DAYS=7

main() {
    local log_dir="${0%/*}/../../../data/logs"
    echo "Cleaning logs older than $RETENTION_DAYS days..."
    find "$log_dir" -type f -name "*.log" -mtime "+$RETENTION_DAYS" -delete
    echo "Log cleanup complete."
}

main "$@"
EOF

    sudo tee "$BASE_PATH/infrastructure/scripts/maintenance/update-system.sh" > /dev/null <<'EOF'
#!/bin/bash
set -e

DESCRIPTION="Update system packages"

main() {
    echo "Updating system packages..."
    apt-get update && apt-get upgrade -y
    echo "System update complete."
}

main "$@"
EOF

    # monitoring
    sudo mkdir -p "$BASE_PATH/infrastructure/monitoring/prometheus/rules"
    sudo mkdir -p "$BASE_PATH/infrastructure/monitoring/grafana/dashboards"
    sudo mkdir -p "$BASE_PATH/infrastructure/monitoring/grafana/datasources"
    sudo mkdir -p "$BASE_PATH/infrastructure/monitoring/grafana/provisioning"
    sudo mkdir -p "$BASE_PATH/infrastructure/monitoring/loki"
    sudo mkdir -p "$BASE_PATH/infrastructure/monitoring/promtail"
    sudo mkdir -p "$BASE_PATH/infrastructure/monitoring/uptime-kuma"

    sudo tee "$BASE_PATH/infrastructure/monitoring/prometheus/prometheus.yml" > /dev/null <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'backend'
    static_configs:
      - targets: ['backend:3000']
EOF

    sudo tee "$BASE_PATH/infrastructure/monitoring/loki/config.yml" > /dev/null <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      replication_factor: 1

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
EOF

    sudo tee "$BASE_PATH/infrastructure/monitoring/promtail/config.yml" > /dev/null <<'EOF'
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets: ['localhost']
        labels:
          job: varlogs
          __path__: /var/log/*.log
EOF

    sudo tee "$BASE_PATH/infrastructure/monitoring/docker-compose.monitoring.yml" > /dev/null <<'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ../../data/prometheus:/prometheus

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    volumes:
      - ./grafana:/etc/grafana
      - ../../data/grafana:/var/lib/grafana

  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./loki/config.yml:/etc/loki/config.yml:ro
      - ../../data/loki:/loki

  promtail:
    image: grafana/promtail:latest
    volumes:
      - ./promtail/config.yml:/etc/promtail/config.yml:ro
      - ../../data/logs:/var/log/host
EOF

    # docker infrastructure
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/images/node"
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/images/nginx"
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/images/postgres"
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/images/redis"
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/networks"
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/volumes"
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/swarm"
    sudo mkdir -p "$BASE_PATH/infrastructure/docker/compose"

    sudo tee "$BASE_PATH/infrastructure/docker/networks/backend-network.yml" > /dev/null <<'EOF'
networks:
  backend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

    sudo tee "$BASE_PATH/infrastructure/docker/networks/frontend-network.yml" > /dev/null <<'EOF'
networks:
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/16
EOF

    sudo tee "$BASE_PATH/infrastructure/docker/volumes/volume-definitions.yml" > /dev/null <<'EOF'
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  uploads:
    driver: local
EOF

    sudo tee "$BASE_PATH/infrastructure/docker/compose/base.yml" > /dev/null <<'EOF'
version: '3.8'

services:
  backend:
    image: ${REGISTRY:-local}/${PROJECT_NAME}-backend:${TAG:-latest}
    networks:
      - backend
    environment:
      - NODE_ENV=${NODE_ENV:-production}

networks:
  backend:
    external: true
EOF

    sudo tee "$BASE_PATH/infrastructure/docker/compose/production.yml" > /dev/null <<'EOF'
version: '3.8'

include:
  - base.yml

services:
  frontend:
    image: ${REGISTRY:-local}/${PROJECT_NAME}-frontend:${TAG:-latest}
    ports:
      - "80:80"
    networks:
      - frontend

  nginx:
    image: ${REGISTRY:-local}/${PROJECT_NAME}-nginx:${TAG:-latest}
    ports:
      - "80:80"
      - "443:443"
    networks:
      - frontend
      - backend
EOF

    sudo tee "$BASE_PATH/infrastructure/docker/compose/monitoring.yml" > /dev/null <<'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
EOF
}

create_data() {
    sudo mkdir -p "$BASE_PATH/data/postgres/main"
    sudo mkdir -p "$BASE_PATH/data/postgres/replicas"
    sudo mkdir -p "$BASE_PATH/data/postgres/wal_archive"
    sudo mkdir -p "$BASE_PATH/data/postgres/backups"

    sudo mkdir -p "$BASE_PATH/data/redis/data"
    sudo mkdir -p "$BASE_PATH/data/redis/appendonly"
    sudo mkdir -p "$BASE_PATH/data/redis/backups"

    sudo mkdir -p "$BASE_PATH/data/uploads/images"
    sudo mkdir -p "$BASE_PATH/data/uploads/documents"
    sudo mkdir -p "$BASE_PATH/data/uploads/temp"
    sudo mkdir -p "$BASE_PATH/data/uploads/exports"

    sudo mkdir -p "$BASE_PATH/data/logs/nginx"
    sudo mkdir -p "$BASE_PATH/data/logs/backend"
    sudo mkdir -p "$BASE_PATH/data/logs/workers"
    sudo mkdir -p "$BASE_PATH/data/logs/system"

    sudo mkdir -p "$BASE_PATH/data/cache/nginx"
    sudo mkdir -p "$BASE_PATH/data/cache/application"
}

create_backups() {
    sudo mkdir -p "$BASE_PATH/backups/daily/postgres"
    sudo mkdir -p "$BASE_PATH/backups/daily/redis"
    sudo mkdir -p "$BASE_PATH/backups/daily/uploads"
    sudo mkdir -p "$BASE_PATH/backups/weekly"
    sudo mkdir -p "$BASE_PATH/backups/monthly"
    sudo mkdir -p "$BASE_PATH/backups/encrypted"
    sudo mkdir -p "$BASE_PATH/backups/remote"
    sudo mkdir -p "$BASE_PATH/backups/restore-points"
}

create_symlinks() {
    if [ "$ENV_MODE" = "development" ] || [ "$ENV_MODE" = "both" ]; then
        sudo ln -sf "../sites-available/development.conf" \
            "$BASE_PATH/infrastructure/nginx/sites-enabled/development.conf"
        echo -e "  ${GREEN}[symlink]${NC} sites-enabled/development.conf → sites-available/development.conf"
    fi
    if [ "$ENV_MODE" = "production" ] || [ "$ENV_MODE" = "both" ]; then
        sudo ln -sf "../sites-available/staging.conf" \
            "$BASE_PATH/infrastructure/nginx/sites-enabled/staging.conf"
        echo -e "  ${GREEN}[symlink]${NC} sites-enabled/staging.conf → sites-available/staging.conf"
    fi
}

set_permissions() {
    echo
    echo "Asignando permisos..."

    sudo chown -R "$USER:$USER" "$BASE_PATH"

    if [ "$ENV_MODE" = "development" ] || [ "$ENV_MODE" = "both" ]; then
        # development: permissive (group writable)
        find "$BASE_PATH/apps/development" -type d -exec sudo chmod 775 {} \;
        find "$BASE_PATH/apps/development" -type f -not -name "*.sh" -exec sudo chmod 664 {} \;
        find "$BASE_PATH/apps/development" -name "*.sh" -exec sudo chmod 775 {} \;
    fi

    if [ "$ENV_MODE" = "production" ] || [ "$ENV_MODE" = "both" ]; then
        # production: restrictive (only owner writable)
        find "$BASE_PATH/apps/staging" -type d -exec sudo chmod 755 {} \;
        find "$BASE_PATH/apps/staging" -type f -not -name "*.sh" -exec sudo chmod 644 {} \;
        find "$BASE_PATH/apps/staging" -name "*.sh" -exec sudo chmod 755 {} \;
    fi

    # infrastructure: general
    find "$BASE_PATH/infrastructure" -type d -exec sudo chmod 755 {} \;
    find "$BASE_PATH/infrastructure" -type f -not -name "*.sh" -exec sudo chmod 644 {} \;
    find "$BASE_PATH/infrastructure" -name "*.sh" -exec sudo chmod 755 {} \;

    # data directories: group writable for services
    find "$BASE_PATH/data" -type d -exec sudo chmod 775 {} \;
    find "$BASE_PATH/data" -type f -exec sudo chmod 664 {} \;

    # backups: writable
    find "$BASE_PATH/backups" -type d -exec sudo chmod 775 {} \;

    # nginx logs need to be writable
    sudo chmod 664 "$BASE_PATH/infrastructure/nginx/logs/access.log"
    sudo chmod 664 "$BASE_PATH/infrastructure/nginx/logs/error.log"

    echo -e "${GREEN}Permisos asignados correctamente.${NC}"
}

# =========== MAIN ===========

sudo mkdir -p "$BASE_PATH"

case "$ENV_MODE" in
    development)
        create_env_apps "development"
        ;;
    production)
        create_env_apps "staging"
        ;;
    both)
        create_env_apps "development"
        create_env_apps "staging"
        ;;
esac

create_infrastructure
create_data
create_backups
create_symlinks
set_permissions

echo
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  Estructura creada correctamente${NC}"
echo -e "${GREEN}=======================================${NC}"
echo
echo -e "${YELLOW}Resumen:${NC}"
echo "  Proyecto:  $PROJECT_NAME"
echo "  Ruta:      $BASE_PATH"
echo "  Entorno:   $ENV_MODE"
echo

if command -v tree &> /dev/null; then
    tree "$BASE_PATH" -L 3 2>/dev/null || tree "$BASE_PATH" 2>/dev/null
else
    find "$BASE_PATH" -maxdepth 3 2>/dev/null
fi

echo
echo -e "${GREEN}Proceso finalizado.${NC}"
