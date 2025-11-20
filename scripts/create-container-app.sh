#!/bin/bash
set -euo pipefail

#########################################
# CONFIGURATIONS
#########################################
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
CONTAINER_APP_ENV="messagehub-env"
CONTAINER_APP_NAME="messagehub-app"
ACR_NAME="messagehubacr"
IMAGE_NAME="message-app"   # ACR repository
IMAGE_TAG="v1"             # Deployment tag
PORT=5000

echo "--------------------------------------"
echo "Container App Creation Script Started"
echo "--------------------------------------"

#########################################
# STEP 1 — Set Subscription
#########################################
echo "[STEP 1] Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
echo "[OK] Subscription set"
echo ""

#########################################
# STEP 2 — Check if Container App Exists
#########################################
echo "[STEP 2] Checking if Container App already exists..."

if az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null
then
    echo "[INFO] Container App '$CONTAINER_APP_NAME' already exists."
    echo "[SKIPPED] Creation skipped to avoid duplication."
    echo "--------------------------------------"
    exit 0
fi

echo "[OK] Container App does NOT exist — proceeding with creation."
echo ""

#########################################
# STEP 3 — Get ACR Login Server
#########################################
echo "[STEP 3] Getting ACR login server..."
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)
echo "[OK] ACR Login Server: $ACR_LOGIN_SERVER"
echo ""

#########################################
# STEP 4 — Prepare full image name
#########################################
FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "[STEP 4] Using image: $FULL_IMAGE"
echo ""

#########################################
# STEP 5 — Create Container App
#########################################
echo "[STEP 5] Creating Container App..."

az containerapp create \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$CONTAINER_APP_ENV" \
  --image "$FULL_IMAGE" \
  --target-port "$PORT" \
  --ingress external \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_NAME" \
  --registry-password "$(az acr credential show -n $ACR_NAME --query 'passwords[0].value' -o tsv)" \
  --query properties.configuration.ingress.fqdn -o tsv

echo ""
echo "--------------------------------------"
echo "[SUCCESS] Container App created successfully!"
echo "--------------------------------------"
