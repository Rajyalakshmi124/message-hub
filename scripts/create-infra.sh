#!/bin/bash
set -euo pipefail

ENV=$1
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

RESOURCE_GROUP="exr-dvo-intern-inc"
SUBSCRIPTION_NAME="Founder-HUB-Microsoft Azure Sponsorship"
ACR_NAME="messagehubacr"
IMAGE_NAME="message-app"

case "$ENV" in
  dev) APP_NAME="messagehub-app-dev" ;;
  qa) APP_NAME="messagehub-app-qa" ;;
  staging) APP_NAME="messagehub-app-stg" ;;
  prod) APP_NAME="messagehub-app-prod" ;;
  *) echo "Invalid env"; exit 1 ;;
esac

echo "========================================="
echo " Deploying latest image to $APP_NAME ($ENV)"
echo "========================================="

# 1. Set subscription
az account set --subscription "$SUBSCRIPTION_NAME"

# 2. Get latest image tag
TAG=$(az acr repository show-tags --name "$ACR_NAME" \
      --repository "$IMAGE_NAME" \
      --orderby time_desc --top 1 -o tsv)

if [[ -z "$TAG" ]]; then
  echo "[ERROR] No image in ACR!"
  exit 1
fi

IMAGE="$ACR_NAME.azurecr.io/$IMAGE_NAME:$TAG"

# 3. Deploy image
az containerapp update \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$IMAGE"

echo "Deployed $IMAGE to $APP_NAME"
