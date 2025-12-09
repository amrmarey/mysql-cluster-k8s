#!/bin/bash
# ============================================================================
# MySQL Operator for Kubernetes - Installation Script
# ============================================================================
# Version: 8.4.7-2.1.9 LTS (Long Term Support)
# Documentation: https://dev.mysql.com/doc/mysql-operator/en/
# ============================================================================

set -e

# Configuration
OPERATOR_VERSION="8.4.7-2.1.9"
NAMESPACE="mysql-cluster"
SECRET_NAME="mysql-cluster-secret"

echo "=============================================="
echo " MySQL Operator Installation Script"
echo " Version: ${OPERATOR_VERSION}"
echo "=============================================="

# Step 1: Create the namespace first
echo ""
echo "[1/5] Creating namespace and resource policies..."
kubectl apply -f namespace.yaml

# Step 2: Deploy CRDs (Custom Resource Definitions)
echo ""
echo "[2/5] Installing MySQL Operator CRDs..."
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/${OPERATOR_VERSION}/deploy/deploy-crds.yaml

# Step 3: Deploy the operator itself
echo ""
echo "[3/5] Installing MySQL Operator..."
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/${OPERATOR_VERSION}/deploy/deploy-operator.yaml

# Wait for operator to be ready
echo ""
echo "[4/5] Waiting for MySQL Operator to be ready..."
kubectl -n mysql-operator wait --for=condition=available deployment/mysql-operator --timeout=120s

# Step 4: Create the MySQL cluster secret
echo ""
echo "[5/5] Creating MySQL cluster secret..."
echo "      WARNING: Using generated password. Save it securely!"

# Generate a strong random password
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 24 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*' | fold -w 24 | head -n 1)

# Create secret in the mysql-cluster namespace
kubectl create secret generic ${SECRET_NAME} \
  --namespace=${NAMESPACE} \
  --from-literal=rootUser=root \
  --from-literal=rootHost=% \
  --from-literal=rootPassword="${MYSQL_ROOT_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=============================================="
echo " MySQL Operator installed successfully!"
echo "=============================================="
echo ""
echo "Root Password (SAVE THIS SECURELY):"
echo "  ${MYSQL_ROOT_PASSWORD}"
echo ""
echo "Next steps:"
echo "  1. Deploy network policies: kubectl apply -f network-policy.yaml"
echo "  2. Deploy the cluster:      kubectl apply -f mysql-cluster.yaml"
echo "  3. Monitor the cluster:     kubectl -n ${NAMESPACE} get innodbcluster"
echo "  4. Check pods:              kubectl -n ${NAMESPACE} get pods -w"
echo ""
echo "Connect to MySQL (after cluster is ready):"
echo "  kubectl -n ${NAMESPACE} port-forward svc/mycluster 3306:6446"
echo "  mysql -h 127.0.0.1 -P 3306 -u root -p"
echo ""