#! /bin/bash

export RG_NAME="pixel_group"
export CLUSTER_NAME="urpixelstream"
export LOCATION="eastus"

# Create Resource Group
az group create \
    --name $RG_NAME \
    --location $LOCATION

# Create AKS Cluster
az aks create \
    -g $RG_NAME \
    -n $CLUSTER_NAME \
    --enable-managed-identity \
    --node-count 1 \
    --enable-addons monitoring \
    --enable-msi-auth-for-monitoring  \
    --generate-ssh-keys