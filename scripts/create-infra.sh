#!/bin/bash
set -euo pipefail

MODE=${1:-create}

# Config
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
ACR_NAME="messagehubacr"
CONTAINER_APP_ENV="messagehub-env"
LOG_WORKSPACE="workspace-${RESOURCE_GROUP}"

echo "==========================================="
echo " MODE: $MODE"
echo "==========================================="

# Step 1: Set subscription
az account set --subscription "$SUBSCRIPTION_NAME"

###############################################
# MODE: DELETE
###############################################
if [[ "$MODE" == "delete" ]]; then
    echo "[DELETE] Deleting Azure resources except Resource Group..."

    # Delete Container Apps Environment
    echo "[DELETE] Container App Environment: $CONTAINER_APP_ENV"
    az containerapp env delete --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" --yes || echo "Not found"

    # Delete ACR
    echo "[DELETE] ACR: $ACR_NAME"
    az acr delete --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --yes || echo "Not found"

    # Delete Log Analytics Workspace
    echo "[DELETE] Workspace: $LOG_WORKSPACE"
    az monitor log-analytics workspace delete \
        --resource-group "$RESOURCE_GROUP" \
        --workspace-name "$LOG_WORKSPACE" \
        --yes || echo "Not found"

    echo "-----------------------------------------"
    echo " Delete operation completed successfully!"
    echo "-----------------------------------------"
    exit 0
fi

###############################################
# MODE: CREATE (Default)
###############################################
echo "[CREATE] Starting infra creation..."

# Ensure Resource Group (do NOT delete)
if ! az group show -n "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] Creating Resource Group..."
    az group create -n "$RESOURCE_GROUP" -l "$LOCATION"
fi

# Create Log Analytics Workspace
if ! az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null; then
    echo "[CREATE] Creating Log Workspace..."
    az monitor log-analytics workspace create \
        -g "$RESOURCE_GROUP" \
        -n "$LOG_WORKSPACE" \
        --location "$LOCATION"
fi

WORKSPACE_ID=$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query customerId -o tsv)
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query primarySharedKey -o tsv)

# Create ACR
if ! az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
    az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --admin-enabled true
fi

# Create Container Apps Environment
if ! az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    az containerapp env create \
        --name "$CONTAINER_APP_ENV" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --logs-workspace-id "$WORKSPACE_ID" \
        --logs-workspace-key "$WORKSPACE_KEY"
fi

echo "-----------------------------------------"
echo " Infra creation completed successfully!"
echo "-----------------------------------------"
