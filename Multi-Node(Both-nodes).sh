#!/bin/bash

# Disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab
mount -a

# Verify swap is disabled
free -h

# Enable IP forwarding for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
sysctl net.ipv4.ip_forward

# Remove old Docker packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg
done

# Update package list
sudo apt-get update

# Install required packages
sudo apt-get install -y ca-certificates curl apt-transport-https gpg

# Create keyrings directory
sudo install -m 0755 -d /etc/apt/keyrings

# Add Docker GPG key
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list
sudo apt-get update

# Install containerd
sudo apt-get install -y containerd.io

# Configure containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sed 's/sandbox_image = "registry.k8s.io\/pause:3.8"/sandbox_image = "registry.k8s.io\/pause:3.10"/' | sudo tee /etc/containerd/config.toml

# Restart and enable containerd
systemctl enable --now containerd
systemctl restart containerd


# Update package list again
sudo apt-get update

# Add Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
sudo apt-get update

# Install Kubernetes components
sudo apt-get install -y kubelet kubeadm kubectl

# Prevent automatic updates of Kubernetes components
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable --now kubelet

# Script completed
echo "Kubernetes setup completed successfully!"

