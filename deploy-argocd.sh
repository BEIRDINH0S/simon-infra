#!/bin/bash

# Script de déploiement GitOps avec ArgoCD
# Utilisation: ./deploy-argocd.sh

set -e

echo "=== Déploiement GitOps - Projet Simon ==="
echo

# Vérifier qu'on est sur le bon profil
CURRENT_PROFILE=$(minikube profile 2>/dev/null || echo "none")
if [ "$CURRENT_PROFILE" != "prod" ]; then
    echo "❌ Erreur: Vous n'êtes pas sur le profil 'prod'"
    echo "   Profil actuel: $CURRENT_PROFILE"
    echo "   Exécutez: minikube profile prod"
    exit 1
fi

echo "✓ Profil minikube: prod"
echo

# Vérifier qu'ArgoCD est installé
if ! kubectl get namespace argocd &>/dev/null; then
    echo "❌ Erreur: ArgoCD n'est pas installé"
    echo "   Exécutez d'abord: ./script-init-prod-env"
    exit 1
fi

echo "✓ ArgoCD est installé"
echo

# Vérifier que les secrets Postgres existent
echo "=== Vérification des secrets Postgres ==="
if ! kubectl get secret postgres-secret &>/dev/null; then
    echo "⚠️  Le secret 'postgres-secret' n'existe pas"
    echo
    echo "Pour créer le secret Postgres:"
    echo "1. Copiez le fichier template:"
    echo "   cp prod/secret/postgres-template.yaml prod/secret/postgres-secret.yaml"
    echo
    echo "2. Éditez le fichier et remplacez les valeurs (base64):"
    echo "   nano prod/secret/postgres-secret.yaml"
    echo
    echo "3. Appliquez le secret:"
    echo "   kubectl apply -f prod/secret/postgres-secret.yaml"
    echo
    read -p "Avez-vous créé et appliqué le secret postgres-secret? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Annulé. Créez le secret et relancez ce script."
        exit 0
    fi

    # Vérifier à nouveau
    if ! kubectl get secret postgres-secret &>/dev/null; then
        echo "❌ Le secret postgres-secret n'existe toujours pas"
        exit 1
    fi
fi

echo "✓ Secrets Postgres configurés"
echo

# Demander confirmation
echo "=== Déploiement ArgoCD ==="
echo "Ce script va déployer l'App of Apps qui déploiera automatiquement:"
echo "  - PostgreSQL (StatefulSet)"
echo "  - API Capteur"
echo "  - API Auth User"
echo "  - API Ingestion"
echo "  - API Gateway Client"
echo "  - Frontend"
echo
echo "ArgoCD Image Updater surveillera automatiquement vos images Docker Hub:"
echo "  - beirdinhos/api-capteur:latest"
echo "  - beirdinhos/api-auth-user:latest"
echo "  - beirdinhos/api-ingestion:latest"
echo "  - beirdinhos/api-gateway-client:latest"
echo "  - beirdinhos/frontend:latest"
echo
read -p "Déployer avec ArgoCD? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

echo
echo "=== Déploiement de l'App of Apps ==="
kubectl apply -f argocd/app-of-apps.yaml
echo "✓ App of Apps déployée"
echo

echo "=== Attente de la synchronisation ArgoCD ==="
echo "ArgoCD va maintenant synchroniser toutes les applications..."
echo "Cela peut prendre quelques minutes."
echo

# Attendre que l'application soit créée
sleep 5

echo "=== État des Applications ArgoCD ==="
kubectl get applications -n argocd
echo

echo "=== État des Pods ==="
kubectl get pods
echo

echo "=== Déploiement terminé! ==="
echo
echo "Pour accéder à l'interface ArgoCD:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Puis ouvrez: https://localhost:8080"
echo
echo "Pour voir l'état des applications:"
echo "  kubectl get applications -n argocd"
echo
echo "Pour voir les logs d'ArgoCD Image Updater:"
echo "  kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f"
echo
echo "Pour forcer une synchronisation manuelle:"
echo "  kubectl patch application simon-prod -n argocd --type merge -p '{\"spec\":{\"source\":{\"repoURL\":\"https://iut-git.unice.fr/simon/infra\"}}}'"
echo
echo "ArgoCD Image Updater vérifiera automatiquement les nouvelles images toutes les 2 minutes."
echo "Quand une nouvelle image est détectée sur Docker Hub, elle sera automatiquement déployée."
echo
echo "IMPORTANT: Image Updater surveille le digest SHA256 de vos images 'latest'."
echo "Pour déclencher un redéploiement, poussez une nouvelle image avec le même tag 'latest'."
echo
