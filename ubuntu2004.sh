#!/bin/bash

file_server=192.168.1.59
file_server_id=root
user_home=/home/sadmin

nvidia_driver=NVIDIA-Linux-x86_64-510.54.run
cuda_runfile=cuda_11.2.0_460.27.04_linux.run
cudnn_archive=cudnn-11.2-linux-x64-v8.1.0.77.tgz

disk_presence=no
gpu_presence=no
docker_install=no
nvidia_docker_install=no
intel_raid_presence=no

cd ${user_home}

#----------- prevent package auto upgrade
sed -i 's/1/0/g' /etc/apt/apt.conf.d/20auto-upgrades

#----------- install basic packages
apt install -y net-tools nfs-common xfsprogs

#----------- mount disks
if [ ${disk_presence} = yes ] || [ ${disk_presence} = y ] ; then

	parted -s -a optimal -- /dev/sdb mklabel gpt mkpart primary xfs 1 -1
	mkdir /data
	mkfs.xfs /dev/sdb1
	echo "/dev/sdb1	/data	xfs	defaults	0	0" >> /etc/fstab
	mount -a

fi

#----------- install nvidia driver / cuda / cudnn

if [ ${gpu_presence} = yes ] || [ ${gpu_presence} = y ] ; then

#----------- download nvidia driver / cuda / cudnn installation files

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

	rmmod nouveau
	
	scp ${file_server_id}@${file_server}:/root/files/${nvidia_driver} .
	scp ${file_server_id}@${file_server}:/root/files/${cuda_runfile} .
	scp ${file_server_id}@${file_server}:/root/files/${cudnn_archive} .

	sh ${nvidia_driver}
	nvidia-smi
	sh ${cuda_runfile}

	tar -zxvf ${cudnn_archive}
	cp cuda/include/cudnn*.h /usr/local/cuda/include
	cp cuda/lib64/libcudnn* /usr/local/cuda/lib64
	chmod a+r /usr/local/cuda/include/cudnn*.h /usr/local/cuda/lib64/libcudnn*

#------------ download gpu-burn
	git clone https://github.com/wilicc/gpu-burn
	cd ${user_home}

fi

#------------ install docker
if [ ${docker_install} = yes ] || [ ${docker_install} = y ] ; then

	apt update
	apt install -y ca-certificates curl gnupg lsb-release
	mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt update
	apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

	echo -e "\n\n\n------------------------------------------ docker images -----------------------------------------------"
	docker images
	echo -e "\n\n\n----------------------------------------- docker --version ---------------------------------------------"
	docker --version

fi

#------------- install nvidia docker
if [ ${nvidia_docker_install} = yes ] || [ ${nvidia_docker_install} = y ] ; then

	distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
	curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
	curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
 	apt update && apt install -y nvidia-container-toolkit
	systemctl restart docker

	echo -e "\n\n\n------------------------------------------ docker images -----------------------------------------------"
	docker images
	echo -e "\n\n\n----------------------------------------- docker --version ---------------------------------------------"
	docker --version
	echo -e "\n\n\n------------------------------------- nvidia-docker --version ------------------------------------------"
	nvidia-container-toolkit

fi

#------------ install intel raid web console
if [ ${intel_raid_presence} = yes ] || [ ${intel_raid_presence} = y ] ; then

	apt install -y unzip
	scp ${file_server_id}@${file_server}:/root/files/Intel_RWC3_Linux_007.019.006.000.zip .
	unzip Intel_RWC3_Linux_007.019.006.000.zip
	cd Intel_RWC3_Linux_007.019.006.000/x64
	chmod a+x *.sh
	./install_deb.sh
	cd ${user_home}

fi
