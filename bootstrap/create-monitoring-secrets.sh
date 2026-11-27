#!/usr/bin/env bash
# monitoring 네임스페이스의 Grafana 관리자 Secret 을 클러스터에 직접 생성 (공개 저장소에 비밀번호를 두지 않기 위함)
# 무작위 비밀번호로 만들고, 이미 있으면 아무것도 하지 않음. 비밀번호 확인:
#   kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
set -euo pipefail

NS=monitoring
kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"
if kubectl -n "$NS" get secret grafana-admin >/dev/null 2>&1; then
  echo "Secret grafana-admin already exists in namespace $NS; nothing to do."
  exit 0
fi
kubectl -n "$NS" create secret generic grafana-admin \
  --from-literal=admin-user=admin --from-literal=admin-password="$(openssl rand -hex 16)"
