#!/bin/bash
set -euo pipefail

ACTION=$1
ENV=$2

# Convert Env to lowercase
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
ACR_NAME="messagehubacr"

case "$ENV" in
  dev)
    CONTAINER_APP_ENV="messagehub-env-dev"
    LOG_WORKSPACE="logs-dev"
    ;;
  qa)
    CONTAINER_APP_ENV="messagehub-env-qa"
    LOG_WORKSPACE="logs-qa"
    ;;
  staging)
    CONTAINER_APP_ENV="messagehub-env-stg"
    LOG_WORKSPACE="logs-stg"
    ;;
  prod)
    CONTAINER_APP_ENV="messagehub-env-prod"
    LOG_WORKSPACE="logs-prod"
    ;;
  *)
    echo "Invalid environment: $ENV"
    exit 1
    ;;
esac

echo "=========================================="
echo " Running $ACTION for $ENV environment"
echo "=========================================="

# -----------------------------------------------------
# DELETE INFRA
# -----------------------------------------------------
if [[ "$ACTION" == "delete" ]]; then
    echo "Deleting Infrastructure: $ENV"

    az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &>/dev/null && \
    az containerapp env delete -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" --yes

    az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &>/dev/null && \
    az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --yes

    echo "Delete completed!"
    exit 0
fi

# -----------------------------------------------------
# CREATE INFRA
# -----------------------------------------------------
echo "Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

echo "Checking Log Analytics Workspace..."
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &>/dev/null || \
az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LOG_WORKSPACE" \
    --location "$LOCATION"

echo "Checking Container App Environment..."
az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &>/dev/null || {

    WORKSPACE_ID=$(az monitor log-analytics workspace show \
                      -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" \
                      --query customerId -o tsv)

    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
                      -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" \
                      --query primarySharedKey -o tsv)

    az containerapp env create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CONTAINER_APP_ENV" \
        --location "$LOCATION" \
        --logs-workspace-id "$WORKSPACE_ID" \
        --logs-workspace-key "$WORKSPACE_KEY"
}

echo "Create completed successfully!"
