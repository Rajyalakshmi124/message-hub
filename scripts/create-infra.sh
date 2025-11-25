#!/bin/bash
set -euo pipefail

ACTION=$1
ENV=$2
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"

case "$ENV" in
  dev)
    APP_NAME="messagehub-app-dev"
    ENV_NAME="messagehub-env-dev"
    WORKSPACE="logs-dev"
    ;;
  qa)
    APP_NAME="messagehub-app-qa"
    ENV_NAME="messagehub-env-qa"
    WORKSPACE="logs-qa"
    ;;
  staging)
    APP_NAME="messagehub-app-stg"
    ENV_NAME="messagehub-env-stg"
    WORKSPACE="logs-stg"
    ;;
  prod)
    APP_NAME="messagehub-app-prod"
    ENV_NAME="messagehub-env-prod"
    WORKSPACE="logs-prod"
    ;;
  *)
    echo "Invalid environment: $ENV"
    exit 1
    ;;
esac

echo "======================================"
echo "ACTION       : $ACTION"
echo "ENVIRONMENT  : $ENV"
echo "APP NAME     : $APP_NAME"
echo "ENV NAME     : $ENV_NAME"
echo "WORKSPACE    : $WORKSPACE"
echo "======================================"

# ---------------------------------------------
# DELETE Infra
# ---------------------------------------------
if [[ "$ACTION" == "delete" ]]; then
    echo "[STEP] Deleting Infrastructure for $ENV..."

    # Delete Container App
    if az containerapp show -g "$RESOURCE_GROUP" -n "$APP_NAME" &>/dev/null; then
        echo "Deleting Container App: $APP_NAME"
        az containerapp delete --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --yes
    else
        echo "[INFO] No container app found (skipping)"
    fi

    # Delete Container App Environment
    if az containerapp env show -g "$RESOURCE_GROUP" -n "$ENV_NAME" &>/dev/null; then
        echo "Deleting Container App Environment: $ENV_NAME"
        az containerapp env delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$ENV_NAME" \
            --yes
    else
        echo "[INFO] No environment found (skipping)"
    fi

    # Delete Log Analytics Workspace
    if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE" &>/dev/null; then
        echo "Deleting Log Analytics Workspace: $WORKSPACE"
        az monitor log-analytics workspace delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$WORKSPACE" \
            --yes
    else
        echo "[INFO] No logs workspace found (skipping)"
    fi

    echo "Delete Completed!"
    exit 0
fi

# ---------------------------------------------
# CREATE Infra
# ---------------------------------------------

echo "[STEP] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

echo "[STEP] Creating Log Analytics Workspace..."
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE" &>/dev/null || \
az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WORKSPACE" \
    --location "$LOCATION"

echo "[STEP] Creating Container App Environment..."

az containerapp env show -g "$RESOURCE_GROUP" -n "$ENV_NAME" &>/dev/null || {

    WORKSPACE_ID=$(az monitor log-analytics workspace show \
        -g "$RESOURCE_GROUP" -n "$WORKSPACE" --query customerId -o tsv)

    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
        -g "$RESOURCE_GROUP" -n "$WORKSPACE" --query primarySharedKey -o tsv)

    az containerapp env create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ENV_NAME" \
        --location "$LOCATION" \
        --logs-workspace-id "$WORKSPACE_ID" \
        --logs-workspace-key "$WORKSPACE_KEY"
}

echo "Create Completed Successfully!"
