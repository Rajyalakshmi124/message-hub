#!/bin/bash
# Stop on error, undefined variable, or pipe failure
set -euo pipefail

ACTION=$1 # create-all / delete-all / create-one / delete-one
ENV_SELECTED=$(echo "$2" | tr '[:upper:]' '[:lower:]')

RESOURCE_GROUP="exr-dvo-intern-inc"
LOCATION="Central India"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"

# Supported environments
ENVS=("dev" "qa" "staging" "prod")

# ---------------------------------------------------------------
# Set Azure subscription (Required before any AZ CLI operations)
# ---------------------------------------------------------------
echo "[INIT] Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

# ---------------------------------------------------------------
# Function: generate dynamic resource names
# ---------------------------------------------------------------
get_names() {
  local env=$1

  APP="messagehub-app-$env"
  ENVN="messagehub-env-$env"
  WORK="logs-$env"
  ACR="messagehubacr$env"       
}

# ---------------------------------------------------------------
# Function: Create/Delete a SINGLE environment (one env)
# ---------------------------------------------------------------
process() {
  get_names "$1"

  echo "========================================"
  echo " ENVIRONMENT   : $1"
  echo " ACTION        : $ACTION"
  echo " ENV NAME      : $ENVN"
  echo " WORKSPACE     : $WORK"
  echo " ACR NAME      : $ACR"
  echo "========================================"

  # ---------------- DELETE BLOCK ----------------
  if [[ "$ACTION" == delete* ]]; then
    echo "[DELETE] Removing resources for $1…"

    # Delete Container App (SAFE DELETE — if exists)
    az containerapp delete -g "$RESOURCE_GROUP" -n "$APP" --yes 2>/dev/null || true

    # Delete Container App Environment
    az containerapp env delete -g "$RESOURCE_GROUP" -n "$ENVN" --yes 2>/dev/null || true

    # Delete Log Analytics Workspace
    az monitor log-analytics workspace delete -g "$RESOURCE_GROUP" -n "$WORK" --yes 2>/dev/null || true

    # Delete ACR
    az acr delete -g "$RESOURCE_GROUP" -n "$ACR" --yes 2>/dev/null || true

    echo "[OK] Deleted $1 infra"
    return
  fi

  # ---------------- CREATE BLOCK ----------------
  echo "[CREATE] Setting up $1 infrastructure…"

  # Create Logs Workspace
  az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORK" &>/dev/null || \
  az monitor log-analytics workspace create -g "$RESOURCE_GROUP" -n "$WORK" -l "$LOCATION"

  # Create ACR for this environment
  az acr show -n "$ACR" -g "$RESOURCE_GROUP" &>/dev/null || \
  az acr create --resource-group "$RESOURCE_GROUP" \
                --name "$ACR" \
                --sku Basic \
                --admin-enabled true \
                --location "$LOCATION"

  # Create Container App Environment
  if ! az containerapp env show -g "$RESOURCE_GROUP" -n "$ENVN" &>/dev/null; then

    WS_ID=$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORK" --query customerId -o tsv)
    WS_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$RESOURCE_GROUP" -n "$WORK" --query primarySharedKey -o tsv)

    az containerapp env create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$ENVN" \
      --location "$LOCATION" \
      --logs-workspace-id "$WS_ID" \
      --logs-workspace-key "$WS_KEY"
  fi

  echo "[OK] Created infra for $1"
}

# ---------------------------------------------------------------
# MAIN ACTION HANDLING
# ---------------------------------------------------------------
case "$ACTION" in
  create-all|delete-all)
    for e in "${ENVS[@]}"; do
      process "$e"
    done
    ;;
  create-one|delete-one)
    process "$ENV_SELECTED"
    ;;
  *)
    echo "Invalid ACTION: $ACTION"
    exit 1
    ;;
esac

echo "✔ Completed ACTION: $ACTION"
