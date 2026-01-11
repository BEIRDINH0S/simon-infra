#!/bin/bash

echo "======================================"
echo "Diagnostic Réseau Avancé"
echo "======================================"
echo ""

echo "TEST 1 : Ping vers IP publique (8.8.8.8)"
echo "------------------------------------------------"
ping -c 3 8.8.8.8
PING_RESULT=$?
if [ $PING_RESULT -eq 0 ]; then
    echo "✓ Ping réussi - Connectivité IP fonctionne"
else
    echo "✗ Ping échoué - Problème de connectivité IP"
fi
echo ""

echo "TEST 2 : Routes réseau"
echo "------------------------------------------------"
ip route show
echo ""
echo "Route par défaut :"
ip route show default
DEFAULT_ROUTE=$?
if [ $DEFAULT_ROUTE -eq 0 ]; then
    echo "✓ Route par défaut trouvée"
else
    echo "✗ Aucune route par défaut !"
fi
echo ""

echo "TEST 3 : Interfaces réseau et adresses IP"
echo "------------------------------------------------"
ip addr show | grep -E "^[0-9]:|inet "
echo ""

echo "TEST 4 : Statut du firewall (ufw)"
echo "------------------------------------------------"
sudo ufw status
UFW_STATUS=$(sudo ufw status | grep -i "Status: active")
if [ -n "$UFW_STATUS" ]; then
    echo "⚠️  UFW est actif - peut bloquer le trafic"
else
    echo "✓ UFW est inactif"
fi
echo ""

echo "TEST 5 : Règles iptables (NAT)"
echo "------------------------------------------------"
sudo iptables -t nat -L -n -v | head -30
echo ""

echo "TEST 6 : Règles iptables (FILTER)"
echo "------------------------------------------------"
sudo iptables -t filter -L -n -v | head -30
echo ""

echo "TEST 7 : Test DNS direct vers 8.8.8.8 (bypass systemd-resolved)"
echo "------------------------------------------------"
echo "Test avec dig :"
dig @8.8.8.8 github.com +timeout=3
DIG_RESULT=$?
if [ $DIG_RESULT -eq 0 ]; then
    echo "✓ DNS fonctionne en direct vers 8.8.8.8"
else
    echo "✗ DNS bloqué même en direct"
fi
echo ""

echo "TEST 8 : Vérifier /etc/resolv.conf"
echo "------------------------------------------------"
cat /etc/resolv.conf
echo ""
echo "Vérifier si c'est un lien symbolique :"
ls -la /etc/resolv.conf
echo ""

echo "TEST 9 : Statut de systemd-resolved"
echo "------------------------------------------------"
resolvectl status | head -30
echo ""

echo "TEST 10 : Test de connectivité TCP vers 8.8.8.8:53 (DNS via TCP)"
echo "------------------------------------------------"
timeout 3 bash -c 'cat < /dev/null > /dev/tcp/8.8.8.8/53' 2>&1
TCP_DNS=$?
if [ $TCP_DNS -eq 0 ]; then
    echo "✓ Connectivité TCP vers 8.8.8.8:53 fonctionne"
else
    echo "✗ Connectivité TCP vers 8.8.8.8:53 bloquée"
fi
echo ""

echo "TEST 11 : Vérifier les processus Docker/Minikube"
echo "------------------------------------------------"
docker ps --format "{{.Names}}: {{.Status}}"
echo ""

echo "TEST 12 : Test DNS depuis le conteneur Minikube"
echo "------------------------------------------------"
echo "Ping depuis Minikube :"
docker exec minikube ping -c 2 8.8.8.8 2>&1 || echo "✗ Minikube ne répond pas ou n'existe pas"
echo ""
echo "DNS depuis Minikube :"
docker exec minikube nslookup github.com 2>&1 || echo "✗ Impossible de tester DNS dans Minikube"
echo ""

echo "======================================"
echo "Résumé du Diagnostic"
echo "======================================"
echo ""
if [ $PING_RESULT -eq 0 ]; then
    echo "✓ Connectivité IP : OK"
else
    echo "✗ Connectivité IP : ÉCHEC (problème critique)"
fi

if [ $DEFAULT_ROUTE -eq 0 ]; then
    echo "✓ Route par défaut : OK"
else
    echo "✗ Route par défaut : MANQUANTE (problème critique)"
fi

if [ -n "$UFW_STATUS" ]; then
    echo "⚠️  Firewall UFW : ACTIF (peut causer des problèmes)"
else
    echo "✓ Firewall UFW : INACTIF"
fi

if [ $DIG_RESULT -eq 0 ]; then
    echo "✓ DNS direct (dig @8.8.8.8) : OK"
    echo "  → Le problème vient de systemd-resolved"
else
    echo "✗ DNS direct (dig @8.8.8.8) : BLOQUÉ"
    echo "  → Le problème vient du réseau Azure (NSG, routes, etc.)"
fi

if [ $TCP_DNS -eq 0 ]; then
    echo "✓ TCP vers 8.8.8.8:53 : OK"
else
    echo "✗ TCP vers 8.8.8.8:53 : BLOQUÉ"
fi

echo ""
echo "======================================"
echo "Recommandations"
echo "======================================"
echo ""

if [ $PING_RESULT -ne 0 ]; then
    echo "CRITIQUE : Pas de connectivité IP !"
    echo "→ Vérifiez la configuration réseau Azure (NSG, routes, subnet)"
    echo ""
fi

if [ $DIG_RESULT -eq 0 ] && [ $PING_RESULT -eq 0 ]; then
    echo "DNS fonctionne en direct mais systemd-resolved échoue."
    echo "→ Essayez de contourner systemd-resolved avec :"
    echo "   sudo rm /etc/resolv.conf"
    echo "   sudo bash -c 'echo \"nameserver 8.8.8.8\" > /etc/resolv.conf'"
    echo "   sudo bash -c 'echo \"nameserver 8.8.4.4\" >> /etc/resolv.conf'"
    echo "   sudo chattr +i /etc/resolv.conf  # Empêche modification"
    echo ""
elif [ $PING_RESULT -eq 0 ] && [ $DIG_RESULT -ne 0 ]; then
    echo "Ping fonctionne mais DNS bloqué."
    echo "→ Vérifiez le NSG Azure : le port 53 UDP doit être autorisé en sortie"
    echo "→ Vérifiez qu'il n'y a pas de firewall réseau Azure"
    echo ""
fi

if [ -n "$UFW_STATUS" ]; then
    echo "UFW est actif et peut bloquer le DNS."
    echo "→ Essayez : sudo ufw disable"
    echo ""
fi

echo "Pour plus d'aide, partagez le résultat de ce script."
echo ""
