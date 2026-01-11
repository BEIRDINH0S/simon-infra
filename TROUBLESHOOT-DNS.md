# Résolution du Problème DNS sur VM Azure

## Problème Identifié

Votre VM Azure ne peut pas résoudre les noms DNS (github.com, argoproj.github.io, etc.).
Cela empêche l'installation de Helm charts et l'accès à Internet.

**Erreur observée** :
```
dial tcp: lookup github.com on 127.0.0.53:53: read udp ... i/o timeout
```

## Solutions à Essayer (dans l'ordre)

### Solution 1 : Corriger la Configuration DNS (Recommandé)

**Sur votre VM Azure, exécutez** :

```bash
cd ~/infra
chmod +x fix-dns.sh
./fix-dns.sh
```

Ce script va :
- Configurer des DNS publics (Google DNS et Cloudflare)
- Redémarrer systemd-resolved
- Tester la connectivité

**Si ça fonctionne**, relancez l'installation :
```bash
minikube delete
./script-init-prod-env
```

---

### Solution 2 : Diagnostic Approfondi

Si la Solution 1 ne fonctionne pas, faites un diagnostic complet :

```bash
cd ~/infra
chmod +x diagnose-network.sh
./diagnose-network.sh > diagnostic-output.txt 2>&1
cat diagnostic-output.txt
```

Envoyez-moi le contenu de `diagnostic-output.txt` pour analyse.

---

### Solution 3 : Configuration Manuelle DNS

Si systemd-resolved pose problème, configurez les DNS manuellement :

#### 3.1. Vérifier la configuration réseau

```bash
# Voir les interfaces réseau
ip addr show

# Voir les routes
ip route show

# Identifier le fichier de configuration réseau (Netplan sur Ubuntu 24.04)
ls -la /etc/netplan/
```

#### 3.2. Éditer la configuration Netplan

**Trouvez le fichier Netplan** (généralement `50-cloud-init.yaml` ou similaire) :

```bash
sudo ls /etc/netplan/
```

**Éditez le fichier** (exemple avec 50-cloud-init.yaml) :

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

**Ajoutez la section nameservers** :

```yaml
network:
    version: 2
    ethernets:
        eth0:  # Remplacez par votre interface (voir avec 'ip addr')
            dhcp4: true
            nameservers:
                addresses:
                    - 8.8.8.8
                    - 8.8.4.4
                    - 1.1.1.1
```

**Appliquez la configuration** :

```bash
sudo netplan apply
```

**Vérifiez** :

```bash
nslookup github.com
ping -c 3 8.8.8.8
curl -I https://github.com
```

---

### Solution 4 : Vérifier la Configuration Azure

Si rien ne fonctionne, le problème vient peut-être de la configuration Azure.

#### 4.1. Network Security Group (NSG)

**Vérifiez les règles Outbound (sortantes)** :

1. Allez dans le Portail Azure
2. Votre VM → Networking → Network Security Group
3. Onglet **Outbound security rules**
4. Vérifiez qu'il existe une règle permettant le trafic sortant

**Règle requise** :
- **Destination** : Internet
- **Destination port ranges** : * (ou 53,80,443)
- **Protocol** : Any
- **Action** : Allow
- **Priority** : < 65000

> **Note** : Par défaut, Azure autorise tout le trafic sortant avec une règle `AllowInternetOutBound` (priority 65001)

#### 4.2. Vérifier qu'il n'y a pas de Route Table restrictive

1. Portail Azure → Votre VM → Networking
2. Vérifiez qu'il n'y a pas de **Route Table** qui bloque le trafic Internet
3. Une route par défaut `0.0.0.0/0 → Internet` doit exister

#### 4.3. Vérifier la Subnet

Vérifiez que la subnet de votre VM a bien accès à Internet (pas isolée dans un VNet privé sans NAT Gateway ou sans IP publique).

---

### Solution 5 : Redémarrer la VM

Parfois un simple redémarrage résout les problèmes de configuration réseau :

```bash
sudo reboot
```

Après redémarrage, testez :

```bash
ping -c 3 8.8.8.8
nslookup github.com
curl -I https://github.com
```

---

## Tests de Validation

Une fois le DNS corrigé, validez avec ces commandes :

```bash
# Test 1 : Ping vers IP publique (devrait fonctionner)
ping -c 3 8.8.8.8

# Test 2 : Résolution DNS (devrait afficher l'IP de github.com)
nslookup github.com

# Test 3 : Résolution avec dig
dig github.com

# Test 4 : Accès HTTPS
curl -I https://github.com

# Test 5 : Helm repo update (devrait fonctionner maintenant)
helm repo update
```

Si **tous ces tests passent**, relancez l'installation :

```bash
cd ~/infra
minikube delete
./script-init-prod-env
```

---

## Causes Courantes du Problème DNS sur Azure

1. **systemd-resolved mal configuré** → Solution 1
2. **Netplan sans nameservers** → Solution 3
3. **NSG bloquant le trafic sortant** → Solution 4.1
4. **Route Table sans route Internet** → Solution 4.2
5. **Subnet isolée sans accès Internet** → Solution 4.3
6. **DHCP Azure ne fournit pas de DNS** → Solutions 1 ou 3

---

## Support

Si aucune de ces solutions ne fonctionne, partagez le résultat de :

```bash
cd ~/infra
./diagnose-network.sh > diagnostic.txt 2>&1

# Puis affichez et partagez :
cat diagnostic.txt
```

Cela permettra d'identifier précisément le problème.
