#!/bin/bash

echo "======================================"
echo "Vérification Déploiement Kubernetes"
echo "======================================"
echo ""

# Couleurs pour le terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "1. NAMESPACES"
echo "======================================"
kubectl get namespaces
echo ""

echo "2. PODS - INGRESS-NGINX"
echo "======================================"
kubectl get pods -n ingress-nginx
echo ""
NGINX_PODS=$(kubectl get pods -n ingress-nginx --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$NGINX_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ nginx-ingress a $NGINX_PODS pod(s) en running${NC}"
else
    echo -e "${RED}✗ Aucun pod nginx-ingress en running${NC}"
fi
echo ""

echo "3. PODS - ARGOCD"
echo "======================================"
kubectl get pods -n argocd
echo ""
ARGOCD_PODS=$(kubectl get pods -n argocd --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
ARGOCD_TOTAL=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
echo -e "ArgoCD : ${GREEN}$ARGOCD_PODS${NC} / $ARGOCD_TOTAL pods en running"
echo ""

echo "4. PODS - MONITORING (Prometheus & Grafana)"
echo "======================================"
kubectl get pods -n monitoring
echo ""
MONITORING_PODS=$(kubectl get pods -n monitoring --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
MONITORING_TOTAL=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l)
echo -e "Monitoring : ${GREEN}$MONITORING_PODS${NC} / $MONITORING_TOTAL pods en running"
echo ""

echo "5. SERVICES - INGRESS-NGINX"
echo "======================================"
kubectl get svc -n ingress-nginx
echo ""

echo "6. SERVICES - ARGOCD"
echo "======================================"
kubectl get svc -n argocd
echo ""

echo "7. SERVICES - MONITORING"
echo "======================================"
kubectl get svc -n monitoring
echo ""

echo "8. INGRESS RESOURCES (tous namespaces)"
echo "======================================"
kubectl get ingress -A
echo ""
INGRESS_COUNT=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
echo -e "Total Ingress configurés : ${GREEN}$INGRESS_COUNT${NC}"
echo ""

echo "9. DÉTAILS INGRESS (avec adresses)"
echo "======================================"
kubectl get ingress -A -o wide
echo ""

echo "10. VÉRIFICATION DES PORTS (nginx-ingress sur l'hôte)"
echo "======================================"
echo "Ports en écoute sur l'hôte (80 et 443) :"
sudo ss -tulpn | grep -E ':(80|443) '
echo ""
PORT_80=$(sudo ss -tulpn | grep -E ':80 ' | grep -c LISTEN)
PORT_443=$(sudo ss -tulpn | grep -E ':443 ' | grep -c LISTEN)

if [ "$PORT_80" -gt 0 ]; then
    echo -e "${GREEN}✓ Port 80 en écoute${NC}"
else
    echo -e "${RED}✗ Port 80 n'est PAS en écoute${NC}"
fi

if [ "$PORT_443" -gt 0 ]; then
    echo -e "${GREEN}✓ Port 443 en écoute${NC}"
else
    echo -e "${RED}✗ Port 443 n'est PAS en écoute${NC}"
fi
echo ""

echo "11. LOGS NGINX-INGRESS (dernières 20 lignes)"
echo "======================================"
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20
echo ""

echo "12. CREDENTIALS ARGOCD"
echo "======================================"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [ -n "$ARGOCD_PASSWORD" ]; then
    echo -e "${GREEN}✓ Mot de passe ArgoCD récupéré${NC}"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
else
    echo -e "${RED}✗ Impossible de récupérer le mot de passe ArgoCD${NC}"
fi
echo ""

echo "13. TEST CONNECTIVITÉ INTERNE (curl depuis un pod temporaire)"
echo "======================================"
echo "Test de connexion vers nginx-ingress depuis l'intérieur du cluster..."
kubectl run test-curl --image=curlimages/curl --rm -i --restart=Never --timeout=10s -- curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local 2>/dev/null || echo "Test échoué ou timeout"
echo ""

echo "14. RÉSUMÉ"
echo "======================================"
echo ""
if [ "$NGINX_PODS" -gt 0 ] && [ "$PORT_80" -gt 0 ] && [ "$PORT_443" -gt 0 ]; then
    echo -e "${GREEN}✓ nginx-ingress : OK${NC}"
else
    echo -e "${RED}✗ nginx-ingress : PROBLÈME${NC}"
fi

if [ "$ARGOCD_PODS" -ge 5 ]; then
    echo -e "${GREEN}✓ ArgoCD : OK (tous les pods running)${NC}"
elif [ "$ARGOCD_PODS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ ArgoCD : EN COURS (certains pods encore en démarrage)${NC}"
else
    echo -e "${RED}✗ ArgoCD : PROBLÈME${NC}"
fi

if [ "$MONITORING_PODS" -ge 10 ]; then
    echo -e "${GREEN}✓ Monitoring : OK${NC}"
elif [ "$MONITORING_PODS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Monitoring : EN COURS (certains pods encore en démarrage)${NC}"
else
    echo -e "${RED}✗ Monitoring : PROBLÈME${NC}"
fi

if [ "$INGRESS_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✓ Ingress : OK ($INGRESS_COUNT configurés)${NC}"
else
    echo -e "${YELLOW}⚠ Ingress : Seulement $INGRESS_COUNT configuré(s)${NC}"
fi
echo ""

echo "======================================"
echo "ACCÈS AUX SERVICES"
echo "======================================"
echo ""
echo "🔧 ArgoCD :"
echo "   URL externe : http://simon-prod.uksouth.cloudapp.azure.com/argocd"
echo "   Username    : admin"
if [ -n "$ARGOCD_PASSWORD" ]; then
    echo "   Password    : $ARGOCD_PASSWORD"
fi
echo ""
echo "📊 Prometheus :"
echo "   URL externe : http://simon-prod.uksouth.cloudapp.azure.com/prometheus"
echo ""
echo "📈 Grafana :"
echo "   URL externe : http://simon-prod.uksouth.cloudapp.azure.com/grafana"
echo "   Username    : admin"
echo "   Password    : admin"
echo ""
echo "⚠️  Si les services ne sont pas encore accessibles depuis l'extérieur :"
echo "   - Attendez que tous les pods soient en Running (peut prendre 2-5 min)"
echo "   - Vérifiez le NSG Azure autorise les ports 80/443"
echo "   - Testez depuis la VM : curl -H 'Host: simon-prod.uksouth.cloudapp.azure.com' http://localhost/argocd"
echo ""

echo "======================================"
echo "COMMANDES UTILES"
echo "======================================"
echo ""
echo "# Voir les événements (troubleshooting)"
echo "kubectl get events -n ingress-nginx --sort-by='.lastTimestamp' | tail -20"
echo ""
echo "# Voir les logs d'un pod spécifique"
echo "kubectl logs -n argocd <nom-du-pod>"
echo ""
echo "# Voir tous les pods en temps réel"
echo "watch kubectl get pods -A"
echo ""
echo "# Redémarrer un pod qui pose problème"
echo "kubectl delete pod <nom-du-pod> -n <namespace>"
echo ""
