#! /bin/bash
#################################################
source env.rc 

# Build and Push Game Component Containers

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