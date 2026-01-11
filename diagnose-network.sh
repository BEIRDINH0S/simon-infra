#!/bin/bash

# Script de diagnostic réseau pour VM Azure
echo "======================================"
echo "Diagnostic Réseau VM Azure"
echo "======================================"
echo ""

echo "1. Test de résolution DNS avec systemd-resolved"
echo "------------------------------------------------"
resolvectl status | head -20
echo ""

echo "2. Contenu de /etc/resolv.conf"
echo "------------------------------------------------"
cat /etc/resolv.conf
echo ""

echo "3. Test de ping vers IP publique (Google DNS)"
echo "------------------------------------------------"
ping -c 3 8.8.8.8
echo ""

echo "4. Test de résolution DNS manuelle"
echo "------------------------------------------------"
nslookup github.com
echo ""

echo "5. Test de résolution avec dig"
echo "------------------------------------------------"
dig github.com
echo ""

echo "6. Test de connectivité HTTP vers github.com"
echo "------------------------------------------------"
curl -v --connect-timeout 5 https://github.com 2>&1 | head -20
echo ""

echo "7. Routes réseau"
echo "------------------------------------------------"
ip route show
echo ""

echo "8. Interfaces réseau et adresses IP"
echo "------------------------------------------------"
ip addr show
echo ""

echo "9. Configuration DNS dans le conteneur Docker Minikube"
echo "------------------------------------------------"
docker exec minikube cat /etc/resolv.conf
echo ""

echo "10. Test DNS depuis le conteneur Minikube"
echo "------------------------------------------------"
docker exec minikube ping -c 2 8.8.8.8
docker exec minikube nslookup github.com
echo ""

echo "======================================"
echo "Diagnostic terminé"
echo "======================================"
