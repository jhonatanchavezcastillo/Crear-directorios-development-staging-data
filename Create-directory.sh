#!/bin/bash

# setup-directory.sh
# Crea una estructura base de proyecto en /srv

set -e

echo "======================================="
echo "   Configuración de estructura base"
echo "======================================="
echo

# Solicitar nombre del proyecto
read -p "Ingresa el nombre del proyecto: " PROJECT_NAME

# Validar entrada
if [ -z "$PROJECT_NAME" ]; then
    echo "El nombre del proyecto no puede estar vacío."
    exit 1
fi

# Ruta base
BASE_PATH="/srv/$PROJECT_NAME"

echo
echo "Creando estructura en: $BASE_PATH"
echo

# Crear directorios
sudo mkdir -p "$BASE_PATH/development"
sudo mkdir -p "$BASE_PATH/staging"
sudo mkdir -p "$BASE_PATH/data/postgres"
sudo mkdir -p "$BASE_PATH/data/redis"

# Asignar permisos al usuario actual
sudo chown -R $USER:$USER "$BASE_PATH"

# Mostrar resultado
echo " Estructura creada correctamente:"
echo

tree "$BASE_PATH" 2>/dev/null || find "$BASE_PATH"

echo
echo "Proceso finalizado."
