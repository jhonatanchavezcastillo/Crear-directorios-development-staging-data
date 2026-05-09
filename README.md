# Crear-directorios-development-staging-data


Estructura
/srv/mi-proyecto/
├── development/        # Código fuente y Docker Compose de desarrollo
├── staging/            # Configuración para puesta en escena (Air-Gapped/Local)
└── data/               # Persistencia de volúmenes (Fuera de los contenedores)
    ├── postgres/
    └── redis/

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
7. Renombrar el script
