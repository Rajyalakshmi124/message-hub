#!/bin/bash
set -e

# ----------------------------------------------------------
# Configuration
# ----------------------------------------------------------
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
CONTAINER_APP_NAME="messagehub-app"
ACR_NAME="messagehubacr"
IMAGE_NAME="message-app"

echo "---------------------------------------------"
echo "   Deployment Script Started"
echo "---------------------------------------------"

# STEP 1 — Set subscription
echo "[STEP 1] Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
echo "[OK] Subscription set"
echo ""

# STEP 2 — Get ACR login server
echo "[STEP 2] Fetching ACR login server..."
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)
echo "[OK] ACR Login Server: $ACR_LOGIN_SERVER"
echo ""

# STEP 3 — Get latest image tag
echo "[STEP 3] Fetching latest image tag..."
LATEST_TAG=$(az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository "$IMAGE_NAME" \
    --orderby time_desc \
    --top 1 -o tsv)

if [[ -z "$LATEST_TAG" ]]; then
    echo "[ERROR] No image found in ACR. Push an image first."
    exit 1
fi

FULL_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$LATEST_TAG"
echo "[OK] Latest image: $FULL_IMAGE"
echo ""

# STEP 4 — Deploy to Container App
echo "[STEP 4] Updating Container App with latest image..."
az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$FULL_IMAGE"

echo "---------------------------------------------"
echo "   Deployment Completed Successfully!"
echo "---------------------------------------------"
