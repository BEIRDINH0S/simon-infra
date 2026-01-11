# Configuration HTTPS avec Let's Encrypt

Ce dossier contient la configuration pour activer HTTPS automatique sur tous les ingress.

## Installation sur le serveur

### 1. Installer cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.1/cert-manager.yaml

# Attendre que cert-manager soit prêt
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
```

### 2. Appliquer la configuration Let's Encrypt
```bash
cd ~/simon-infra
git pull origin main

# Appliquer le ClusterIssuer et les middlewares
kubectl apply -f prod/cert-manager/

# Vérifier que le ClusterIssuer est prêt
kubectl get clusterissuer letsencrypt-prod
```

### 3. Les certificats seront générés automatiquement
ArgoCD va synchroniser les ingress modifiés, et cert-manager va automatiquement:
- Générer les certificats SSL pour chaque ingress
- Les stocker dans les secrets (frontend-tls-cert, api-gateway-tls-cert, argocd-server-tls-cert)
- Les renouveler automatiquement tous les 60 jours

### 4. Vérifier les certificats
```bash
# Voir les certificats générés
kubectl get certificate -n default
kubectl get certificate -n argocd

# Voir les détails d'un certificat
kubectl describe certificate frontend-tls-cert -n default

# Voir les logs de cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

### 5. Tester HTTPS
- Frontend: https://simon-prod.uksouth.cloudapp.azure.com/
- API Gateway: https://simon-prod.uksouth.cloudapp.azure.com/api/
- ArgoCD: https://simon-prod.uksouth.cloudapp.azure.com/argocd

Le HTTP sera automatiquement redirigé vers HTTPS.

## Dépannage

Si un certificat ne se génère pas:
```bash
# Voir les challenges ACME en cours
kubectl get challenges -A

# Voir les ordres de certificat
kubectl get certificaterequest -A

# Logs détaillés de cert-manager
kubectl logs -n cert-manager deploy/cert-manager -f
```
