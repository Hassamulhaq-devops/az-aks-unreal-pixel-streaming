#! /bin/bash

export RG_NAME="pixel_group"

az vm create \
  --resource-group $RG_NAME \
  --location eastus \
  --name gbbpixel \
  --image ubuntults \
  --admin-username azureuser \
  --ssh-key-value ~/.ssh/id_rsa.pub \
  --size Standard_D16s_v3 \
  --os-disk-size-gb 1023 \
  --vnet-name pixel_group-vnet \
  --subnet default \
  --public-ip-address-dns-name gbbpixel