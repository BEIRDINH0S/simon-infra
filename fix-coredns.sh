#!/bin/bash

echo "======================================"
echo "Correction DNS dans Kubernetes (CoreDNS)"
echo "======================================"
echo ""

echo "Ce script va :"
echo "  1. Modifier la ConfigMap CoreDNS pour utiliser les DNS publics"
echo "  2. Redémarrer les pods CoreDNS"
echo "  3. Tester que le DNS fonctionne dans les pods"
echo "  4. Supprimer les pods en ImagePullBackOff pour qu'ils se relancent"
echo ""
read -p "Voulez-vous continuer ? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

echo ""
echo "1. Sauvegarde de la ConfigMap CoreDNS actuelle"
echo "------------------------------------------------"
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup.yaml
echo "✓ Sauvegarde créée : /tmp/coredns-backup.yaml"
echo ""

echo "2. Modification de la ConfigMap CoreDNS"
echo "------------------------------------------------"
kubectl get configmap coredns -n kube-system -o yaml | \
sed 's/forward . \/etc\/resolv.conf/forward . 8.8.8.8 8.8.4.4 1.1.1.1/' | \
kubectl apply -f -

echo "✓ CoreDNS configuré pour utiliser 8.8.8.8, 8.8.4.4, 1.1.1.1"
echo ""

echo "3. Redémarrage des pods CoreDNS"
echo "------------------------------------------------"
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=60s
echo "✓ CoreDNS redémarré"
echo ""

echo "4. Attente que CoreDNS soit prêt (10 secondes)"
echo "------------------------------------------------"
sleep 10
echo "✓ Pause terminée"
echo ""

echo "5. Test DNS depuis un pod temporaire"
echo "------------------------------------------------"
echo "Test 1 : Résolution de github.com"
kubectl run dns-test --image=busybox --rm -i --restart=Never --timeout=15s -- nslookup github.com
DNS_TEST1=$?
echo ""

echo "Test 2 : Résolution de registry-1.docker.io"
kubectl run dns-test2 --image=busybox --rm -i --restart=Never --timeout=15s -- nslookup registry-1.docker.io
DNS_TEST2=$?
echo ""

if [ $DNS_TEST1 -eq 0 ] && [ $DNS_TEST2 -eq 0 ]; then
    echo "✓ DNS fonctionne dans les pods !"
    echo ""

    echo "6. Suppression des pods en ImagePullBackOff"
    echo "------------------------------------------------"
    echo "Liste des pods à supprimer :"
    kubectl get pods -A | grep -E "ImagePullBackOff|ErrImagePull"
    echo ""

    read -p "Voulez-vous supprimer ces pods pour qu'ils se relancent ? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Supprimer les pods en erreur dans argocd
        kubectl get pods -n argocd -o json | \
        jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason | test("ImagePullBackOff|ErrImagePull")) | .metadata.name' | \
        xargs -r kubectl delete pod -n argocd

        # Supprimer les pods en erreur dans monitoring
        kubectl get pods -n monitoring -o json | \
        jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason | test("ImagePullBackOff|ErrImagePull")) | .metadata.name' | \
        xargs -r kubectl delete pod -n monitoring

        # Supprimer les pods en erreur dans ingress-nginx
        kubectl get pods -n ingress-nginx -o json | \
        jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason | test("ImagePullBackOff|ErrImagePull")) | .metadata.name' | \
        xargs -r kubectl delete pod -n ingress-nginx

        echo "✓ Pods supprimés, Kubernetes va les recréer automatiquement"
        echo ""

        echo "7. Attente que les nouveaux pods démarrent (30 secondes)"
        echo "------------------------------------------------"
        sleep 30
        echo ""

        echo "8. Vérification des pods"
        echo "------------------------------------------------"
        kubectl get pods -A | grep -v "Running\|Completed"
        echo ""

        echo "✓ Si vous voyez encore des ImagePullBackOff, attendez 1-2 minutes"
        echo "  Les images prennent du temps à télécharger"
        echo ""
        echo "Surveillez avec : watch kubectl get pods -A"
    fi
else
    echo "✗ DNS ne fonctionne toujours pas dans les pods"
    echo ""
    echo "Problème persistant. Essayez :"
    echo "  1. Vérifier que /etc/resolv.conf sur l'hôte fonctionne : cat /etc/resolv.conf"
    echo "  2. Redémarrer Minikube : minikube stop && minikube start"
    echo "  3. Vérifier les logs CoreDNS : kubectl logs -n kube-system -l k8s-app=kube-dns"
fi

echo ""
echo "======================================"
echo "Terminé"
echo "======================================"
echo ""
