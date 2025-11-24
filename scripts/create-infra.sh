#!/bin/bash
set -euo pipefail    # Stop script immediately on error

ACTION=$1             # create/delete
ENV=$2                # Dev/QA/Staging/Prod (from workflow)

# Normalize environment to lowercase (Dev → dev, Staging → staging)
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

# Fixed resource group
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"

# Single ACR for all environments
ACR_NAME="messagehubacr"

# Step 0 — Set names based on environment
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
# Step 1 — DELETE INFRASTRUCTURE
# -----------------------------------------------------
if [[ "$ACTION" == "delete" ]]; then
    echo "Step 1 - Deleting infrastructure for $ENV..."

    # Delete Container App Environment
    if az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &>/dev/null; then
        az containerapp env delete \
          --resource-group "$RESOURCE_GROUP" \
          --name "$CONTAINER_APP_ENV" \
          --yes
    fi

    # Delete Log Analytics Workspace
    if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &>/dev/null; then
        az monitor log-analytics workspace delete \
          --resource-group "$RESOURCE_GROUP" \
          --name "$LOG_WORKSPACE" \
          --yes
    fi

    echo "Delete completed!"
    exit 0
fi

# -----------------------------------------------------
# Step 2 — Set subscription
# -----------------------------------------------------
echo "Step 2 - Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

# -----------------------------------------------------
# Step 3 — Ensure Log Analytics Workspace exists
# -----------------------------------------------------
echo "Step 3 - Checking Log Analytics Workspace..."
az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &>/dev/null || \
  az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LOG_WORKSPACE" \
    --location "$LOCATION"

# -----------------------------------------------------
# Step 4 — Ensure Container App Environment exists
# -----------------------------------------------------
echo "Step 4 - Checking Container App Environment..."
az containerapp env show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_ENV" &>/dev/null || {

  # Fetch Log Analytics Keys
  WORKSPACE_ID=$(az monitor log-analytics workspace show \
                  -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" \
                  --query customerId -o tsv)

  WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
                  -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" \
                  --query primarySharedKey -o tsv)

  # Create Container App Environment
  az containerapp env create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CONTAINER_APP_ENV" \
    --location "$LOCATION" \
    --logs-workspace-id "$WORKSPACE_ID" \
    --logs-workspace-key "$WORKSPACE_KEY"
}

echo "Create completed successfully!"
