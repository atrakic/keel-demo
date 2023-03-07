#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

## 1) KinD + ingress
kind create cluster --config config/kind.yaml --wait 60s || true
kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s
kubectl cluster-info
kind get clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

kubectl create namespace push-workflow
kubectl config set-context "$(kubectl config current-context)" --namespace=push-workflow

## 2) KEEL.sh
helm repo add keel https://charts.keel.sh 
helm repo update
helm upgrade --install keel --namespace=push-workflow keel/keel --set helmProvider.enabled="false" --set service.enabled="true" --set service.type="ClusterIP"

## 3) App
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --timeout=300s -l "app=pushwf"
kubectl expose deployment pushwf --port=80 --target-port=8500
kubectl create ingress pushwf --class=nginx --rule="keel-demo.local/*=pushwf:80"
curl -fisk localhost:80 -H "Host: keel-demo.local"
