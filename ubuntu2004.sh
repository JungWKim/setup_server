#!/bin/bash

file_server=192.168.1.59
file_server_id=root
user_home=/home/sadmin
disk_presence=no
gpu_presence=no

cd ${user_home}

#----------- install basic packages
sed -i 's/1/0/g' /etc/apt/apt.conf.d/20auto-upgrades
apt install -y net-tools nfs-common

#----------- mount disks
if [ ${disk_presence} = yes ] || [ ${disk_presence} = y ] ; then

	parted -s -a optimal -- /dev/sdb mklabel gpt mkpart primary xfs 1 -1
	mkdir /data
	mkfs.xfs /dev/sdb1
	echo "/dev/sdb1	/data	xfs	defaults	0	0" >> /etc/fstab
	mount -a

fi

#----------- prerequisite for installation of nvidia driver / cuda / cudnn

if [ ${gpu_presence} = yes ] || [ ${gpu_presence} = y ] ; then

#----------- download nvidia driver / cuda / cudnn installation files
	scp ${file_server_id}@${file_server}:/root/files/NVIDIA-Linux-x86_64-510.54.run .
	scp ${file_server_id}@${file_server}:/root/files/cuda_11.2.0_460.27.04_linux.run .
	scp ${file_server_id}@${file_server}:/root/files/cudnn-11.2-linux-x64-v8.1.0.77.tgz .


	apt remove Nvidia* && sudo apt autoremove
	apt update
	apt install -y build-essential
	apt install -y linux-headers-generic
	apt install -y dkms

	cat >> /etc/modprobe.d/blacklist.conf << EOF
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

	echo options nouveau modeset=0 | sudo tee -a /etc/modprobe.d/nouveau-kms.conf
	update-initramfs -u

#------------ install nvidia driver / cuda / cudnn
	cat >> ${user_home}/.bashrc << EOF
## CUDA and cuDNN paths
export PATH=/usr/local/cuda/bin:${PATH}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
EOF
	source ${user_home}/.bashrc

	sh NVIDIA-Linux-x86_64-510.54.run
	sh cuda_11.2.0_460.27.04_linux.run

	tar -zxvf cudnn-11.2-linux-x64-v8.1.0.77.tgz 
	cp cuda/include/cudnn*.h /usr/local/cuda/include
	cp cuda/lib64/libcudnn* /usr/local/cuda/lib64
	chmod a+r /usr/local/cuda/include/cudnn*.h /usr/local/cuda/lib64/libcudnn*

#------------ install docker && nvidia container runtime
	git clone https://github.com/JungWKim/Docker_NvidiaDocker_Install_Ubuntu20.04.git
	mv Docker_NvidiaDocker_Install_Ubuntu20.04/docker_nvidiaDocker_install_Ubuntu20.04.sh .
	rm -rf Docker_NvidiaDocker_Install_Ubuntu20.04
	./docker_nvidiaDocker_install_Ubuntu20.04.sh 

#------------ download gpu-burn
	git clone https://github.com/wilicc/gpu-burn

	cd ${user_home}

fi
