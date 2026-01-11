#!/bin/bash

echo "======================================"
echo "Correction DNS CoreDNS (Version Simple)"
echo "======================================"
echo ""

echo "1. Modification de CoreDNS pour utiliser DNS publics"
echo "------------------------------------------------"
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup.yaml
echo "✓ Sauvegarde : /tmp/coredns-backup.yaml"

# Créer une nouvelle ConfigMap CoreDNS
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . 8.8.8.8 8.8.4.4 1.1.1.1
        cache 30
        loop
        reload
        loadbalance
    }
EOF

echo "✓ CoreDNS configuré avec DNS publics (8.8.8.8, 8.8.4.4, 1.1.1.1)"
echo ""

echo "2. Redémarrage de CoreDNS"
echo "------------------------------------------------"
kubectl delete pod -n kube-system -l k8s-app=kube-dns
echo "✓ Pods CoreDNS supprimés, redémarrage en cours..."
echo ""

echo "3. Attente que CoreDNS redémarre (15 secondes)"
echo "------------------------------------------------"
sleep 15
kubectl get pods -n kube-system -l k8s-app=kube-dns
echo ""

echo "4. Test DNS"
echo "------------------------------------------------"
kubectl run dns-test --image=busybox --rm -i --restart=Never --timeout=15s -- nslookup github.com
echo ""

echo "5. Suppression des pods en ImagePullBackOff"
echo "------------------------------------------------"
echo "ArgoCD :"
kubectl delete pod -n argocd --field-selector=status.phase=Pending 2>/dev/null || echo "Aucun pod Pending dans argocd"
echo ""
echo "Monitoring :"
kubectl delete pod -n monitoring --field-selector=status.phase=Pending 2>/dev/null || echo "Aucun pod Pending dans monitoring"
echo ""
echo "Ingress-nginx :"
kubectl delete pod -n ingress-nginx --field-selector=status.phase=Pending 2>/dev/null || echo "Aucun pod Pending dans ingress-nginx"
echo ""

echo "✓ Pods supprimés, ils vont redémarrer automatiquement"
echo ""

echo "6. Surveillance des pods (Ctrl+C pour quitter)"
echo "------------------------------------------------"
echo "Attendez que tous les pods passent en Running..."
echo "Cela peut prendre 2-5 minutes selon la vitesse de téléchargement des images"
echo ""
watch -n 3 'kubectl get pods -A | grep -v "Running\|Completed"'
