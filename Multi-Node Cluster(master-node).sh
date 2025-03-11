#!/bin/bash

set -e  # Exit on error
set -o pipefail  # Exit if any command in a pipeline fails
set -x  # Print commands for debugging

# Define Kubernetes Master Node IP
MASTER_IP="192.168.10.10"
POD_CIDR="192.168.0.0/16"

echo ">>> Checking kubelet status"
sudo systemctl status kubelet --no-pager || true

echo ">>> Pre-pulling Kubernetes images"
kubeadm config images pull

echo ">>> Initializing Kubernetes cluster"
kubeadm init --pod-network-cidr=$POD_CIDR --apiserver-advertise-address=$MASTER_IP

echo ">>> Setting up kubeconfig for user"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo ">>> Deploying Calico CNI for networking"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml

echo ">>> Configuring Kubelet with Master IP"
echo "KUBELET_KUBEADM_ARGS=\"--node-ip=$MASTER_IP --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10\"" | sudo tee /var/lib/kubelet/kubeadm-flags.env

echo ">>> Restarting kubelet"
systemctl restart kubelet
systemctl status kubelet --no-pager

echo ">>> Verifying node status"
kubectl get nodes -o wide

echo ">>> Kubernetes master setup completed!"

echo ">>> Showing Joining token for Worker nodes for join"
sudo kubeadm token create --print-join-command
