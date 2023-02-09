# The Unreal Pixel Streaming On Azure Kubernetes Service!
Reference Repo to deploy Unreal Pixel Streaming on AKS. 

![](img/UEPS.gif)

## Provision the Azure Kubernetes Service

Before you proceed:
 
We provide a set of scripts to automate the setup of the infrastructure needed for this demo. You can find them under `infrastructure/azure-cli`.  

If you want to use these scripts, **the first step** is to open the `env.rc` and fill in the values that reflect your environment. Edit the `env.rc` file under `infrastructure/azure-cli/env.rc` and change the following:

Github settings
| Parameter | Notes
|---|---
| GHCR_PAT_TOKEN | Github PAT token
| GH_USERNAME | Github username

AKS settings
| Parameter | Default Value | Notes
|---|---|---
| RG_NAME | pixel_group | AKS resource group
| CLUSTER_NAME | urpixelstream | AKS cluster name
| ACR_NAME | gbbpixel | Azure Container Registry
| LOCATION | eastus | Location for the cluster
| GPU_NP_SKU | Standard_NC12 | GPU SKU node pool
| TURN_NP_SKU | Standard_F8s_v2 | Turn SKU node pool


## Deploying the cluster
In this initial run of the  `infrastructure/azure-cli/deploy-infra.sh`

### Setup the environment
> NOTE
>
> Ensure you set/change these variables reflect your environment.

```bash
#################################################
# Github credentials
export GHCR_PAT_TOKEN=""
export GH_USERNAME=""
export GIT_REPO_ROOT_PATH=$(git rev-parse --show-toplevel)
export GAME_COMPONENTS_PATH=$GIT_REPO_ROOT_PATH"/game-server-components"

#################################################
# AKS settings
export RG_NAME="pixel_group"
export CLUSTER_NAME="urpixelstream"
export ACR_NAME="gbbpixel"
export LOCATION="eastus"
export GPU_NP_SKU="Standard_NC12"
export TURN_NP_SKU="Standard_F8s_v2"

#################################################
# Build and Push Game Component Containers
# Update your container registry name here
export CONTAINER_REGISTRY_URL="$ACR_NAME.azurecr.io"
export ORG="pixelstream"
export CONTAINER_URI=$CONTAINER_REGISTRY_URL/$ORG
```

### Create Resource Group
```bash
az group create \
    --name $RG_NAME \
    --location $LOCATION
```
### Create Azure Container Registry
```bash
az acr create \
    --name $CLUSTER_NAME \
    --resource-group $RG_NAME \
    --location $LOCATION \
    --sku Standard
```

### Create AKS Cluster
```bash
az aks create \
    --resource-group  $RG_NAME \
    --name $CLUSTER_NAME \
    --node-count 1 \
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
>
> For the Game image, you will need an unreal project that was compiled on a Linux-based machine.
> We provide a sample project that can be used as a starting point [here](https://github.com/appdevgbb/unreal-engine-sample-project)

If you are using this sample project, please do the following.

Steps:
1. git clone https://github.com/appdevgbb/unreal-engine-sample-project.git
1. cd unreal-engine-sample-project
1. docker build -t $CONTAINER_URI/game:4.27 -f Dockerfile .
1. docker push $CONTAINER_URI/game:4.27

For all of the other Docker images:

``` bash
cd game-server-components
./docker-build.sh
```

### Deployment of the Unreal Pixel Streaming On Azure Kubernetes Service

This is reference implementation for autoscaling of signalling servers based on number of connected players. Redis will be a dependency for the game server components to store info about currently connected players.

> NOTE:
>
> Before deploying this solution, edit a kustomization file, found under `manifests/demo/kustomization.yaml`. This file is contains the references for the container images for this solution:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../base
images:
- name: GAME
  newName: gbbpixel.azurecr.io/pixelstream/game
  newTag: "dc-build2"
- name: KUBECTL
  newName: bitnami/kubectl
  newTag: "latest"
- name: MATCHMAKER
  newName: gbbpixel.azurecr.io/pixelstream/matchmaker
  newTag: "4.27"
- name: REDIS
  newName: bitnami/redis
  newTag: "latest"
- name: TURN
  newName: gbbpixel.azurecr.io/pixelstream/turn
  newTag: "latest"
- name: SCALEMONITOR
  newName: gbbpixel.azurecr.io/pixelstream/scalemonitor
  newTag: "latest"
- name: SIGNALLINGWEBSERVER
  newName: gbbpixel.azurecr.io/pixelstream/signallingwebserver
```

In this file, for every `image`, you will be changing the following values:

| Parameter | Notes
|---|---
| newName | The container repository URI of where the container image is located, including the name of the image
| newTag | The version of the container image

After the `manifests/demo/kustomization.yaml` is updated with the values that reflect your environment, you are ready to deploy the solution.

Steps:
1. `cd manifests/demo`
1. `kubectl apply -k `

The final deployment should resemble this:

```bash
kubectl get no,po,svc
NAME                                     STATUS                     ROLES   AGE   VERSION
node/aks-gpunp-41306925-vmss000000       Ready,SchedulingDisabled   agent   13d   v1.24.6
node/aks-gpunp2-32188085-vmss000000      Ready                      agent   8d    v1.24.6
node/aks-nodepool1-21702042-vmss000000   Ready                      agent   13d   v1.24.6
node/aks-turnp-79165077-vmss000000       Ready                      agent   13d   v1.24.6

NAME                                    READY   STATUS    RESTARTS      AGE
pod/matchmaker-64dfdbd8d8-vjnsq         1/1     Running   0             23h
pod/redis-deployment-cff67fd78-vfs8z    1/1     Running   0             23h
pod/scalemonitor-7945bc96c4-cvsqs       1/1     Running   6 (23h ago)   23h
pod/signallingserver-77d7b9576b-p9lss   2/2     Running   0             23h
pod/turnserver-h5lrq                    1/1     Running   0             23h

NAME                       TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)                       AGE
service/kubernetes         ClusterIP      10.0.0.1      <none>           443/TCP                       13d
service/matchmaker         LoadBalancer   10.0.18.167   20.121.108.24    90:30855/TCP,9999:32587/TCP   23h
service/redis              ClusterIP      10.0.58.57    <none>           6379/TCP                      23h
service/signallingserver   LoadBalancer   10.0.17.41    20.121.108.176   80:30051/TCP,8888:31602/TCP   23h
service/turnserver         LoadBalancer   10.0.128.14   52.226.247.199   3478:32187/TCP                23h
```

Finally, you can test scaling up the cluster by adding more players and connecting them to the `signallingserver` service.
` 

![](img/SignallingAutoScale.gif)

## Legal
© 2004-2022, Epic Games, Inc. Unreal and its logo are Epic’s trademarks or registered trademarks in the US and elsewhere. 
