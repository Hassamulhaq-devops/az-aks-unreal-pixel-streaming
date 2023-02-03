#! /bin/bash
# Create Resource Group
source env.rc 

echo "Create RG"

# Need to Register GPU Nodes for AKS
az feature register --namespace "Microsoft.ContainerService" --name "GPUDedicatedVHDPreview"
az feature show --namespace "Microsoft.ContainerService" --name "GPUDedicatedVHDPreview"

az group create \
    --name $RG_NAME \
    --location $LOCATION

echo "Create ACR"
az acr create \
    --name $ACR_NAME \
    --resource-group $RG_NAME \
    --location $LOCATION \
    --sku Standard 

# Create AKS Cluster
echo "Create Cluster"

az aks create \
    --resource-group  $RG_NAME \
    --name $CLUSTER_NAME \
    --enable-managed-identity \
    --node-count 1 \
    --enable-addons monitoring \
    --enable-msi-auth-for-monitoring  \
    --generate-ssh-keys \
    --attach-acr $ACR_NAME

# az aks update -n $CLUSTER_NAME -g $RG_NAME --attach-acr $ACR_NAME
az aks get-credentials -n $CLUSTER_NAME -g $RG_NAME