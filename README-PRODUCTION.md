# 📖 Guide Production - Projet Simon

## 🎯 Objectif

**Workflow automatique:**
```
git push CODE → GitLab CI → Docker Hub → ArgoCD Image Updater → Kubernetes ✅
```

Vous committez le code, tout le reste est automatique!

---

## 📁 Structure et utilité de chaque fichier

### 📂 Dossiers principaux

```
infra/
├── dev/                    ← Environnement développement (skaffold + minikube)
├── prod/                   ← Environnement production (kubectl + ArgoCD)
└── argocd/                 ← Configuration ArgoCD Image Updater
```

### 🔧 Scripts (à exécuter)

| Fichier | Utilité | Quand l'utiliser |
|---------|---------|------------------|
| `script-init-dev-env` | Initialise minikube pour dev (avec k3s remplacé par minikube) | Une fois sur votre machine de dev |
| `script-init-prod-env` | **Initialise cluster prod** (minikube + ArgoCD + Image Updater) | **Une fois pour créer le cluster prod** |
| `deploy-prod.sh` | Déploie les applications (PostgreSQL + API) sur le cluster | **Après init, ou pour redéployer les apps** |
| `script-redeploy-prod.sh` | **Redéploie TOUT sur un nouveau cluster** (init + secrets + deploy) | **Sur une nouvelle machine/cluster** |

### 📄 Fichiers de config

| Fichier | Utilité |
|---------|---------|
| `gitlab-ci-example.yml` | Exemple de pipeline GitLab CI à copier dans le repo `api-capteur` |
| `argocd/image-updater-config.yaml` | Config pour qu'Image Updater surveille Docker Hub |

### 📚 Documentation

| Fichier | Contenu |
|---------|---------|
| `README-PRODUCTION.md` | **CE FICHIER** - Guide complet |
| `INFRASTRUCTURE.md` | Doc existante (à garder) |
| `README.md` | README original du projet |

---

## 🚀 DÉMARRAGE RAPIDE

### Première fois - Setup complet (10 min)

#### 1️⃣ Initialiser le cluster production

```bash
cd /home/erwan/simon/infra
sudo ./script-init-prod-env
```

**Ce script fait:**
- ✅ Installe Docker, Minikube, Helm
- ✅ Crée cluster minikube avec profil `prod` (4 CPU, 8Gi RAM)
- ✅ Installe ArgoCD
- ✅ Installe ArgoCD Image Updater
- ✅ Affiche le password ArgoCD admin

#### 2️⃣ Mettre votre username Docker Hub

Éditer `prod/deployment/api-capteur.yaml` ligne 36:
```yaml
image: VOTRE_USERNAME_DOCKERHUB/api-capteur:v1.0.0
```

Committer:
```bash
git add prod/deployment/api-capteur.yaml
git commit -m "config: docker username"
git push
```

#### 3️⃣ Build et push image initiale

```bash
cd /home/erwan/simon/APIs/api-capteur
docker login
docker build -t VOTRE_USERNAME/api-capteur:v1.0.0 .
docker push VOTRE_USERNAME/api-capteur:v1.0.0
```

#### 4️⃣ Créer les secrets

```bash
minikube profile prod

kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD='MOT_DE_PASSE_SECURISE' \
  --from-literal=ROOT_PASSWORD='MOT_DE_PASSE_ROOT_SECURISE'
```

#### 5️⃣ Déployer les applications

```bash
cd /home/erwan/simon/infra
./deploy-prod.sh
```

**Ce script fait:**
- ✅ Vérifie que vous êtes sur profil `prod`
- ✅ Vérifie que les secrets existent
- ✅ Déploie PostgreSQL
- ✅ Déploie API Capteur
- ✅ Configure Image Updater pour surveiller Docker Hub

#### 6️⃣ Configurer GitLab CI

**a) Copier le pipeline dans le repo api-capteur:**

```bash
cp /home/erwan/simon/infra/gitlab-ci-example.yml \
   /home/erwan/simon/APIs/api-capteur/.gitlab-ci.yml
```

**b) Dans GitLab (`https://iut-git.unice.fr/simon/api-capteur`):**

Settings → CI/CD → Variables → Add variable

| Variable | Value | Masked |
|----------|-------|--------|
| DOCKER_USERNAME | votre_username_dockerhub | Non |
| DOCKER_PASSWORD | votre_password_dockerhub | Oui ✅ |

**c) Committer le .gitlab-ci.yml:**

```bash
cd /home/erwan/simon/APIs/api-capteur
git add .gitlab-ci.yml
git commit -m "ci: add gitlab ci pipeline"
git push
```

### ✅ C'est terminé!

Maintenant, **à chaque fois que vous faites `git push` dans api-capteur:**
1. GitLab CI build l'image
2. GitLab CI push vers Docker Hub avec la version du `package.json`
3. Image Updater détecte la nouvelle image (2-5 min)
4. Kubernetes redémarre les pods avec la nouvelle image

**Vous ne faites RIEN d'autre!** 🎉

---

## 🔄 Redéployer sur un nouveau cluster

Si vous changez de machine ou voulez recréer le cluster:

```bash
cd /home/erwan/simon/infra
./script-redeploy-prod.sh
```

Ce script fait TOUT:
- Init cluster
- Demande les secrets
- Déploie les apps
- Configure Image Updater

---

## 📊 Accéder aux services

### API Capteur
```bash
kubectl port-forward svc/api-capteur-service 3000:3000
# http://localhost:3000
```

### PostgreSQL
```bash
kubectl port-forward svc/postgis 5432:5432
# psql -h localhost -U prod_user -d projet_simon_prod
```

### ArgoCD UI
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# http://localhost:8080
# User: admin
# Password: voir output du script-init-prod-env
```

---

## 🔍 Commandes utiles

### Surveiller

```bash
# Surveiller les pods
kubectl get pods -w

# Logs API Capteur
kubectl logs -l app=api-capteur -f

# Logs Image Updater (pour voir la détection des nouvelles images)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f
```

### Vérifier

```bash
# Quelle image est actuellement déployée?
kubectl get deployment api-capteur-deployment \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# État du cluster
kubectl get pods
kubectl get deployments
kubectl get services
```

### Basculer entre dev et prod

```bash
# Passer en dev
minikube profile default
kubectl config use-context minikube
cd /home/erwan/simon/infra/dev
skaffold dev

# Passer en prod
minikube profile prod
kubectl config use-context prod
kubectl get pods
```

---

## 🐛 Troubleshooting

### Image Updater ne détecte pas les nouvelles images

```bash
# Vérifier les logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=50

# Vérifier les annotations
kubectl get deployment api-capteur-deployment -o yaml | grep argocd-image-updater

# Redémarrer Image Updater
kubectl rollout restart deployment/argocd-image-updater -n argocd
```

### Les pods ne démarrent pas

```bash
# Voir les events
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Décrire le pod
kubectl describe pod <pod-name>

# Logs du pod
kubectl logs <pod-name>
```

### Secret manquant

```bash
# Vérifier
kubectl get secret postgres-secret

# Recréer
kubectl delete secret postgres-secret
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD='new_password' \
  --from-literal=ROOT_PASSWORD='new_root_password'

# Redémarrer les apps
kubectl rollout restart deployment/api-capteur-deployment
kubectl rollout restart statefulset/postgis
```

---

## 📝 Workflow de développement

### Développer une nouvelle feature

1. **Développer localement avec skaffold (dev):**
   ```bash
   minikube profile default
   cd /home/erwan/simon/infra/dev
   skaffold dev
   ```

2. **Modifier le code dans `api-capteur`**

3. **Tester localement** (skaffold hot reload automatique)

4. **Quand c'est prêt, incrémenter la version:**
   ```bash
   # Dans package.json
   "version": "1.0.1"  # était 1.0.0
   ```

5. **Commit + push:**
   ```bash
   git add .
   git commit -m "feat: nouvelle fonctionnalité"
   git push
   ```

6. **GitLab CI fait le reste!**
   - Build l'image avec tag `1.0.1`
   - Push vers Docker Hub
   - Image Updater détecte et met à jour prod automatiquement

---

## ⚙️ Configuration avancée

### Changer la stratégie de mise à jour

Par défaut: `semver:~1.0` (mises à jour mineures: 1.0.x)

Pour toujours la dernière version (pas recommandé):
```bash
kubectl annotate deployment api-capteur-deployment \
  argocd-image-updater.argoproj.io/api-capteur.update-strategy=latest \
  --overwrite
```

Pour uniquement les patchs:
```bash
kubectl annotate deployment api-capteur-deployment \
  argocd-image-updater.argoproj.io/api-capteur.update-strategy=semver:~1.0.0 \
  --overwrite
```

### Rollback si problème

```bash
# Voir l'historique
kubectl rollout history deployment/api-capteur-deployment

# Rollback à la version précédente
kubectl rollout undo deployment/api-capteur-deployment

# Ou à une version spécifique
kubectl rollout undo deployment/api-capteur-deployment --to-revision=2
```

---

## 🎯 Résumé

### Ce qui est automatique ✅
- Build des images (GitLab CI)
- Push vers Docker Hub (GitLab CI)
- Détection des nouvelles images (Image Updater)
- Mise à jour des déploiements (Image Updater)
- Rolling update des pods (Kubernetes)

### Ce que vous faites 👨‍💻
- Développer le code
- `git push`
- C'est tout!

### Fichiers importants à retenir 📌
- **`script-init-prod-env`** - Setup initial du cluster (1 fois)
- **`deploy-prod.sh`** - Déployer les apps (1 fois ou après modifs manifests)
- **`script-redeploy-prod.sh`** - Tout redéployer sur nouveau cluster
- **`gitlab-ci-example.yml`** - Pipeline CI à copier dans api-capteur

---

**Besoin d'aide?** Relisez ce fichier, tout y est! 📖
