#!/bin/bash
set -euo pipefail

ACTION=$1       # create or delete
ENV=$2          # Dev / QA / Staging / Prod
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"

# -------------------------------
# SAFE Azure-compliant names
# -------------------------------
APP_NAME="messagehub-app-$ENV"
ENV_NAME="messagehub-env-$ENV"
WORKSPACE="logs-$ENV"
ACR_NAME="messagehubacr${ENV}"   # dev → messagehubacrdev (VALID)
# No hyphens, fully Azure safe

echo "=========================================="
echo " ACTION      : $ACTION"
echo " ENV         : $ENV"
echo " APP NAME    : $APP_NAME"
echo " ENV NAME    : $ENV_NAME"
echo " WORKSPACE   : $WORKSPACE"
echo " ACR NAME    : $ACR_NAME"
echo "=========================================="


# -------------------------------
# DELETE INFRA
# -------------------------------
if [[ "$ACTION" == "delete" ]]; then
    echo "[DELETE] Removing infrastructure for $ENV..."

    # Delete Container App
    if az containerapp show -g "$RESOURCE_GROUP" -n "$APP_NAME" &>/dev/null; then
        echo "Deleting Container App: $APP_NAME"
        az containerapp delete -g "$RESOURCE_GROUP" -n "$APP_NAME" --yes
    fi

    # Delete Container App Environment
    if az containerapp env show -g "$RESOURCE_GROUP" -n "$ENV_NAME" &>/dev/null; then
        echo "Deleting Container App Environment: $ENV_NAME"
        az containerapp env delete -g "$RESOURCE_GROUP" -n "$ENV_NAME" --yes
    fi

    # Delete Log Analytics Workspace
    if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE" &>/dev/null; then
        echo "Deleting Log Workspace: $WORKSPACE"
        az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$WORKSPACE" --yes
    fi

    # Delete ACR
    if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &>/dev/null; then
        echo "Deleting ACR: $ACR_NAME"
        az acr delete -g "$RESOURCE_GROUP" -n "$ACR_NAME" --yes
    fi

    echo "DELETE Completed!"
    exit 0
fi


# -------------------------------
# CREATE INFRA
# -------------------------------
echo "[STEP] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

echo "[STEP] Creating Log Analytics Workspace..."
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE" &>/dev/null ||
az monitor log-analytics workspace create \
    -g "$RESOURCE_GROUP" -n "$WORKSPACE" -l "$LOCATION"

echo "[STEP] Creating ACR for env: $ACR_NAME"
az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &>/dev/null ||
az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled true \
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

echo "CREATE Completed Successfully!"
