#! /bin/bash
export GHCR_PAT_TOKEN=""
export GH_USERNAME=""
export GIT_REPO_ROOT_PATH=$(git rev-parse --show-toplevel)
export GAME_COMPONENTS_PATH=$GIT_REPO_ROOT_PATH"/game-server-components"

export RG_NAME="pixel_group"
export CLUSTER_NAME="urpixelstream"
export LOCATION="eastus"
export GPU_NP_SKU="Standard_NC12_Promo"
export TURN_NP_SKU="Standard_F8s_v2"

# Create Resource Group
echo "Create RG"

# Need to Register GPU Nodes for AKS
az feature register --namespace "Microsoft.ContainerService" --name "GPUDedicatedVHDPreview"
az feature show --namespace "Microsoft.ContainerService" --name "GPUDedicatedVHDPreview"

az group create \
    --name $RG_NAME \
    --location $LOCATION

echo "Create ACR"
az acr create --name $CLUSTER_NAME -g $RG_NAME -l $LOCATION --sku Standard 

# Create AKS Cluster
echo "Create Cluster"

az aks create \
    -g $RG_NAME \
    --name $CLUSTER_NAME \
    --enable-managed-identity \
    --node-count 1 \
    --enable-addons monitoring \
    --enable-msi-auth-for-monitoring  \
    --generate-ssh-keys \
    --attach-acr $CLUSTER_NAME

# Add a GPU sku nodepool
# Note: Taint the nodepool to prevent unintended use
echo "Create Nodepool"

az aks nodepool add \
    --resource-group $RG_NAME \
    --cluster-name $CLUSTER_NAME \
    --name gpunp \
    --node-count 1 \
    --node-osdisk-size 250 \
    --mode User \
    --node-vm-size $GPU_NP_SKU \
    --aks-custom-headers UseGPUDedicatedVHD=true \
    --node-taints sku=gpu:NoSchedule \
    --no-wait
    
# Add a nodepool for TURN
echo "Create Nodepool"

az aks nodepool add \
    --resource-group $RG_NAME \
    --cluster-name $CLUSTER_NAME \
    --name turnp \
    --node-count 1 \
    --node-osdisk-size 250 \
    --mode User \
    --enable-node-public-ip \
    --node-vm-size $TURN_NP_SKU \
    --node-taints sku=turn:NoSchedule \
    --no-wait

az aks get-credentials -n $CLUSTER_NAME -g $RG_NAME

#################################################
# Build and Push Game Component Containers


# Update your container registry name here
export CONTAINER_REGISTRY_URL="$CLUSTER_NAME.azurecr.io"
export ORG="pixelstream"
export CONTAINER_URI=$CONTAINER_REGISTRY_URL/$ORG

# Build Matchmaker image
cd $GAME_COMPONENTS_PATH"/Matchmaker/platform_scripts/bash"
docker build -t $CONTAINER_URI/matchmaker:4.27 -f Dockerfile ../..

# Build Signalling image
cd $GAME_COMPONENTS_PATH"/SignallingWebServer/platform_scripts/bash/"
docker build -t $CONTAINER_URI/signallingwebserver:4.27 -f ./Dockerfile ../..

# Build Unreal Engine App image . Copy the Dockerfile to the root of the Unreal Engine App
## ***NOTE*** YOU MUST JOIN THE EPIC GAMES GitHub ORG to access the base container image
## https://www.unrealengine.com/en-US/ue-on-github
## Then you must Log in to GitHub Container Registry (GHCR) with a Pat Token
## https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry
## Create a Classic PAT token and gratn read:package scope
# Set ENV VAR
# export GHCR_PAT_TOKEN="your-read-only-token-for-packages"
# export GH_USERNAME="your-git-hub-user-name"
# Log into GHCR to build this image

echo $GHCR_PAT_TOKEN | docker login ghcr.io -u $GH_USERNAME --password-stdin

cd $GAME_COMPONENTS_PATH"/Game"
docker build -t $CONTAINER_URI/game:4.27 -f Dockerfile .

# Build TURN Server image
cd $GAME_COMPONENTS_PATH"/TURN"
docker build -t $CONTAINER_URI/turn -f Dockerfile .

# Build PlayerMonitor image
cd $GAME_COMPONENTS_PATH"/PlayerMonitor"
docker build -t $CONTAINER_URI/playermonitor -f Dockerfile .

# Build ScaleMonitor Image
cd $GAME_COMPONENTS_PATH"/ScaleMonitor"
docker build -t $CONTAINER_URI/scalemonitor -f Dockerfile .

# Log into ACR
az acr login -n $CLUSTER_NAME

# Push images to container registry
docker push $CONTAINER_URI/matchmaker:4.27
docker push $CONTAINER_URI/signallingwebserver:4.27
docker push $CONTAINER_URI/game:4.27
docker push $CONTAINER_URI/turn
docker push $CONTAINER_URI/playermonitor
docker push $CONTAINER_URI/scalemonitor