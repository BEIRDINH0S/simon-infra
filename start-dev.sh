#!/bin/bash

echo "======================================"
echo "Démarrage environnement dev Simon"
echo "======================================"

# 1. Démarrer Docker si nécessaire
if ! docker ps &> /dev/null; then
    echo "Démarrage de Docker..."
    sudo service docker start
    sleep 2

    if ! docker ps &> /dev/null; then
        echo "ERREUR: Docker ne démarre pas"
        exit 1
    fi
fi
echo "✓ Docker OK"

# 2. Démarrer Minikube si nécessaire
MINIKUBE_STATUS=$(minikube status -p dev -f '{{.Host}}' 2>/dev/null || echo "Stopped")
if [ "$MINIKUBE_STATUS" != "Running" ]; then
    echo "Démarrage de Minikube avec configuration optimisée..."
    # Attendre que le cluster soit prêt pour éviter les erreurs en chaîne
    minikube start -p dev \
        --driver=docker \
        --container-runtime=docker \
        --cpus=2 \
        --memory=6144 \
        --wait=all --wait-timeout=5m
else
    echo "✓ Minikube déjà démarré"
fi

# 3. Activer le registry Minikube si nécessaire
echo "Configuration du registry Minikube..."
REGISTRY_STATUS=$(minikube addons list -p dev | grep "^| registry " | awk '{print $5}')
if [ "$REGISTRY_STATUS" != "enabled" ]; then
    echo "Activation du registry Minikube..."
    minikube addons enable registry -p dev
    sleep 5
else
    echo "✓ Registry Minikube déjà activé"
fi

# Configurer le port-forward pour le registry
echo "Configuration du port-forward pour le registry..."

# Arrêter l'ancien port-forward s'il existe
if [ -f /tmp/registry-pf.pid ]; then
    OLD_PID=$(cat /tmp/registry-pf.pid)
    if ps -p $OLD_PID > /dev/null 2>&1; then
        kill $OLD_PID 2>/dev/null
    fi
    rm -f /tmp/registry-pf.pid
fi

# Démarrer le port-forward en arrière-plan
kubectl port-forward -n kube-system service/registry 5000:80 > /dev/null 2>&1 &
echo $! > /tmp/registry-pf.pid
sleep 2

# Vérifier que le registry est accessible
echo "Vérification de l'accès au registry..."
if curl -s http://127.0.0.1:5000/v2/_catalog > /dev/null 2>&1; then
    echo "✓ Registry accessible sur 127.0.0.1:5000"
else
    echo "ERREUR: Registry Minikube non accessible"
    exit 1
fi

echo ""
echo "======================================"
echo "Environnement prêt !"
echo "======================================"
echo ""
echo "Pour lancer l'application (depuis le dossier 'infra'):"
echo "  cd dev"
echo "  skaffold dev"
echo ""
