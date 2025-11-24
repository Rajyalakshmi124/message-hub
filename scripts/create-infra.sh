#!/bin/bash
set -euo pipefail    # Stops script immediately on error

ACTION=$1            # create/delete
ENV=$2               # dev/qa/staging/prod

# Fixed resource group (since you cannot create a new one)
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"

# Single ACR used for all environments
ACR_NAME="messagehubacr"

# Step 0: Set environment-specific values
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
esac

echo "=========================================="
echo " Running $ACTION for $ENV environment"
echo "=========================================="

# -----------------------------------------------------
# Step 1: Delete Infra (only removes selected env)
# -----------------------------------------------------
if [[ "$ACTION" == "delete" ]]; then
    echo "Step 1 - Deleting infrastructure for $ENV..."

    # Delete Container App Environment
    az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &> /dev/null && \
      az containerapp env delete -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" --yes

    # Delete Log Analytics
    az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null && \
      az monitor.log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --yes

    echo "Delete completed!"
    exit 0
fi

# -----------------------------------------------------
# Step 2: Set subscription
# -----------------------------------------------------
echo "Step 2 - Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

# -----------------------------------------------------
# Step 3: Ensure Log Analytics Workspace exists
# -----------------------------------------------------
echo "Step 3 - Checking Log Analytics Workspace..."
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &> /dev/null || \
  az.monitor.log-analytics workspace create -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --location "$LOCATION"

# -----------------------------------------------------
# Step 4: Ensure Container App Environment exists
# -----------------------------------------------------
echo "Step 4 - Checking Container App Environment..."
az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &> /dev/null || {

  WORKSPACE_ID=$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query customerId -o tsv)
  WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query primarySharedKey -o tsv)

  az containerapp env create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CONTAINER_APP_ENV" \
    --location "$LOCATION" \
    --logs-workspace-id "$WORKSPACE_ID" \
    --logs-workspace-key "$WORKSPACE_KEY"
}

echo "Create completed successfully!"
