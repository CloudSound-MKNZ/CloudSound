#!/bin/bash

# Azure Resource Pause/Resume Script
# Stops/starts Azure resources to save credits when not in use
#
# Usage:
#   ./scripts/azure-pause-resources.sh stop    # Stop all stoppable resources
#   ./scripts/azure-pause-resources.sh start   # Start all resources
#   ./scripts/azure-pause-resources.sh status # Show current status
#
# Estimated Savings:
#   - AKS Cluster: ~$30-40/month
#   - PostgreSQL: ~$15-20/month
#   Total: ~$45-60/month when stopped

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resource names (get from Terraform outputs if available)
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-cloudsound-rg}"
AKS_CLUSTER="${AKS_CLUSTER_NAME:-cloudsound-aks}"
POSTGRES_SERVER="${POSTGRES_SERVER_NAME:-}"

# Function to print section headers
print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Function to check if Azure CLI is installed and logged in
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        echo -e "${RED}❌ Azure CLI is not installed${NC}"
        echo "Install it from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi

    # Check if logged in
    if ! az account show &> /dev/null; then
        echo -e "${YELLOW}⚠️  Not logged into Azure. Logging in...${NC}"
        az login
    fi
}

# Function to get PostgreSQL server name from Terraform or resource group
get_postgres_server() {
    if [ -n "$POSTGRES_SERVER" ]; then
        echo "$POSTGRES_SERVER"
        return
    fi

    # Try to get from Terraform outputs
    if [ -f "infrastructure/terraform/terraform.tfstate" ]; then
        POSTGRES_SERVER=$(cd infrastructure/terraform && terraform output -raw postgres_server_name 2>/dev/null || echo "")
    fi

    # If still not found, try to find it in the resource group
    if [ -z "$POSTGRES_SERVER" ]; then
        POSTGRES_SERVER=$(az postgres flexible-server list \
            --resource-group "$RESOURCE_GROUP" \
            --query "[0].name" -o tsv 2>/dev/null || echo "")
    fi

    echo "$POSTGRES_SERVER"
}

# Function to stop all resources
stop_resources() {
    print_header "🛑 STOPPING AZURE RESOURCES"

    # Stop AKS Cluster
    echo -e "${BLUE}Stopping AKS cluster: ${AKS_CLUSTER}${NC}"
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" &> /dev/null; then
        AKS_STATE=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --query "powerState.code" -o tsv)
        if [ "$AKS_STATE" = "Running" ]; then
            az aks stop --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --no-wait
            echo -e "${GREEN}✅ AKS cluster stop initiated${NC}"
            echo -e "   ${YELLOW}Note: This may take 5-10 minutes${NC}"
        else
            echo -e "${YELLOW}⚠️  AKS cluster is already stopped (state: $AKS_STATE)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  AKS cluster not found${NC}"
    fi

    echo ""

    # Stop PostgreSQL Flexible Server
    POSTGRES_SERVER=$(get_postgres_server)
    if [ -n "$POSTGRES_SERVER" ]; then
        echo -e "${BLUE}Stopping PostgreSQL server: ${POSTGRES_SERVER}${NC}"
        POSTGRES_STATE=$(az postgres flexible-server show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$POSTGRES_SERVER" \
            --query "state" -o tsv 2>/dev/null || echo "Unknown")
        
        if [ "$POSTGRES_STATE" = "Ready" ]; then
            az postgres flexible-server stop \
                --resource-group "$RESOURCE_GROUP" \
                --name "$POSTGRES_SERVER" \
                --no-wait
            echo -e "${GREEN}✅ PostgreSQL server stop initiated${NC}"
            echo -e "   ${YELLOW}Note: This may take 2-5 minutes${NC}"
        elif [ "$POSTGRES_STATE" = "Stopped" ]; then
            echo -e "${YELLOW}⚠️  PostgreSQL server is already stopped${NC}"
        else
            echo -e "${YELLOW}⚠️  PostgreSQL server state: $POSTGRES_STATE${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  PostgreSQL server not found${NC}"
    fi

    echo ""
    print_header "💰 ESTIMATED MONTHLY SAVINGS"
    echo -e "${GREEN}When stopped, you save approximately:${NC}"
    echo "  • AKS Cluster:     ~\$30-40/month"
    echo "  • PostgreSQL:      ~\$15-20/month"
    echo -e "${GREEN}  Total Savings:     ~\$45-60/month${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC}"
    echo "  • Event Hubs, Storage, ACR continue running (minimal cost)"
    echo "  • Use './scripts/azure-pause-resources.sh start' to resume"
    echo ""
}

# Function to start all resources
start_resources() {
    print_header "▶️  STARTING AZURE RESOURCES"

    # Start AKS Cluster
    echo -e "${BLUE}Starting AKS cluster: ${AKS_CLUSTER}${NC}"
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" &> /dev/null; then
        AKS_STATE=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --query "powerState.code" -o tsv)
        if [ "$AKS_STATE" = "Stopped" ]; then
            az aks start --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --no-wait
            echo -e "${GREEN}✅ AKS cluster start initiated${NC}"
            echo -e "   ${YELLOW}Note: This may take 5-10 minutes${NC}"
        elif [ "$AKS_STATE" = "Running" ]; then
            echo -e "${YELLOW}⚠️  AKS cluster is already running${NC}"
        else
            echo -e "${YELLOW}⚠️  AKS cluster state: $AKS_STATE${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  AKS cluster not found${NC}"
    fi

    echo ""

    # Start PostgreSQL Flexible Server
    POSTGRES_SERVER=$(get_postgres_server)
    if [ -n "$POSTGRES_SERVER" ]; then
        echo -e "${BLUE}Starting PostgreSQL server: ${POSTGRES_SERVER}${NC}"
        POSTGRES_STATE=$(az postgres flexible-server show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$POSTGRES_SERVER" \
            --query "state" -o tsv 2>/dev/null || echo "Unknown")
        
        if [ "$POSTGRES_STATE" = "Stopped" ]; then
            az postgres flexible-server start \
                --resource-group "$RESOURCE_GROUP" \
                --name "$POSTGRES_SERVER" \
                --no-wait
            echo -e "${GREEN}✅ PostgreSQL server start initiated${NC}"
            echo -e "   ${YELLOW}Note: This may take 2-5 minutes${NC}"
        elif [ "$POSTGRES_STATE" = "Ready" ]; then
            echo -e "${YELLOW}⚠️  PostgreSQL server is already running${NC}"
        else
            echo -e "${YELLOW}⚠️  PostgreSQL server state: $POSTGRES_STATE${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  PostgreSQL server not found${NC}"
    fi

    echo ""
    echo -e "${GREEN}✅ Resources are starting...${NC}"
    echo -e "${YELLOW}Wait a few minutes, then check status with:${NC}"
    echo "  ./scripts/azure-pause-resources.sh status"
    echo ""
}

# Function to show status of all resources
show_status() {
    print_header "📊 AZURE RESOURCES STATUS"

    # AKS Status
    echo -e "${BLUE}AKS Cluster:${NC}"
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" &> /dev/null; then
        AKS_STATE=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --query "powerState.code" -o tsv)
        if [ "$AKS_STATE" = "Running" ]; then
            echo -e "  Status: ${GREEN}Running${NC} ✅"
            echo -e "  Cost:   ~\$30-40/month"
        elif [ "$AKS_STATE" = "Stopped" ]; then
            echo -e "  Status: ${YELLOW}Stopped${NC} ⏸️"
            echo -e "  Cost:   \$0/month (saving ~\$30-40)"
        else
            echo -e "  Status: ${YELLOW}$AKS_STATE${NC}"
        fi
    else
        echo -e "  ${RED}Not found${NC}"
    fi

    echo ""

    # PostgreSQL Status
    echo -e "${BLUE}PostgreSQL Flexible Server:${NC}"
    POSTGRES_SERVER=$(get_postgres_server)
    if [ -n "$POSTGRES_SERVER" ]; then
        POSTGRES_STATE=$(az postgres flexible-server show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$POSTGRES_SERVER" \
            --query "state" -o tsv 2>/dev/null || echo "Unknown")
        
        if [ "$POSTGRES_STATE" = "Ready" ]; then
            echo -e "  Status: ${GREEN}Running${NC} ✅"
            echo -e "  Cost:   ~\$15-20/month"
        elif [ "$POSTGRES_STATE" = "Stopped" ]; then
            echo -e "  Status: ${YELLOW}Stopped${NC} ⏸️"
            echo -e "  Cost:   \$0/month (saving ~\$15-20)"
        else
            echo -e "  Status: ${YELLOW}$POSTGRES_STATE${NC}"
        fi
        echo -e "  Server: $POSTGRES_SERVER"
    else
        echo -e "  ${RED}Not found${NC}"
    fi

    echo ""

    # Other resources (always running, minimal cost)
    echo -e "${BLUE}Other Resources (always running):${NC}"
    echo -e "  Event Hubs:     ${GREEN}Running${NC} (~\$10-20/month)"
    echo -e "  Storage:        ${GREEN}Running${NC} (~\$1-2/month)"
    echo -e "  ACR:            ${GREEN}Running${NC} (~\$5/month)"
    echo -e "  Log Analytics:  ${GREEN}Running${NC} (~\$5-15/month)"

    echo ""
    print_header "💰 CURRENT MONTHLY COST ESTIMATE"
    
    AKS_STATE=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --query "powerState.code" -o tsv 2>/dev/null || echo "Unknown")
    POSTGRES_STATE=$(az postgres flexible-server show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$(get_postgres_server)" \
        --query "state" -o tsv 2>/dev/null || echo "Unknown")
    
    BASE_COST=21  # Event Hubs + Storage + ACR + Log Analytics (minimum)
    
    if [ "$AKS_STATE" = "Running" ]; then
        BASE_COST=$((BASE_COST + 35))
    fi
    
    if [ "$POSTGRES_STATE" = "Ready" ]; then
        BASE_COST=$((BASE_COST + 17))
    fi
    
    echo -e "${GREEN}Estimated: ~\$$BASE_COST-$(($BASE_COST + 20))/month${NC}"
    echo ""
}

# Main script logic
main() {
    check_azure_cli

    case "${1:-status}" in
        stop)
            stop_resources
            ;;
        start)
            start_resources
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {stop|start|status}"
            echo ""
            echo "Commands:"
            echo "  stop    - Stop AKS and PostgreSQL (save ~\$45-60/month)"
            echo "  start   - Start AKS and PostgreSQL"
            echo "  status  - Show current status of all resources (default)"
            exit 1
            ;;
    esac
}

main "$@"

