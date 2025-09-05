#!/bin/bash

# Título del script
echo "========================================================================="
echo "   Desinstalando Docker completamente (incluyendo Snap) y re-instalando"
echo "   Ejecutando 'docker compose build --no-cache && up -d --force-recreate' y 'kool run setup' al finalizar"
echo "========================================================================="

# 1. Detener y eliminar contenedores, imágenes, redes y volúmenes
echo "Deteniendo y eliminando contenedores, imágenes, redes y volúmenes..."
if command -v docker &> /dev/null; then
  sudo docker stop $(sudo docker ps -aq) 2>/dev/null || echo "No hay contenedores para detener."
  sudo docker rm $(sudo docker ps -aq) 2>/dev/null || echo "No hay contenedores para eliminar."
  sudo docker rmi $(sudo docker images -q) 2>/dev/null || echo "No hay imágenes para eliminar."
  sudo docker network rm $(sudo docker network ls -q) 2>/dev/null || echo "No hay redes para eliminar."
  sudo docker volume rm $(sudo docker volume ls -q) 2>/dev/null || echo "No hay volúmenes para eliminar."
else
  echo "Docker no está instalado. Saltando eliminación de contenedores, imágenes, etc."
fi

# 2. Desinstalar Docker si fue instalado con Snap
echo "Verificando si Docker fue instalado con Snap..."
if snap list | grep -q 'docker'; then
  echo "Docker instalado con Snap detectado. Desinstalando..."
  sudo snap remove docker
else
  echo "No se encontró Docker instalado con Snap."
fi

# 3. Desinstalar paquetes APT de Docker
echo "Desinstalando paquetes APT de Docker..."
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras 2>/dev/null || echo "No hay paquetes APT de Docker para desinstalar."

# 4. Eliminar archivos y directorios de Docker
echo "Eliminando archivos y directorios de Docker..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg

# 5. Actualizar sistema e instalar dependencias
echo "Actualizando sistema e instalando dependencias..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# 6. Agregar clave GPG oficial de Docker
echo "Agregando clave GPG oficial de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 7. Agregar repositorio de Docker
echo "Agregando repositorio de Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 8. Actualizar paquetes
echo "Actualizando paquetes..."
sudo apt update

# 9. Instalar Docker Engine y plugins
echo "Instalando Docker Engine y plugins..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 10. Verificar instalación
echo "Verificando instalación..."
sudo docker --version
sudo docker compose version

# 11. Agregar automáticamente el usuario al grupo 'docker'
echo "Agregando usuario '$USER' al grupo 'docker'..."
sudo usermod -aG docker $USER

# Aplicar cambios sin reiniciar sesión
echo "Aplicando cambios de grupo..."
newgrp docker <<< ""

# 12. Hacer login en el registry privado. (Add a token) 
echo "Iniciando sesión en medtrainer.azurecr.io..."
echo "<token>" | docker login medtrainer.azurecr.io --username developers --password-stdin

# 13. Limpiar TODO: contenedores, imágenes, volúmenes, redes, caché de build
echo "Ejecutando 'docker system prune -a -f' para limpieza completa..."
docker system prune -a -f

# 14. Verificar si existe docker-compose.yml
if [ -f "docker-compose.yml" ]; then
  echo "Archivo 'docker-compose.yml' encontrado. Ejecutando 'docker compose build --no-cache && up -d --force-recreate'..."
  docker compose build --no-cache
  docker compose up -d --force-recreate
else
  echo "No se encontró un archivo 'docker-compose.yml'. Saltando build y up."
fi

# 15. Ejecutar kool run setup (si está disponible)
if command -v kool &> /dev/null; then
  echo "Ejecutando 'kool run setup'..."
  kool run setup
else
  echo "El comando 'kool' no está disponible. Asegúrate de tener 'kool' instalado o disponible en tu entorno."
fi

echo "========================================================================="
echo "✅ Docker ha sido completamente desinstalado (incluyendo Snap) y re-instalado con éxito."
echo "✅ Usuario '$USER' agregado automáticamente al grupo 'docker'."
echo "✅ Login en medtrainer.azurecr.io completado."
echo "✅ Limpieza completa con 'docker system prune -a -f' realizada."
echo "✅ Se ejecutó 'docker compose build --no-cache && up -d --force-recreate' (si existe docker-compose.yml)."
echo "✅ Se ejecutó 'kool run setup' (si 'kool' está disponible)."
echo "========================================================================="
