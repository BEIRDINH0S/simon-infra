#!/bin/bash

echo "======================================"
echo "Diagnostic ImagePullBackOff"
echo "======================================"
echo ""

echo "1. Pods en ImagePullBackOff"
echo "------------------------------------------------"
kubectl get pods -A | grep -E "ImagePullBackOff|ErrImagePull"
echo ""

echo "2. Détails d'un pod en erreur (pour voir le message exact)"
echo "------------------------------------------------"
POD_NAME=$(kubectl get pods -n argocd -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' | awk '{print $1}')
if [ -n "$POD_NAME" ]; then
    echo "Analyse du pod : $POD_NAME"
    kubectl describe pod -n argocd "$POD_NAME" | grep -A 10 "Events:"
else
    echo "Pas de pod en Pending dans argocd, cherchons ailleurs..."
    POD_NAME=$(kubectl get pods -n monitoring -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' | awk '{print $1}')
    if [ -n "$POD_NAME" ]; then
        echo "Analyse du pod : $POD_NAME"
        kubectl describe pod -n monitoring "$POD_NAME" | grep -A 10 "Events:"
    fi
fi
echo ""

echo "3. Test DNS depuis un pod temporaire"
echo "------------------------------------------------"
echo "Test de résolution registry-1.docker.io :"
kubectl run dns-test --image=busybox --rm -i --restart=Never --timeout=10s -- nslookup registry-1.docker.io 2>&1 || echo "✗ DNS échoue dans les pods"
echo ""

echo "Test de résolution github.com :"
kubectl run dns-test2 --image=busybox --rm -i --restart=Never --timeout=10s -- nslookup github.com 2>&1 || echo "✗ DNS échoue dans les pods"
echo ""

echo "4. Configuration DNS de CoreDNS"
echo "------------------------------------------------"
kubectl get configmap coredns -n kube-system -o yaml | grep -A 20 "Corefile:"
echo ""

echo "5. Logs CoreDNS"
echo "------------------------------------------------"
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30
echo ""

echo "6. Configuration DNS dans les pods"
echo "------------------------------------------------"
echo "Vérifier le fichier /etc/resolv.conf dans un pod :"
kubectl run check-resolv --image=busybox --rm -i --restart=Never --timeout=10s -- cat /etc/resolv.conf 2>&1 || echo "✗ Impossible de vérifier"
echo ""

echo "======================================"
echo "Diagnostic terminé"
echo "======================================"
echo ""
echo "Si DNS échoue dans les pods, exécutez :"
echo "  ./fix-coredns.sh"
echo ""
