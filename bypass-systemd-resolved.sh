#!/bin/bash

echo "======================================"
echo "Contournement de systemd-resolved"
echo "======================================"
echo ""
echo "Ce script va :"
echo "  1. Désactiver le stub DNS de systemd-resolved"
echo "  2. Remplacer /etc/resolv.conf par une configuration statique"
echo "  3. Protéger le fichier contre les modifications"
echo ""
echo "⚠️  ATTENTION : Cette méthode contourne systemd-resolved"
echo "    Elle fonctionne mais n'est pas la solution idéale"
echo ""
read -p "Voulez-vous continuer ? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

echo ""
echo "1. Test de connectivité avant modification"
echo "------------------------------------------------"
echo "Test ping vers 8.8.8.8 :"
ping -c 2 8.8.8.8
PING_RESULT=$?

if [ $PING_RESULT -ne 0 ]; then
    echo "✗ Ping échoue - Ce script ne résoudra pas le problème"
    echo "  Le problème est plus profond (routes, NSG Azure, etc.)"
    echo "  Exécutez ./advanced-diagnostic.sh pour plus d'infos"
    exit 1
fi
echo "✓ Ping fonctionne"
echo ""

echo "Test DNS direct vers 8.8.8.8 :"
dig @8.8.8.8 github.com +short +timeout=3
DIG_RESULT=$?

if [ $DIG_RESULT -ne 0 ]; then
    echo "✗ DNS est bloqué même en direct"
    echo "  Le problème vient du réseau (NSG Azure, firewall, etc.)"
    echo "  Ce script ne résoudra pas le problème"
    echo ""
    echo "Vérifiez :"
    echo "  1. Azure NSG autorise le port 53 UDP en sortie"
    echo "  2. Pas de firewall (ufw) actif : sudo ufw status"
    echo "  3. Pas de règles iptables bloquantes"
    exit 1
fi
echo "✓ DNS fonctionne en direct"
echo ""

echo "2. Sauvegarde de la configuration actuelle"
echo "------------------------------------------------"
if [ -L /etc/resolv.conf ]; then
    echo "/etc/resolv.conf est un lien symbolique vers :"
    ls -la /etc/resolv.conf
    sudo cp --remove-destination /etc/resolv.conf /etc/resolv.conf.backup
else
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup
fi
echo "✓ Sauvegarde créée : /etc/resolv.conf.backup"
echo ""

echo "3. Rendre /etc/resolv.conf modifiable (enlever protection)"
echo "------------------------------------------------"
sudo chattr -i /etc/resolv.conf 2>/dev/null || echo "Fichier déjà modifiable"
echo "✓ Protection enlevée"
echo ""

echo "4. Supprimer le lien symbolique systemd-resolved"
echo "------------------------------------------------"
if [ -L /etc/resolv.conf ]; then
    sudo rm /etc/resolv.conf
    echo "✓ Lien symbolique supprimé"
else
    echo "✓ Pas un lien symbolique, on continue"
fi
echo ""

echo "5. Créer un nouveau /etc/resolv.conf avec DNS publics"
echo "------------------------------------------------"
sudo tee /etc/resolv.conf > /dev/null <<EOF
# Configuration DNS statique (bypass systemd-resolved)
# Fichier créé par bypass-systemd-resolved.sh
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
options timeout:2 attempts:2
EOF
echo "✓ Nouveau /etc/resolv.conf créé"
echo ""

echo "Contenu de /etc/resolv.conf :"
cat /etc/resolv.conf
echo ""

echo "6. Protéger le fichier contre les modifications"
echo "------------------------------------------------"
sudo chattr +i /etc/resolv.conf
echo "✓ Fichier protégé (immutable)"
echo ""

echo "7. Tests de validation"
echo "------------------------------------------------"
echo "Test 1 : nslookup github.com"
nslookup github.com
NSLOOKUP_RESULT=$?
echo ""

echo "Test 2 : dig google.com"
dig google.com +short
DIG_TEST=$?
echo ""

echo "Test 3 : curl https://github.com"
curl -I https://github.com --connect-timeout 5
CURL_RESULT=$?
echo ""

echo "======================================"
echo "Résultat"
echo "======================================"
echo ""

if [ $NSLOOKUP_RESULT -eq 0 ] && [ $DIG_TEST -eq 0 ] && [ $CURL_RESULT -eq 0 ]; then
    echo "✓ DNS FONCTIONNE !"
    echo ""
    echo "Vous pouvez maintenant relancer l'installation :"
    echo "  cd ~/infra"
    echo "  minikube delete"
    echo "  ./script-init-prod-env"
    echo ""
else
    echo "✗ DNS ne fonctionne toujours pas"
    echo ""
    echo "Le problème vient probablement de :"
    echo "  1. NSG Azure bloquant le port 53 UDP en sortie"
    echo "  2. Firewall réseau Azure"
    echo "  3. Règles iptables bloquantes"
    echo ""
    echo "Exécutez ./advanced-diagnostic.sh pour plus d'infos"
    echo ""
    echo "Pour restaurer la configuration précédente :"
    echo "  sudo chattr -i /etc/resolv.conf"
    echo "  sudo cp /etc/resolv.conf.backup /etc/resolv.conf"
fi
echo ""
