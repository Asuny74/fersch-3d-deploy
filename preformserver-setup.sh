#!/bin/bash

##############################################
# INSTALLATION PREFORMSERVER - FERSCH 3D
# Formlabs PreForm Server API
##############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   PREFORMSERVER INSTALLATION          ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Vérifier root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Ce script doit être exécuté en root${NC}"
  exit 1
fi

##############################################
# ÉTAPE 1 : TÉLÉCHARGEMENT
##############################################

echo -e "${YELLOW}[1/5] Téléchargement PreFormServer...${NC}"

PREFORM_DIR="/opt/preformserver"
mkdir -p $PREFORM_DIR
cd $PREFORM_DIR

# Télécharger la dernière version
# Note: Remplace par l'URL officielle Formlabs
PREFORM_URL="https://formlabs.com/download/preformserver-latest-linux"

echo -e "${YELLOW}⚠️  IMPORTANT: Télécharge manuellement PreFormServer depuis:${NC}"
echo -e "${BLUE}https://formlabs.com/software/preform/download/${NC}"
echo ""
echo -e "${YELLOW}Puis dépose le fichier dans: $PREFORM_DIR${NC}"
echo ""
read -p "Appuie sur ENTRÉE quand c'est fait..."

# Vérifier présence
if [ ! -f "$PREFORM_DIR/PreFormServer" ] && [ ! -f "$PREFORM_DIR/preformserver" ]; then
  echo -e "${RED}❌ Fichier PreFormServer introuvable${NC}"
  exit 1
fi

echo -e "${GREEN}✅ PreFormServer trouvé${NC}"

##############################################
# ÉTAPE 2 : DÉPENDANCES
##############################################

echo -e "${YELLOW}[2/5] Installation des dépendances...${NC}"

apt-get update
apt-get install -y \
  libgl1-mesa-glx \
  libglib2.0-0 \
  libxrender1 \
  libxrandr2 \
  libxi6 \
  libxcursor1 \
  libxinerama1 \
  libxss1 \
  libxtst6 \
  libasound2

echo -e "${GREEN}✅ Dépendances installées${NC}"

##############################################
# ÉTAPE 3 : PERMISSIONS
##############################################

echo -e "${YELLOW}[3/5] Configuration des permissions...${NC}"

chmod +x $PREFORM_DIR/PreFormServer 2>/dev/null || chmod +x $PREFORM_DIR/preformserver

echo -e "${GREEN}✅ Permissions configurées${NC}"

##############################################
# ÉTAPE 4 : SERVICE SYSTEMD
##############################################

echo -e "${YELLOW}[4/5] Création du service systemd...${NC}"

cat > /etc/systemd/system/preformserver.service <<'SERVICE_EOF'
[Unit]
Description=Formlabs PreFormServer API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/preformserver
ExecStart=/opt/preformserver/PreFormServer --port 44388 --headless
Restart=always
RestartSec=10
Environment=DISPLAY=:99

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable preformserver
systemctl start preformserver

echo -e "${GREEN}✅ Service créé et démarré${NC}"

##############################################
# ÉTAPE 5 : TEST
##############################################

echo -e "${YELLOW}[5/5] Test de connexion...${NC}"

sleep 5

if curl -s http://localhost:44388/health > /dev/null 2>&1; then
  echo -e "${GREEN}✅ PreFormServer opérationnel !${NC}"
else
  echo -e "${YELLOW}⚠️  PreFormServer en cours de démarrage...${NC}"
  echo -e "${BLUE}Vérifier les logs: journalctl -u preformserver -f${NC}"
fi

##############################################
# FIN
##############################################

echo -e "${GREEN}"
echo "╔════════════════════════════════════════╗"
echo "║   ✅ PREFORMSERVER INSTALLÉ !          ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📍 API: http://localhost:44388${NC}"
echo -e "${BLUE}📊 Status: systemctl status preformserver${NC}"
echo -e "${BLUE}📝 Logs: journalctl -u preformserver -f${NC}"
echo ""
echo -e "${YELLOW}📖 Documentation API:${NC}"
echo "  POST /api/analyze - Analyser un STL"
echo "  GET  /health      - Vérifier le statut"
