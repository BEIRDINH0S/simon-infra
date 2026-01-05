#!/bin/bash

# Script de redéploiement complet sur un nouveau cluster
# Usage: ./script-redeploy-prod.sh

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║   Redéploiement Production - Projet Simon            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

# Vérifier qu'on est dans le bon dossier
if [ ! -f "script-init-prod-env" ]; then
    echo "❌ Erreur: Exécutez ce script depuis /home/erwan/simon/infra"
    exit 1
fi

# Demander confirmation
read -p "⚠️  Voulez-vous redéployer sur un nouveau cluster prod? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

# Étape 1: Initialisation du cluster
echo
echo "════════════════════════════════════════════════════════"
echo "  Étape 1/3: Initialisation du cluster"
echo "════════════════════════════════════════════════════════"
echo

if ! command -v minikube &> /dev/null; then
    echo "⚠️  Minikube n'est pas installé. Lancement de script-init-prod-env..."
    sudo ./script-init-prod-env
else
    # Vérifier si le cluster prod existe déjà
    if minikube profile list 2>/dev/null | grep -q "prod"; then
        read -p "⚠️  Le profil 'prod' existe déjà. Le supprimer? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            minikube delete --profile prod
            sudo ./script-init-prod-env
        else
            echo "Utilisation du cluster existant..."
            minikube profile prod
        fi
    else
        sudo ./script-init-prod-env
    fi
fi

echo "✅ Cluster initialisé"

# Étape 2: Création des secrets
echo
echo "════════════════════════════════════════════════════════"
echo "  Étape 2/3: Création des secrets"
echo "════════════════════════════════════════════════════════"
echo

# Vérifier si les secrets existent déjà
if kubectl get secret postgres-secret &>/dev/null; then
    read -p "⚠️  Le secret 'postgres-secret' existe déjà. Le recréer? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret postgres-secret
    else
        echo "✅ Utilisation du secret existant"
        SKIP_SECRETS=true
    fi
fi

if [ "$SKIP_SECRETS" != "true" ]; then
    echo "Création du secret PostgreSQL..."
    echo
    echo "Entrez le mot de passe PostgreSQL (sera masqué):"
    read -s POSTGRES_PASSWORD
    echo
    echo "Entrez le mot de passe root DB (sera masqué):"
    read -s ROOT_PASSWORD
    echo

    kubectl create secret generic postgres-secret \
      --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
      --from-literal=ROOT_PASSWORD="$ROOT_PASSWORD"

    echo "✅ Secret créé"
fi

# Étape 3: Déploiement des applications
echo
echo "════════════════════════════════════════════════════════"
echo "  Étape 3/3: Déploiement des applications"
echo "════════════════════════════════════════════════════════"
echo

if [ -f "deploy-prod.sh" ]; then
    ./deploy-prod.sh
else
    echo "⚠️  deploy-prod.sh non trouvé, déploiement manuel..."

    echo "Déploiement PostgreSQL..."
    kubectl apply -f prod/configmap/postgres.yaml
    kubectl apply -f prod/statefulset/postgres.yaml
    kubectl apply -f prod/service/postgres.yaml

    echo "Déploiement API Capteur..."
    kubectl apply -f prod/configmap/api-capteur.yaml
    kubectl apply -f prod/deployment/api-capteur.yaml
    kubectl apply -f prod/service/api-capteur.yaml

    echo "Configuration Image Updater..."
    kubectl apply -f argocd/image-updater-config.yaml

    # Annoter le deployment
    DOCKER_USERNAME=$(grep -oP 'image:\s*\K[^/]+' prod/deployment/api-capteur.yaml | head -1)
    kubectl annotate deployment api-capteur-deployment \
      argocd-image-updater.argoproj.io/image-list=api-capteur=${DOCKER_USERNAME}/api-capteur \
      argocd-image-updater.argoproj.io/api-capteur.update-strategy=semver:~1.0 \
      argocd-image-updater.argoproj.io/write-back-method=argocd \
      --overwrite 2>/dev/null || true

    echo "✅ Applications déployées"
fi

# Récapitulatif
echo
echo "╔════════════════════════════════════════════════════════╗"
echo "║           Redéploiement terminé avec succès!          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo
echo "📊 État du cluster:"
kubectl get pods
echo
echo "📋 Informations utiles:"
echo
echo "  ArgoCD UI:"
echo "    kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "    URL: http://localhost:8080"
echo "    User: admin"
echo "    Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "voir commande ci-dessous")"
echo
echo "  Grafana:"
echo "    kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80"
echo "    URL: http://localhost:3001"
echo "    User: admin / Password: admin"
echo
echo "  API Capteur:"
echo "    kubectl port-forward svc/api-capteur-service 3000:3000"
echo "    URL: http://localhost:3000"
echo
echo "🔍 Surveiller:"
echo "  kubectl get pods -w"
echo "  kubectl logs -l app=api-capteur -f"
echo "  kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f"
echo
echo "✨ Le cluster surveille maintenant Docker Hub."
echo "   Toute nouvelle image sera déployée automatiquement!"
echo
