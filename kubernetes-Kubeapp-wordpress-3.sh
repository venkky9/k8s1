#!/bin/bash
# Author: Bala
# Email: bakuppus@kubelancer.com
#Describtion: Run this script on Master Node
# OS: Ubuntu 18
# Cloud: AWS


# Install Helm3
# https://github.com/helm/helm/releases

cd ~
wget https://get.helm.sh/helm-v3.2.0-linux-amd64.tar.gz
tar -xvzf helm-v3.2.0-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/
chmod +x /usr/local/bin/helm
helm version

## Install Kubeapps on Helm3
# https://github.com/kubeapps/kubeapps/blob/master/docs/user/getting-started.md

helm repo add bitnami https://charts.bitnami.com/bitnami
kubectl create namespace kubeapps
helm install kubeapps --namespace kubeapps bitnami/kubeapps --set useHelm3=true --set frontend.service.type="LoadBalancer"
sleep 60
kubectl create serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator
kubectl get secret $(kubectl get serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo
export SERVICE_IP=$(kubectl get svc --namespace kubeapps kubeapps --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
echo "Kubeapps URL: http://$SERVICE_IP:80"

## Install wordpress

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  fsType: ext4 
reclaimPolicy: Retain
allowVolumeExpansion: true
mountOptions:
  - debug
volumeBindingMode: Immediate
EOF

# create namespace wordpress  
kubectl create namespace wordpress

# Install wordpress
helm install wordpress bitnami/wordpress --namespace wordpress --set wordpressUsername=wordpress --set wordpressPassword=wordpress  --set global.storageClass=gp2 --set mariadb.rootUser.password=wordpress --set mariadb.db.password=wordpress --set mariadb.master.persistence.storageClass=gp2

export SERVICE_IP=$(kubectl get svc --namespace wordpress wordpress | awk {'print $4'} | tail -n1)
echo "wordpress URL: http://$SERVICE_IP:80"

## END ##

