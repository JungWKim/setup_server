#!/bin/bash

#----------- install basic packages
yum install -y net-tools createrepo nfs-utils

#----------- mount disks
parted -s -a optimal -- /dev/sda mklabel gpt mkpart primary xfs 1 -1
mkdir /data
mkfs.xfs /dev/sda1
echo "/dev/sda1	/data	xfs	defaults	0	0" >> /etc/fstab
mount -a
