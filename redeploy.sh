#!/bin/bash
# ============================================================================
# MySQL Cluster Kubernetes - Redeploy Script
# ============================================================================
# Purpose: Clean delete and redeploy the MySQL cluster
# Usage: ./redeploy.sh [--keep-data]
# ============================================================================

set -e

NAMESPACE="mysql-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
KEEP_DATA=false
if [[ "$1" == "--keep-data" ]]; then
    KEEP_DATA=true
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  MySQL Cluster Kubernetes - Redeploy${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Step 1: Delete existing resources
echo -e "${YELLOW}[1/5] Deleting existing MySQL cluster resources...${NC}"
kubectl delete -f "${SCRIPT_DIR}/mysql-cluster.yaml" -n ${NAMESPACE} --ignore-not-found 2>/dev/null || true
kubectl delete -f "${SCRIPT_DIR}/service.yaml" -n ${NAMESPACE} --ignore-not-found 2>/dev/null || true
kubectl delete -f "${SCRIPT_DIR}/secret.yaml" -n ${NAMESPACE} --ignore-not-found 2>/dev/null || true
kubectl delete -f "${SCRIPT_DIR}/network-policy.yaml" -n ${NAMESPACE} --ignore-not-found 2>/dev/null || true
echo -e "${GREEN}✓ Resources deleted${NC}"

# Step 2: Delete PVCs (optional)
if [[ "$KEEP_DATA" == false ]]; then
    echo -e "${YELLOW}[2/5] Deleting PersistentVolumeClaims (fresh start)...${NC}"
    kubectl delete pvc --all -n ${NAMESPACE} --ignore-not-found 2>/dev/null || true
    echo -e "${GREEN}✓ PVCs deleted${NC}"
else
    echo -e "${YELLOW}[2/5] Keeping existing PersistentVolumeClaims (--keep-data)${NC}"
fi

# Step 3: Wait for cleanup
echo -e "${YELLOW}[3/5] Waiting for resources to be cleaned up...${NC}"
sleep 10
echo -e "${GREEN}✓ Cleanup complete${NC}"

# Step 4: Redeploy
echo -e "${YELLOW}[4/5] Deploying MySQL cluster resources...${NC}"

echo "  → Applying namespace..."
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

echo "  → Applying secrets..."
kubectl apply -f "${SCRIPT_DIR}/secret.yaml"

echo "  → Applying network policies..."
kubectl apply -f "${SCRIPT_DIR}/network-policy.yaml"

echo "  → Applying services..."
kubectl apply -f "${SCRIPT_DIR}/service.yaml"

echo "  → Applying MySQL cluster..."
kubectl apply -f "${SCRIPT_DIR}/mysql-cluster.yaml"

echo -e "${GREEN}✓ All resources deployed${NC}"

# Step 5: Show status
echo -e "${YELLOW}[5/5] Checking deployment status...${NC}"
echo ""
echo -e "${BLUE}Pods:${NC}"
kubectl get pods -n ${NAMESPACE}
echo ""
echo -e "${BLUE}Services:${NC}"
kubectl get svc -n ${NAMESPACE}
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Deployment complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "To watch pod status: ${YELLOW}kubectl get pods -n ${NAMESPACE} -w${NC}"
echo -e "To view logs: ${YELLOW}kubectl logs -f <pod-name> -n ${NAMESPACE}${NC}"
