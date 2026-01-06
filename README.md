# Infrastructure Projet Simon

Infrastructure Kubernetes pour le projet Simon avec support dev et prod.

## Prérequis
- WSL (Windows Subsystem for Linux)
- Ubuntu Server 24.04 dans WSL
- Docker
- Minikube
- Kubectl

---

## Environnement de développement

### Installation initiale

#### 1. Connexion en tant que root
```bash
sudo su - root
```

#### 2. Création du dossier de travail
```bash
mkdir simon
cd simon
```

#### 3. Récupération du dépôt
```bash
git config --global credential.helper "cache --timeout=3600"
git clone https://iut-git.unice.fr/simon/infra
```

#### 4. Lancement du script d'installation dev
```bash
chmod +x ./infra/script-init-dev-env
./infra/script-init-dev-env
```

Le script installe :
- Docker
- Minikube (profil dev)
- Kubectl
- Skaffold pour le développement continu

---

## Environnement de production (ArgoCD)

### Installation de l'environnement prod

#### 1. Initialisation de l'environnement prod
```bash
chmod +x ./infra/script-init-prod-env
./infra/script-init-prod-env
```

Ce script installe :
- Minikube (profil prod)
- Helm
- ArgoCD
- ArgoCD Image Updater

#### 2. Accéder à l'interface ArgoCD
```bash
# Récupérer le mot de passe admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward pour accéder à l'UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Ouvrir https://localhost:8080
- Username: `admin`
- Password: [celui récupéré ci-dessus]

### Déploiement avec ArgoCD

#### 1. Créer le secret PostgreSQL
```bash
# Copier le template
cp prod/secret/postgres-template.yaml prod/secret/postgres-secret.yaml

# Éditer et ajouter vos mots de passe (en base64)
nano prod/secret/postgres-secret.yaml

# Appliquer le secret
kubectl apply -f prod/secret/postgres-secret.yaml
```

#### 2. Déployer les applications
```bash
chmod +x ./infra/deploy-argocd.sh
./infra/deploy-argocd.sh
```

Ce script déploie l'App of Apps qui créera automatiquement toutes les applications :
- PostgreSQL (StatefulSet)
- API Capteur
- API Auth User
- API Ingestion
- API Gateway Client
- Frontend

### ArgoCD Image Updater

ArgoCD Image Updater surveille automatiquement vos images Docker Hub :
- `beirdinhos/api-capteur:latest`
- `beirdinhos/api-auth-user:latest`
- `beirdinhos/api-ingestion:latest`
- `beirdinhos/api-gateway-client:latest`
- `beirdinhos/frontend:latest`

**Comment ça fonctionne :**
1. Vous poussez une nouvelle image sur Docker Hub avec le tag `latest`
2. Image Updater détecte le changement (vérifie toutes les 2 minutes)
3. ArgoCD redéploie automatiquement avec la nouvelle image

**Voir les logs Image Updater :**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f
```

---

## Commandes utiles

### Gestion des profils Minikube
```bash
# Lister les profils
minikube profile list

# Changer de profil
minikube profile dev    # pour dev
minikube profile prod   # pour prod
```

### ArgoCD
```bash
# Voir toutes les applications
kubectl get applications -n argocd

# Voir l'état d'une application
kubectl describe application simon-prod -n argocd

# Forcer une synchronisation
kubectl patch application simon-prod -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'

# Voir les logs ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

### Monitoring des pods
```bash
# Voir tous les pods
kubectl get pods

# Voir les pods en temps réel
kubectl get pods -w

# Logs d'un pod spécifique
kubectl logs -l app=api-capteur -f
```

---

## Architecture

### Environnement Dev
- Utilise Skaffold pour le développement continu
- Images locales via registry minikube
- Hot-reload automatique

### Environnement Prod
- GitOps avec ArgoCD
- Images depuis Docker Hub
- Déploiement automatique avec Image Updater
- Monitoring et observabilité




