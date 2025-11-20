#!/bin/bash
set -e

# -------------------------
# Configuration
# -------------------------
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
CONTAINER_APP_ENV="messagehub-env"
CONTAINER_APP_NAME="messagehub-app"
ACR_NAME="messagehubacr"
IMAGE_NAME="message-app"

echo "-----------------------------------------"
echo "   Container App Creation Script Started"
echo "-----------------------------------------"

# STEP 1 — Set subscription
echo "[STEP 1] Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
echo "[OK] Subscription set successfully"
echo ""

# STEP 2 — Check if Container App exists
echo "[STEP 2] Checking if Container App already exists..."
if az containerapp show -n "$CONTAINER_APP_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] Container App '$CONTAINER_APP_NAME' already exists."
    echo "[INFO] Skipping creation."
    exit 0
fi
echo "[OK] Container App does NOT exist — creating..."
echo ""

# STEP 3 — Get ACR Login Server
echo "[STEP 3] Getting ACR login server..."
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)
echo "[OK] ACR Login Server: $ACR_LOGIN_SERVER"
echo ""

# STEP 4 — Get latest image tag from ACR
echo "[STEP 4] Fetching latest image tag..."
LATEST_TAG=$(az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository "$IMAGE_NAME" \
    --orderby time_desc \
    --top 1 -o tsv)

if [[ -z "$LATEST_TAG" ]]; then
  echo "[ERROR] No image tags found in ACR! Push an image first."
  exit 1
fi

FULL_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$LATEST_TAG"
echo "[OK] Using image: $FULL_IMAGE"
echo ""

# STEP 5 — Get ACR password for pulling image
echo "[STEP 5] Getting ACR password..."
ACR_PASSWORD=$(az acr credential show -n "$ACR_NAME" --query passwords[0].value -o tsv)

# STEP 6 — Create Container App
echo "[STEP 6] Creating Container App with external ingress..."
az containerapp create \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$CONTAINER_APP_ENV" \
  --image "$FULL_IMAGE" \
  --ingress external \
  --target-port 5000 \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_NAME" \
  --registry-password "$ACR_PASSWORD"

echo "-----------------------------------------"
echo " Container App Created Successfully!"
echo "-----------------------------------------"
