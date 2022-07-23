#!/bin/bash

file_server=192.168.1.59
file_server_id=root
user_home=/root

nvidia_driver=NVIDIA-Linux-x86_64-510.54.run
cuda_runfile=cuda_11.2.0_460.27.04_linux.run
cudnn_archive=cudnn-11.2-linux-x64-v8.1.0.77.tgz

disk_presence=no
gpu_presence=no
docker_install=no
nvidia_docker_install=no
intel_raid_presence=no

cd ${user_home}

#----------- install basic packages
yum install -y net-tools createrepo nfs-utils

#----------- mount disks
if [ ${disk_presence} = yes ] || [ ${disk_presence} = y ] ; then

	parted -s -a optimal -- /dev/sda mklabel gpt mkpart primary xfs 1 -1
	mkdir /data
	mkfs.xfs /dev/sda1
	echo "/dev/sda1	/data	xfs	defaults	0	0" >> /etc/fstab
	mount -a

fi

#----------- prerequisite for installation of nvidia driver / cuda / cudnn

if [ ${gpu_presence} = yes ] || [ ${gpu_presence} = y ] ; then

#----------- download nvidia driver / cuda / cudnn installation files

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

#------------ install nvidia driver / cuda / cudnn
	cat >> ${user_home}/.bashrc << EOF
## CUDA and cuDNN paths
export PATH=/usr/local/cuda/bin:${PATH}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
EOF

	source ${user_home}/.bashrc

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

#------------- install docker -------------
if [ ${docker_install} = yes ] || [ ${docker_install} == y ]; then

	yum install -y yum-utils
	yum-config-manager \
	    --add-repo \
	    https://download.docker.com/linux/centos/docker-ce.repo
	yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
	systemctl start docker
	systemctl enable docker
	
	echo -e "\n\n\n------------------------------------------ docker images -----------------------------------------------"
	docker images
	echo -e "\n\n\n----------------------------------------- docker --version ---------------------------------------------"
	docker --version

fi

#------------- install nvidia docker -------------
if [ ${nvidia_docker_install} = yes ] || [ ${nvidia_docker_install} == y ]; then
	distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
	   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | sudo tee /etc/yum.repos.d/nvidia-docker.repo

	yum clean expire-cache
	yum install -y nvidia-docker2
	systemctl restart docker
	
	echo -e "\n\n\n------------------------------------------ docker images -----------------------------------------------"
	docker images
	echo -e "\n\n\n----------------------------------------- docker --version ---------------------------------------------"
	docker --version
	echo -e "\n\n\n------------------------------------- nvidia-docker --version ------------------------------------------"
	nvidia-container-toolkit

fi

#------------ intel raid web console install
if [ ${intel_raid_presence} = yes ] || [ ${intel_raid_presence} = y ]; then

	scp ${file_server_id}@${file_server}:/root/files/Intel_RWC3_Linux_007.019.006.000.zip .
	unzip Intel_RWC3_Linux_007.019.006.000.zip
	cd Intel_RWC3_Linux_007.019.006.000/x64
	chmod a+x *.sh
	./install.sh
	cd ${user_home}

fi
