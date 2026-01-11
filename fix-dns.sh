#!/bin/bash

# Script de correction DNS pour VM Azure
echo "======================================"
echo "Correction Configuration DNS"
echo "======================================"
echo ""

echo "Ce script va :"
echo "  1. Configurer les DNS publics (Google DNS 8.8.8.8 et 8.8.4.4)"
echo "  2. Redémarrer systemd-resolved"
echo "  3. Vérifier la connectivité"
echo ""
read -p "Voulez-vous continuer ? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

echo ""
echo "1. Sauvegarde de la configuration actuelle"
echo "------------------------------------------------"
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup
echo "✓ Sauvegarde créée : /etc/systemd/resolved.conf.backup"
echo ""

echo "2. Configuration de systemd-resolved avec DNS publics"
echo "------------------------------------------------"
sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=208.67.222.222 208.67.220.220
#Domains=
#DNSSEC=no
#DNSOverTLS=no
#MulticastDNS=no
#LLMNR=no
#Cache=yes
#CacheFromLocalhost=no
#DNSStubListener=yes
#DNSStubListenerExtra=
#ReadEtcHosts=yes
#ResolveUnicastSingleLabel=no
EOF
echo "✓ Configuration écrite dans /etc/systemd/resolved.conf"
echo ""

echo "3. Redémarrage de systemd-resolved"
echo "------------------------------------------------"
sudo systemctl restart systemd-resolved
sleep 2
echo "✓ systemd-resolved redémarré"
echo ""

echo "4. Vérification du statut"
echo "------------------------------------------------"
sudo systemctl status systemd-resolved --no-pager | head -10
echo ""

echo "5. Test de résolution DNS"
echo "------------------------------------------------"
echo "Test 1 : Résolution de github.com"
nslookup github.com
echo ""

echo "Test 2 : Résolution de google.com"
nslookup google.com
echo ""

echo "6. Test de connectivité HTTP"
echo "------------------------------------------------"
curl -I https://github.com --connect-timeout 5
echo ""

echo "======================================"
echo "Configuration DNS terminée"
echo "======================================"
echo ""
echo "Si les tests ci-dessus réussissent, vous pouvez relancer :"
echo "  ./script-init-prod-env"
echo ""
echo "Si ça ne fonctionne toujours pas, vérifiez :"
echo "  1. Le Network Security Group (NSG) autorise le trafic sortant (Outbound)"
echo "  2. Votre VM a bien une route par défaut vers Internet"
echo "  3. Pas de proxy HTTP configuré qui bloquerait le trafic"
echo ""
