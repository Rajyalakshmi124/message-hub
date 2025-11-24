#!/bin/bash
set -euo pipefail

ACTION=$1
ENV=$2

RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"

# ----------------------------------------------------------
# Select Infra values based on environment
# ----------------------------------------------------------

case "$ENV" in

  dev)
    ACR_NAME="messagehubacr-dev"
    CONTAINER_APP_ENV="messagehub-env-dev"
    LOG_WORKSPACE="logs-dev"
    ;;

  qa)
    ACR_NAME="messagehubacr-qa"
    CONTAINER_APP_ENV="messagehub-env-qa"
    LOG_WORKSPACE="logs-qa"
    ;;

  staging)
    ACR_NAME="messagehubacr-stg"
    CONTAINER_APP_ENV="messagehub-env-stg"
    LOG_WORKSPACE="logs-stg"
    ;;

  prod)
    ACR_NAME="messagehubacr-prod"
    CONTAINER_APP_ENV="messagehub-env-prod"
    LOG_WORKSPACE="logs-prod"
    ;;

  *)
    echo "Invalid environment: $ENV"
    exit 1
    ;;
esac


echo "========================================"
echo " Azure Infra Script ($ACTION - $ENV)"
echo " Using Resource Group: $RESOURCE_GROUP"
echo "========================================"

# ----------------------------------------------------------
# DELETE INFRA
# ----------------------------------------------------------

if [[ "$ACTION" == "delete" ]]; then
    echo "[DELETE] Deleting resources for $ENV..."

    # Delete Container App Environment
    if az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &> /dev/null; then
        az containerapp env delete -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" --yes
    else
        echo "Container App Environment not found (skipped)"
    fi

    # Delete ACR
    if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
        az acr delete --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --yes
    else
        echo "ACR not found (skipped)"
    fi

    # Delete Log Analytics workspace
    if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null; then
        az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --yes
    else
        echo "Log Analytics Workspace not found (skipped)"
    fi

    echo "DELETE completed!"
    exit 0
fi


# ----------------------------------------------------------
# CREATE INFRA
# ----------------------------------------------------------

echo "[INFO] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

echo "[INFO] Resource group already exists → Skipping creation."

# Create Log Analytics Workspace
echo "[INFO] Checking Log Analytics Workspace..."
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null || {
    az monitor log-analytics workspace create \
        -g "$RESOURCE_GROUP" \
        -n "$LOG_WORKSPACE" \
        --location "$LOCATION"
}

# Create ACR
echo "[INFO] Checking ACR..."
az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &> /dev/null || {
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku Basic \
        --admin-enabled true \
        --location "$LOCATION"
}

# Create Container App Environment
echo "[INFO] Checking Container App Environment..."
az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &> /dev/null || {

    WORKSPACE_ID=$(az monitor log-analytics workspace show \
        -g "$RESOURCE_GROUP" \
        -n "$LOG_WORKSPACE" \
        --query customerId -o tsv)

    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
        -g "$RESOURCE_GROUP" \
        -n "$LOG_WORKSPACE" \
        --query primarySharedKey -o tsv)

    az containerapp env create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CONTAINER_APP_ENV" \
        --location "$LOCATION" \
        --logs-workspace-id "$WORKSPACE_ID" \
        --logs-workspace-key "$WORKSPACE_KEY"
}

echo ""
echo "CREATE completed successfully for $ENV!"
echo "========================================"
