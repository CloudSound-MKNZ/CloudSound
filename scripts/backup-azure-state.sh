#!/bin/bash
# CloudSound Azure State Backup Script
# This script exports all Kubernetes resources, Helm releases, and Terraform state
# to create a complete backup of the current deployment state

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/azure_backup_${TIMESTAMP}"
NAMESPACE="${NAMESPACE:-cloudsound}"

echo -e "${GREEN}=== CloudSound Azure State Backup ===${NC}"
echo "Backup directory: ${BACKUP_PATH}"
echo "Namespace: ${NAMESPACE}"
echo ""

# Create backup directory structure
mkdir -p "${BACKUP_PATH}"/{kubernetes,helm,terraform,logs,status}

# Check if kubectl is available and connected
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Error: kubectl is not configured or cluster is not accessible${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/6] Exporting Kubernetes resources...${NC}"
# Export all resources from the namespace
kubectl get all -n "${NAMESPACE}" -o yaml > "${BACKUP_PATH}/kubernetes/all-resources.yaml" 2>&1 || true

# Export individual resource types
for resource in deployments statefulsets services configmaps secrets ingress persistentvolumeclaims; do
    echo "  Exporting ${resource}..."
    kubectl get "${resource}" -n "${NAMESPACE}" -o yaml > "${BACKUP_PATH}/kubernetes/${resource}.yaml" 2>&1 || true
done

# Export pods with detailed information
echo "  Exporting pod details..."
kubectl get pods -n "${NAMESPACE}" -o yaml > "${BACKUP_PATH}/kubernetes/pods.yaml" 2>&1 || true

# Export events
echo "  Exporting events..."
kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' > "${BACKUP_PATH}/kubernetes/events.txt" 2>&1 || true

echo -e "${YELLOW}[2/6] Exporting Helm releases...${NC}"
if command -v helm &> /dev/null; then
    helm list -n "${NAMESPACE}" > "${BACKUP_PATH}/helm/releases.txt" 2>&1 || true
    for release in $(helm list -n "${NAMESPACE}" -q 2>/dev/null || true); do
        echo "  Exporting Helm release: ${release}"
        helm get values "${release}" -n "${NAMESPACE}" > "${BACKUP_PATH}/helm/${release}-values.yaml" 2>&1 || true
        helm get manifest "${release}" -n "${NAMESPACE}" > "${BACKUP_PATH}/helm/${release}-manifest.yaml" 2>&1 || true
    done
else
    echo "  Helm not found, skipping Helm exports"
fi

echo -e "${YELLOW}[3/6] Exporting pod logs...${NC}"
for pod in $(kubectl get pods -n "${NAMESPACE}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
    echo "  Exporting logs for pod: ${pod}"
    kubectl logs "${pod}" -n "${NAMESPACE}" --all-containers=true > "${BACKUP_PATH}/logs/${pod}.log" 2>&1 || true
    kubectl logs "${pod}" -n "${NAMESPACE}" --all-containers=true --previous > "${BACKUP_PATH}/logs/${pod}-previous.log" 2>&1 || true
done

echo -e "${YELLOW}[4/6] Exporting current status...${NC}"
# Get detailed status of all pods
kubectl get pods -n "${NAMESPACE}" -o wide > "${BACKUP_PATH}/status/pods-wide.txt" 2>&1 || true
kubectl describe pods -n "${NAMESPACE}" > "${BACKUP_PATH}/status/pods-describe.txt" 2>&1 || true

# Get node information
kubectl get nodes -o wide > "${BACKUP_PATH}/status/nodes.txt" 2>&1 || true

# Get resource usage
kubectl top nodes > "${BACKUP_PATH}/status/node-resources.txt" 2>&1 || true
kubectl top pods -n "${NAMESPACE}" > "${BACKUP_PATH}/status/pod-resources.txt" 2>&1 || true

echo -e "${YELLOW}[5/6] Exporting Terraform state...${NC}"
if [ -d "infrastructure/terraform" ]; then
    cd infrastructure/terraform
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate "${BACKUP_PATH}/../terraform/terraform.tfstate" 2>&1 || true
        echo "  Terraform state file backed up"
    else
        echo "  No local Terraform state file found"
    fi
    
    # Export Terraform outputs if available
    if command -v terraform &> /dev/null && [ -f "terraform.tfstate" ]; then
        terraform output -json > "${BACKUP_PATH}/../terraform/outputs.json" 2>&1 || true
    fi
    cd - > /dev/null
else
    echo "  Terraform directory not found"
fi

echo -e "${YELLOW}[6/6] Creating backup summary...${NC}"
cat > "${BACKUP_PATH}/BACKUP_SUMMARY.txt" <<EOF
CloudSound Azure State Backup Summary
=====================================
Backup Date: $(date)
Namespace: ${NAMESPACE}
Cluster: $(kubectl config current-context 2>/dev/null || echo "unknown")

Resource Counts:
- Deployments: $(kubectl get deployments -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo "0")
- StatefulSets: $(kubectl get statefulsets -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo "0")
- Services: $(kubectl get services -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo "0")
- Pods: $(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo "0")

Pod Status:
$(kubectl get pods -n "${NAMESPACE}" 2>/dev/null || echo "Unable to retrieve pod status")

Issues Detected:
$(kubectl get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{range .status.containerStatuses[*]}{.name}{": "}{.state}{"\n"}{end}{end}' 2>/dev/null | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" || echo "No critical issues detected")

Backup Contents:
- kubernetes/ - All Kubernetes resource manifests
- helm/ - Helm release configurations
- logs/ - Pod logs (current and previous)
- status/ - Current cluster and pod status
- terraform/ - Terraform state and outputs

To restore:
1. Review the exported YAML files in kubernetes/
2. Apply resources: kubectl apply -f kubernetes/
3. Restore Helm releases if needed
EOF

# Create a compressed archive
echo -e "${YELLOW}Creating compressed archive...${NC}"
cd "${BACKUP_DIR}"
tar -czf "azure_backup_${TIMESTAMP}.tar.gz" "azure_backup_${TIMESTAMP}" 2>/dev/null || true
cd - > /dev/null

echo ""
echo -e "${GREEN}✓ Backup completed successfully!${NC}"
echo "Backup location: ${BACKUP_PATH}"
echo "Compressed archive: ${BACKUP_DIR}/azure_backup_${TIMESTAMP}.tar.gz"
echo ""
echo "Backup summary saved to: ${BACKUP_PATH}/BACKUP_SUMMARY.txt"
cat "${BACKUP_PATH}/BACKUP_SUMMARY.txt"

