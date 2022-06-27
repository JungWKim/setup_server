#!/bin/bash

sed -i 's/1/0/g' /etc/apt/apt.conf.d/20auto-upgrades
apt install -y net-tools nfs-common
parted -s -a optimal -- /dev/sda mklabel gpt mkpart primary xfs 1 -1
mkdir /data
mkfs.xfs /dev/sda1
echo "/dev/sda1	/data	xfs	defaults	0	0" >> /etc/fstab
mount -a
