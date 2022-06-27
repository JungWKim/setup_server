#!/bin/bash

user_home=/home/gpuadmin

#----------- download nvidia driver / cuda / cudnn installation files
cd ${user_home}
scp root@192.168.1.59:/root/files/NVIDIA-Linux-x86_64-510.54.run .
scp root@192.168.1.59:/root/files/cuda_11.2.0_460.27.04_linux.run .
scp root@192.168.1.59:/root/files/cudnn-11.2-linux-x64-v8.1.0.77.tgz .

#----------- install basic packages
yum install -y net-tools createrepo nfs-utils

#----------- mount disks
parted -s -a optimal -- /dev/sda mklabel gpt mkpart primary xfs 1 -1
mkdir /data
mkfs.xfs /dev/sda1
echo "/dev/sda1	/data	xfs	defaults	0	0" >> /etc/fstab
mount -a

yum update -y
yum groupinstall "Development Tools" -y
yum install kernel-devel epel-release wget -y
yum install dkms -y

touch /etc/modprobe.d/blacklist.conf
echo >> /etc/modprobe.d/blacklist.conf <<EOF
blacklist nouveau 
options nouveau modeset=0
EOF

mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r)-backup.img
dracut

sed -i 's/rhgb quiet/rhgb quiet nouveau.modeset=0 modprobe.blacklist=nouveau rd.driver.blacklist=nouveau/g' /etc/default/grub

grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg

cat >> ${user_home}/.bashrc << EOF
## CUDA and cuDNN paths
export PATH=/usr/local/cuda/bin:${PATH}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
EOF
source i${user_home}/.bashrc

tar -zxvf cudnn-11.2-linux-x64-v8.1.0.77.tgz 

#------------ install docker && nvidia container runtime
git clone https://github.com/JungWKim/Docker_NvidiaDocker_Install_CentOS7.9.git
mv Docker_NvidiaDocker_Install_CentOS7.9/docker_nvidiaDocker_install_CentOS7.9.sh .
rm -rf Docker_NvidiaDocker_Install_CentOS7.9
chmod a+x docker_nvidiaDocker_install_CentOS7.9.sh
./docker_nvidiaDocker_install_CentOS7.9.sh
