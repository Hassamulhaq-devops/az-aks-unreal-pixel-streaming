#!/bin/bash
source env.rc

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
    --node-taints sku=gpu:NoSchedule
    
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
    --node-taints sku=turn:NoSchedule