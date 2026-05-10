# Crear-directorios-development-staging-data

Resumen de pasos para crear las carpetas de tu entorno de development y (staging)puesta en escena 
1. Crear carpeta dentro de /srv (Sugerido para crear servicios apps)
   sudo mkdir /srv/scripts
2. Darte permisos sobre esa carpeta para ejecutar scripts futuros
  sudo chown tu-user:tu-user /srv/scripts
3. Entrar a la carpeta
  cd /srv/scripts
4. Crear el script .sh
nano create-directory.sh

Contenido básico:
Agrega el contenido del archivo "Create-directory.sh"
Guardar:
   CTRL + O
   Enter
   CTRL + X
   
5. Dar permisos de ejecución
   chmod +x create-directory.sh
6. Ejecutar el script
   ./create-directory.sh
   
Estructura
/srv/mi-proyecto/
│
├── apps/
│   │
│   ├── development/
│   │   │
│   │   ├── frontend/
│   │   │   ├── src/
│   │   │   ├── public/
│   │   │   ├── package.json
│   │   │   ├── vite.config.js
│   │   │   ├── Dockerfile
│   │   │   └── .env
│   │   │
│   │   ├── backend/
│   │   │   ├── src/
│   │   │   ├── uploads/
│   │   │   ├── logs/
│   │   │   ├── package.json
│   │   │   ├── Dockerfile
│   │   │   └── .env
│   │   │
│   │   ├── workers/
│   │   │   ├── bullmq/
│   │   │   ├── queues/
│   │   │   ├── Dockerfile
│   │   │   └── .env
│   │   │
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   ├── README.md
│   │   └── scripts/
│   │       ├── start.sh
│   │       ├── stop.sh
│   │       └── rebuild.sh
│   │
│   └── staging/
│       │
│       ├── frontend/
│       ├── backend/
│       ├── workers/
│       ├── docker-compose.yml
│       ├── .env
│       ├── README.md
│       └── scripts/
│           ├── deploy.sh
│           ├── rollback.sh
│           └── healthcheck.sh
│
├── infrastructure/
│   │
│   ├── nginx/
│   │   │
│   │   ├── nginx.conf
│   │   │
│   │   ├── conf.d/
│   │   │   ├── frontend.conf
│   │   │   ├── backend.conf
│   │   │   ├── websocket.conf
│   │   │   ├── redirects.conf
│   │   │   └── rate-limit.conf
│   │   │
│   │   ├── sites-available/
│   │   │   ├── development.conf
│   │   │   └── staging.conf
│   │   │
│   │   ├── sites-enabled/
│   │   │   ├── development.conf -> ../sites-available/development.conf
│   │   │   └── staging.conf -> ../sites-available/staging.conf
│   │   │
│   │   ├── snippets/
│   │   │   ├── ssl.conf
│   │   │   ├── proxy.conf
│   │   │   ├── security-headers.conf
│   │   │   ├── gzip.conf
│   │   │   └── cors.conf
│   │   │
│   │   ├── logs/
│   │   │   ├── access.log
│   │   │   ├── error.log
│   │   │   └── archive/
│   │   │
│   │   ├── cache/
│   │   │
│   │   ├── certbot/
│   │   │   ├── www/
│   │   │   └── conf/
│   │   │
│   │   ├── Dockerfile
│   │   └── docker-compose.nginx.yml
│   │
│   ├── ssl/
│   │   │
│   │   ├── letsencrypt/
│   │   │   ├── live/
│   │   │   ├── archive/
│   │   │   └── renewal/
│   │   │
│   │   ├── self-signed/
│   │   │   ├── cert.pem
│   │   │   └── key.pem
│   │   │
│   │   ├── dhparam/
│   │   │   └── dhparam.pem
│   │   │
│   │   └── backups/
│   │
│   ├── scripts/
│   │   │
│   │   ├── deploy/
│   │   │   ├── deploy-dev.sh
│   │   │   ├── deploy-staging.sh
│   │   │   └── rollback.sh
│   │   │
│   │   ├── backups/
│   │   │   ├── backup-postgres.sh
│   │   │   ├── backup-redis.sh
│   │   │   ├── restore-postgres.sh
│   │   │   └── cleanup-old-backups.sh
│   │   │
│   │   ├── monitoring/
│   │   │   ├── check-disk.sh
│   │   │   ├── check-memory.sh
│   │   │   ├── check-containers.sh
│   │   │   └── alerts.sh
│   │   │
│   │   ├── ssl/
│   │   │   ├── renew-ssl.sh
│   │   │   └── generate-selfsigned.sh
│   │   │
│   │   └── maintenance/
│   │       ├── prune-docker.sh
│   │       ├── clean-logs.sh
│   │       └── update-system.sh
│   │
│   ├── monitoring/
│   │   │
│   │   ├── prometheus/
│   │   │   ├── prometheus.yml
│   │   │   └── rules/
│   │   │
│   │   ├── grafana/
│   │   │   ├── dashboards/
│   │   │   ├── datasources/
│   │   │   └── provisioning/
│   │   │
│   │   ├── loki/
│   │   │   └── config.yml
│   │   │
│   │   ├── promtail/
│   │   │   └── config.yml
│   │   │
│   │   ├── uptime-kuma/
│   │   │
│   │   └── docker-compose.monitoring.yml
│   │
│   └── docker/
│       │
│       ├── images/
│       │   ├── node/
│       │   ├── nginx/
│       │   ├── postgres/
│       │   └── redis/
│       │
│       ├── networks/
│       │   ├── backend-network.yml
│       │   └── frontend-network.yml
│       │
│       ├── volumes/
│       │   └── volume-definitions.yml
│       │
│       ├── swarm/
│       │
│       └── compose/
│           ├── base.yml
│           ├── production.yml
│           └── monitoring.yml
│
├── data/
│   │
│   ├── postgres/
│   │   ├── main/
│   │   ├── replicas/
│   │   ├── wal_archive/
│   │   └── backups/
│   │
│   ├── redis/
│   │   ├── data/
│   │   ├── appendonly/
│   │   └── backups/
│   │
│   ├── uploads/
│   │   ├── images/
│   │   ├── documents/
│   │   ├── temp/
│   │   └── exports/
│   │
│   ├── logs/
│   │   ├── nginx/
│   │   ├── backend/
│   │   ├── workers/
│   │   └── system/
│   │
│   └── cache/
│       ├── nginx/
│       └── application/
│
└── backups/
    │
    ├── daily/
    │   ├── postgres/
    │   ├── redis/
    │   └── uploads/
    │
    ├── weekly/
    │
    ├── monthly/
    │
    ├── encrypted/
    │
    ├── remote/
    │
    └── restore-points/
