# The Unreal Pixel Streaming On Azure Kubernetes Service!
Reference Repo to deploy Unreal Pixel Streaming on AKS. 

![](img/UEPS.gif)

## Provision the Azure Kubernetes Service

We provide a set of scripts to automate the setup of the infrastructure needed for this demo. You can find them under `infrastructure/azure-cli`.  If you want to use these scripts, the first step is to open the `env.rc` and fill in the values that reflect your environment. 

In this initial run of the  ```infrastructure/azure-cli/deploy-infra.sh```

**NOTE**: 
> Ensure you set/change the variables `RG_NAME`, `CLUSTER_NAME`, `LOCATION` to suit your needs

```bash
#! /bin/bash

export RG_NAME="pixel_group"
export CLUSTER_NAME="urpixelstream"
export LOCATION="eastus"

# Create Resource Group
az group create \
    --name $RG_NAME \
    --location $LOCATION

# Create Azure Container Registry
az acr create \
    --name $CLUSTER_NAME \
    --resource-group $RG_NAME \
    --location $LOCATION \
    --sku Standard

# Create AKS Cluster
az aks create \
    --resource-group  $RG_NAME \
    --name $CLUSTER_NAME \
    --enable-managed-identity \
    --node-count 1 \
    --enable-addons monitoring \
    --enable-msi-auth-for-monitoring  \
    --generate-ssh-keys \
    --attach-acr $ACR_NAME
```
### Add a GPU nodepool
```infrastructure/azure-cli/create-nodepools.sh```
```bash
# Add a GPU sku nodepool
# Note: Taint the nodepool so that  

az aks nodepool add \
    --resource-group $RG_NAME \
    --cluster-name $CLUSTER_NAME \
    --name gpunp \
    --node-count 1 \
    --node-osdisk-size 250 \
    --mode User \
    --node-vm-size $GPU_NP_SKU \
    --aks-custom-headers UseGPUDedicatedVHD=true \
    --node-taints sku=gpu:NoSchedule
```    

### Add a nodepool for TURN
```infrastructure/azure-cli/create-nodepools.sh```
```bash
az aks nodepool add \
    --resource-group $RG_NAME \
    --cluster-name $CLUSTER_NAME \
    --name turnp \
    --node-count 1 \
    --node-osdisk-size 250 \
    --mode User \
    --enable-node-public-ip \
    --node-vm-size $TURN_NP_SKU \
    --node-taints sku=turn:NoSchedule
```

### Get AKS Credentials to deploy services to AKS
```bash
az aks get-credentials -n $CLUSTER_NAME -g $RG_NAME
```

## Containerize and Deploy Game Server Components

Before you start this section, **YOU MUST JOIN THE EPIC GAMES GitHub ORG** to gain access to the base container image.

Here are the steps needed:

1. Navigate to [Accessing Unreal Engine source code on GitHub](https://www.unrealengine.com/en-US/ue-on-github) to and follow the 6 steps described there.
1. Then you must Log in to [GitHub Container Registry (GHCR)](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry) with a Pat Token [Creating a personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token).
1. Finally, create a Classic PAT token and grant `read:package` scope

After the steps above, populate the following variables. We also provide these variables in the `infrastructure/azure-cli/env.rc` file.

```bash
# Set ENV VAR
export CR_PAT="your-read-only-token-for-packages"
export USERNAME="your-git-hub-user-name"
# Log into GHCR to build this image in an interactive login shell

echo $CR_PAT | docker login ghcr.io -u $USERNAME --password-stdin
```
### Build and Push Matchmaker, Signalling,TURN and Game Images.

We will need to build and push the Game Server Components to our Azure Container Registry (ACR) for use in our AKS Cluster. 

> NOTE:
> For the Game image, you will need an unreal project that was compiled on a Linux-based machine.
> We provide a sample project that can be used as a starting point [here](https://github.com/appdevgbb/unreal-engine-sample-project)

If you are using this sample project, please do the following:

1. git clone https://github.com/appdevgbb/unreal-engine-sample-project.git
1. cd unreal-engine-sample-project
1. docker build -t $CONTAINER_URI/game:4.27 -f Dockerfile .
1. docker push $CONTAINER_URI/game:4.27

For all of the other Docker images:

``` bash
cd game-server-components
./docker-build.sh
```

### Deploy Redis server to store realtime count of current connected players

Redis will be a dependency for the game server components to store info about currently connected  players.

```bash
kubectl apply -f manifests/aks-deploy-redis.yaml
```

### Deploy Pixel Streaming Services on AKS
```bash 
kubectl apply -f manifests/aks-deploy-game-server-components.yaml
```
![](img/aks.png)

# Autoscale Deployment of the Unreal Pixel Streaming On Azure Kubernetes Service!

This is reference implementation for autoscaling of signalling servers based on number of connected players.

### Deploy Autoscaled Pixel Streaming Services on AKS
```bash
kubectl apply -f manifests/aks-deploy-game-server-components-with-autoscale.yaml
```

![](img/SignallingAutoScale.gif)

## Legal
© 2004-2022, Epic Games, Inc. Unreal and its logo are Epic’s trademarks or registered trademarks in the US and elsewhere. 
