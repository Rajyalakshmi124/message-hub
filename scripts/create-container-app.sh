#!/bin/bash
set -euo pipefail

ENV=$1
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

RESOURCE_GROUP="exr-dvo-intern-inc"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
ACR_NAME="messagehubacr"
IMAGE_NAME="message-app"
TARGET_PORT=5000

case "$ENV" in
  dev)
    CONTAINER_APP_NAME="messagehub-app-dev"
    CONTAINER_APP_ENV="messagehub-env-dev"
    ;;
  qa)
    CONTAINER_APP_NAME="messagehub-app-qa"
    CONTAINER_APP_ENV="messagehub-env-qa"
    ;;
  staging)
    CONTAINER_APP_NAME="messagehub-app-stg"
    CONTAINER_APP_ENV="messagehub-env-stg"
    ;;
  prod)
    CONTAINER_APP_NAME="messagehub-app-prod"
    CONTAINER_APP_ENV="messagehub-env-prod"
    ;;
  *)
    echo "Invalid environment: $ENV"
    exit 1
    ;;
esac

echo "========================================="
echo " Creating Container App for $ENV"
echo " App Name: $CONTAINER_APP_NAME"
echo " Env Name: $CONTAINER_APP_ENV"
echo "========================================="

# 1. Set subscription
echo "[Step 1] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_NAME"

# 2. Get ACR login server
ACR_LOGIN_SERVER=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)

# 3. Get latest tag
TAG=$(az acr repository show-tags \
      --name "$ACR_NAME" \
      --repository "$IMAGE_NAME" \
      --orderby time_desc --top 1 -o tsv)

if [[ -z "$TAG" ]]; then
    echo "[ERROR] No image found in ACR! Build & push image first."
    exit 1
fi

FULL_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG"
echo "[INFO] Using image: $FULL_IMAGE"

# 4. Create Container App
echo "[Step 4] Creating Container App..."
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
echo "Container App Created Successfully!"
echo "========================================="
