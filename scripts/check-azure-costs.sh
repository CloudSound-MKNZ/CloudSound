#!/bin/bash
# CloudSound Azure Cost Checking Script

set -e

echo "=========================================="
echo "CloudSound Azure Cost Analysis"
echo "=========================================="
echo ""

# Get subscription and resource group
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RESOURCE_GROUP=$(cd infrastructure/terraform && terraform output -raw resource_group_name 2>/dev/null || echo "")

echo "Subscription: $SUBSCRIPTION_ID"
if [ -n "$RESOURCE_GROUP" ]; then
    echo "Resource Group: $RESOURCE_GROUP"
else
    echo "⚠️  Resource group not found in terraform output"
    exit 1
fi

echo ""
echo "=========================================="
echo "1. CURRENT MONTH COST"
echo "=========================================="
echo ""

# Get current month cost
START_DATE=$(date -d "1 month ago" +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)

echo "Cost from $START_DATE to $END_DATE:"
az consumption usage list \
    --start-date "$START_DATE" \
    --end-date "$END_DATE" \
    --query "[].{Date:date,Cost:pretaxCost,Currency:currency}" \
    -o table 2>/dev/null || echo "⚠️  Cost data may take 24-48 hours to appear after resource creation"

echo ""
echo "=========================================="
echo "2. RESOURCE BREAKDOWN"
echo "=========================================="
echo ""

echo "Resources in resource group:"
az resource list --resource-group "$RESOURCE_GROUP" \
    --query "[].{Name:name,Type:type,Location:location}" \
    -o table

echo ""
echo "=========================================="
echo "3. ESTIMATED MONTHLY COSTS"
echo "=========================================="
echo ""

echo "AKS Cluster (2 nodes, Standard_B2s_v2):"
echo "  - Estimated: ~€30-40/month"
echo ""

echo "PostgreSQL Flexible Server (Standard_B1ms):"
echo "  - Estimated: ~€15-20/month"
echo ""

echo "Azure Container Registry (Basic):"
echo "  - Estimated: ~€1-5/month"
echo ""

echo "Storage Account:"
echo "  - Estimated: ~€1-2/month"
echo ""

echo "Load Balancer (Standard):"
echo "  - Estimated: ~€15-20/month"
echo ""

echo "Application Insights:"
echo "  - Free tier: €0/month (5GB free)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TOTAL ESTIMATED: ~€60-90/month"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "=========================================="
echo "4. COST OPTIMIZATION TIPS"
echo "=========================================="
echo ""

echo "1. Use Azure Reserved Instances for 1-3 year commitments (save 30-60%)"
echo "2. Scale down AKS nodes during off-hours"
echo "3. Use Azure Spot VMs for non-critical workloads (save up to 90%)"
echo "4. Enable auto-shutdown for dev/test environments"
echo "5. Monitor and delete unused resources"
echo ""

echo "=========================================="
echo "5. QUICK LINKS"
echo "=========================================="
echo ""

echo "Azure Portal Cost Management:"
echo "  https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/overview"
echo ""

echo "Azure Pricing Calculator:"
echo "  https://azure.microsoft.com/pricing/calculator/"
echo ""

echo "Resource Group Cost Analysis:"
echo "  https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/CostAnalysis"
echo ""

echo "=========================================="
echo "6. SET UP BUDGET ALERTS"
echo "=========================================="
echo ""

echo "To create a monthly budget alert (€50/month example):"
echo ""
echo "az consumption budget create \\"
echo "  --budget-name cloudsound-monthly \\"
echo "  --amount 50 \\"
echo "  --time-grain Monthly \\"
echo "  --start-date $(date +%Y-%m-01) \\"
echo "  --end-date $(date -d '+1 year' +%Y-%m-01) \\"
echo "  --category Cost"
echo ""

echo "Or use Azure Portal:"
echo "  Cost Management + Billing > Budgets > Add"
echo ""


