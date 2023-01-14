# Update your container registry name here
export CONTAINER_REGISTRY_URL="$CLUSTER_NAME.azurecr.io"
export ORG="pixelstream"
export CONTAINER_URI=$CONTAINER_REGISTRY_URL/$ORG

# Build Matchmaker image
cd Matchmaker/platform_scripts/bash
docker build -t $CONTAINER_URI/matchmaker:4.27 -f Dockerfile ../..

# Build Signalling image
cd SignallingWebServer/platform_scripts/bash/
docker build -t $CONTAINER_URI/signallingwebserver:4.27 -f ./Dockerfile ../..

# Build Unreal Engine App image . Copy the Dockerfile to the root of the Unreal Engine App
## ***NOTE*** YOU MUST JOIN THE EPIC GAMES GitHub ORG to access the base container image
## https://www.unrealengine.com/en-US/ue-on-github
## Then you must Log in to GitHub Container Registry (GHCR) with a Pat Token
## https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry
## Create a Classic PAT token and gratn read:package scope
# Set ENV VAR
# export CR_PAT="your-read-only-token-for-packages"
# export USERNAME="your-git-hub-user-name"
# Log into GHCR to build this image

cd Game
docker build -t $CONTAINER_URI/game:4.27 -f Dockerfile .

# Build TURN Server image
cd TURN
docker build -t $CONTAINER_URI/turn -f Dockerfile .

# Build PlayerMonitor image
cd PlayerMonitor
docker build -t $CONTAINER_URI/playermonitor -f Dockerfile .

# Build ScaleMonitor Image
cd ScaleMonitor
docker build -t $CONTAINER_URI/scalemonitor -f Dockerfile .

# Tag and push images to container registry
# docker tag matchmaker:4.27 $CONTAINER_URI/matchmaker:4.27
# docker tag signallingwebserver:4.27 $CONTAINER_URI/signallingwebserver:4.27
# docker tag game:4.27 $CONTAINER_URI/game:4.27
# docker tag turn $CONTAINER_URI/turn
# docker tag playermonitor $CONTAINER_URI/playermonitor
# docker tag scalemonitor $CONTAINER_URI/scalemonitor
docker push $CONTAINER_URI/matchmaker:4.27
docker push $CONTAINER_URI/signallingwebserver:4.27
docker push $CONTAINER_URI/game:4.27
docker push $CONTAINER_URI/turn
docker push $CONTAINER_URI/playermonitor
docker push $CONTAINER_URI/scalemonitor