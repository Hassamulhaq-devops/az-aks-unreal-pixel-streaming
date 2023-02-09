#! /bin/bash

# Build Jumpbox and linux dev server

# XRDP
# XFCE
# Docker
# https://askubuntu.com/questions/1323601/xrdp-is-quite-slow

export RG_NAME="pixel_group"

az vm create \
  --resource-group $RG_NAME \
  --location eastus \
  --name gbbpixeldev \
  --image ubuntults \
  --admin-username azureuser \
  --ssh-key-value ~/.ssh/id_rsa.pub \
  --size Standard_NC12 \
  --os-disk-size-gb 1023 \
  --vnet-name pixel_group-vnet \
  --subnet default \
  --public-ip-address-dns-name gbbpixeldev