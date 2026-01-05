#!/bin/bash

# Script de déploiement simplifié pour production
# Utilisation: ./deploy-prod.sh

set -e

echo "=== Déploiement Production - Projet Simon ==="
echo

# Vérifier qu'on est sur le bon profil
CURRENT_PROFILE=$(minikube profile)
if [ "$CURRENT_PROFILE" != "prod" ]; then
    echo "❌ Erreur: Vous n'êtes pas sur le profil 'prod'"
    echo "   Profil actuel: $CURRENT_PROFILE"
    echo "   Exécutez: minikube profile prod"
    exit 1
fi

echo "✓ Profil minikube: prod"
echo

# Vérifier que les secrets existent
if ! kubectl get secret postgres-secret &>/dev/null; then
    echo "❌ Erreur: Le secret 'postgres-secret' n'existe pas"
    echo "   Créez-le avec:"
    echo "   kubectl create secret generic postgres-secret \\"
    echo "     --from-literal=POSTGRES_PASSWORD='votre_password' \\"
    echo "     --from-literal=ROOT_PASSWORD='votre_root_password'"
    exit 1
fi

echo "✓ Secret postgres-secret existe"
echo

# Demander confirmation
read -p "Déployer en production? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

echo "=== Déploiement PostgreSQL ==="
kubectl apply -f prod/configmap/postgres.yaml
kubectl apply -f prod/statefulset/postgres.yaml
kubectl apply -f prod/service/postgres.yaml
echo "✓ PostgreSQL déployé"
echo

echo "=== Déploiement API Capteur ==="
kubectl apply -f prod/configmap/api-capteur.yaml
kubectl apply -f prod/deployment/api-capteur.yaml
kubectl apply -f prod/service/api-capteur.yaml
echo "✓ API Capteur déployé"
echo

echo "=== Configuration Image Updater ==="
kubectl apply -f argocd/image-updater-config.yaml

# Annoter le deployment pour Image Updater
echo "Configuration des annotations Image Updater..."
DOCKER_USERNAME=$(grep -oP 'image:\s*\K[^/]+' prod/deployment/api-capteur.yaml | head -1)
kubectl annotate deployment api-capteur-deployment \
  argocd-image-updater.argoproj.io/image-list=api-capteur=${DOCKER_USERNAME}/api-capteur \
  argocd-image-updater.argoproj.io/api-capteur.update-strategy=semver:~1.0 \
  argocd-image-updater.argoproj.io/write-back-method=argocd \
  --overwrite

echo "✓ Image Updater configuré"
echo

echo "=== État du déploiement ==="
kubectl get pods
echo

echo "=== Déploiement terminé! ==="
echo
echo "Pour surveiller les pods:"
echo "  kubectl get pods -w"
echo
echo "Pour voir les logs API Capteur:"
echo "  kubectl logs -l app=api-capteur -f"
echo
echo "Pour voir les logs Image Updater:"
echo "  kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f"
echo
echo "Pour accéder à l'API:"
echo "  kubectl port-forward svc/api-capteur-service 3000:3000"
echo
