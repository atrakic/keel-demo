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
kubectl --namespace=push-workflow wait --for=condition=Ready pods --timeout=300s -l "app=keel"
kubectl --namespace=push-workflow get pods -l "app=keel"

## 3) App
kubectl apply -f deployment.yaml
kubectl wait --for=condition=Ready pods --timeout=300s -l "app=pushwf"
kubectl expose deployment pushwf --port=80 --target-port=8500
kubectl create ingress pushwf --class=nginx --rule="keel-demo.local/*=pushwf:80"
sleep 3


## 4) Test
GITHUB_ACTOR=${GITHUB_ACTOR:-$(whoami)}
git config --local user.name "$GITHUB_ACTOR"
git config --local user.email "$GITHUB_ACTOR@users.noreply.github.com"
sed -i "s/^var version =.*/var version = $(git rev-parse --short HEAD)/" src/version.go
git add src/version.go
git diff --name-only
git commit --allow-empty -m "e2e: $(shell git rev-parse --short HEAD)"
git push -u origin
sleep 30
curl -fisk localhost:80 -H "Host: keel-demo.local"
kind delete cluster
