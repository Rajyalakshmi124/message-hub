#!/bin/bash
set -e  # Stop if any command fails

# ---------------------------------------------
# Configuration
# ---------------------------------------------
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
RESOURCE_GROUP="exr-dvo-intern-inc"
CONTAINER_APP_ENV="messagehub-env"
CONTAINER_APP_NAME="messagehub-app"
ACR_NAME="messagehubacr"
IMAGE_NAME="message-app"
TARGET_PORT=5000

echo "---------------------------------------------"
echo "   Container App Creation Script Started"
echo "---------------------------------------------"

# STEP 1 — Set subscription
echo "[STEP 1] Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"
echo "[OK] Subscription set"
echo ""

# STEP 2 — Check if Container App already exists
echo "[STEP 2] Checking if Container App already exists..."
if az containerapp show -n "$CONTAINER_APP_NAME" -g "$RESOURCE_GROUP" &> /dev/null; then
    echo "[INFO] Container App '$CONTAINER_APP_NAME' already exists."
    echo "[INFO] Skipping creation."
    exit 0
fi
echo "[OK] Container App not found. Proceeding to create."
echo ""

# STEP 3 — Get ACR login server
echo "[STEP 3] Fetching ACR login server..."
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)
echo "[OK] ACR Login Server: $ACR_LOGIN_SERVER"
echo ""

# STEP 4 — Get latest tag
echo "[STEP 4] Fetching latest image tag..."
LATEST_TAG=$(az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository "$IMAGE_NAME" \
    --orderby time_desc \
    --top 1 -o tsv)

if [[ -z "$LATEST_TAG" ]]; then
    echo "[ERROR] No image found. Push an image first."
    exit 1
fi

FULL_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$LATEST_TAG"
echo "[OK] Using image: $FULL_IMAGE"
echo ""

# STEP 5 — Get ACR password
echo "[STEP 5] Getting ACR credentials..."
ACR_PASSWORD=$(az acr credential show -n "$ACR_NAME" --query passwords[0].value -o tsv)
echo "[OK] Password retrieved"
echo ""

# STEP 6 — Create Container App (ONLY CREATE)
echo "[STEP 6] Creating Container App..."
az containerapp create \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINER_APP_ENV" \
    --image "$FULL_IMAGE" \
    --ingress external \
    --target-port $TARGET_PORT \
    --registry-server "$ACR_LOGIN_SERVER" \
    --registry-username "$ACR_NAME" \
    --registry-password "$ACR_PASSWORD"

echo "---------------------------------------------"
echo "   Container App Created Successfully!"
echo "---------------------------------------------"
