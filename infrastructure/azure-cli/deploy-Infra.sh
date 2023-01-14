#! /bin/bash
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

