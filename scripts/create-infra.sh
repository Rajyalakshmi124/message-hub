#!/bin/bash
set -euo pipefail   # Stop if any command fails

#######################################
# Basic Configuration
#######################################
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
ACR_NAME="messagehubacr"
CONTAINER_APP_ENV="messagehub-env"
LOG_WORKSPACE="workspace-${RESOURCE_GROUP}"

echo "-----------------------------------------"
echo "  Azure Infrastructure Setup Started"
echo "-----------------------------------------"

#######################################
# Step 1: Set Azure subscription
#######################################
echo "[1] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
echo "✓ Subscription set"
echo ""

#######################################
# Step 2: Create resource group (if missing)
#######################################
echo "[2] Checking resource group..."
if az group show -n "$RESOURCE_GROUP" &>/dev/null; then
  echo "✓ Resource group exists"
else
  echo "→ Creating resource group..."
  az group create -n "$RESOURCE_GROUP" -l "$LOCATION"
  echo "✓ Resource group created"
fi
echo ""

#######################################
# Step 3: Create Log Analytics workspace
#######################################
echo "[3] Checking Log Analytics workspace..."
if az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" &>/dev/null; then
  echo "✓ Workspace exists"
else
  echo "→ Creating workspace..."
  az monitor log-analytics workspace create \
    -g "$RESOURCE_GROUP" \
    -n "$LOG_WORKSPACE" \
    --location "$LOCATION"
  echo "✓ Workspace created"
fi
echo ""

#######################################
# Step 4: Create ACR (if missing)
#######################################
echo "[4] Checking Azure Container Registry..."
if az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" &>/dev/null; then
  echo "✓ ACR exists"
else
  echo "→ Creating ACR..."
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled true \
    --location "$LOCATION"
  echo "✓ ACR created"
fi
echo ""

#######################################
# Step 5: Create Container Apps Environment
#######################################
echo "[5] Checking Container App environment..."
if az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  echo "✓ Environment exists"
else
  echo "→ Creating Container App environment..."

  # Get workspace ID & key
  WORKSPACE_ID=$(az monitor log-analytics workspace show \
      -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query customerId -o tsv)

  WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
      -g "$RESOURCE_GROUP" -n "$LOG_WORKSPACE" --query primarySharedKey -o tsv)

  az containerapp env create \
    --name "$CONTAINER_APP_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --logs-workspace-id "$WORKSPACE_ID" \
    --logs-workspace-key "$WORKSPACE_KEY"

  echo "✓ Environment created"
fi

echo ""
echo "-----------------------------------------"
echo "  Infra setup completed successfully!"
echo "-----------------------------------------"
