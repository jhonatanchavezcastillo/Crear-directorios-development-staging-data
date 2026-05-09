# Crear-directorios-development-staging-data
Estructura
/srv/mi-proyecto/
├── development/        # Código fuente y Docker Compose de desarrollo
├── staging/            # Configuración para puesta en escena (Air-Gapped/Local)
└── data/               # Persistencia de volúmenes (Fuera de los contenedores)
    ├── postgres/
    └── redis/
