#!/bin/bash
set -euo pipefail

ENV=$1
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

RESOURCE_GROUP="exr-dvo-intern-inc"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
IMAGE_NAME="message-app"
TARGET_PORT=5000

# -----------------------------------------
# Dynamic: ACR, Container App, Env Names
# -----------------------------------------
ACR_NAME="messagehubacr$ENV"                     # dev → messagehubacrdev
CONTAINER_APP_NAME="messagehub-app-$ENV"         # dev → messagehub-app-dev
CONTAINER_APP_ENV="messagehub-env-$ENV"          # dev → messagehub-env-dev

echo "========================================="
echo " Creating Container App"
echo " ENVIRONMENT     : $ENV"
echo " ACR NAME        : $ACR_NAME"
echo " APP NAME        : $CONTAINER_APP_NAME"
echo " ENV NAME        : $CONTAINER_APP_ENV"
echo "========================================="

# Step 1 — Set subscription
echo "[STEP 1] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

# Step 2 — Get ACR Login Server
echo "[STEP 2] Fetching ACR Login Server..."
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)

# Step 3 — Get latest image tag
echo "[STEP 3] Fetching latest image tag..."
TAG=$(az acr repository show-tags \
      --name "$ACR_NAME" \
      --repository "$IMAGE_NAME" \
      --orderby time_desc --top 1 -o tsv)

if [[ -z "$TAG" ]]; then
    echo "[ERROR] No image found in $ACR_NAME! Push an image first."
    exit 1
fi

FULL_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG"
echo "[INFO] Using Image: $FULL_IMAGE"

# Step 4 — Create Container App
echo "[STEP 4] Creating Container App..."
az containerapp create \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$CONTAINER_APP_ENV" \
  --image "$FULL_IMAGE" \
  --ingress external \
  --target-port $TARGET_PORT \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_NAME" \
  --registry-password "$(az acr credential show -n $ACR_NAME --query passwords[0].value -o tsv)"

echo "========================================="
echo " Container App Created Successfully!"
echo "========================================="
