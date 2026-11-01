#!/usr/bin/env bash
# mlops 네임스페이스의 비밀번호 Secret 을 클러스터에 직접 생성 (공개 저장소에 비밀번호를 두지 않기 위함)
# 무작위 비밀번호로 4개를 한 번에 만들고, 이미 있으면 아무것도 하지 않음
# 주의: PostgreSQL 은 최초 기동 때 이 비밀번호로 사용자를 만들므로, Secret 을 지우고 다시 만들면 DB 와 어긋남
set -euo pipefail

NS=mlops
# SeaweedFS(Kubeflow Pipelines) S3 키: kubeflow/manifests 기본값. KFP 쪽 키를 바꿨다면 같이 지정
S3_ACCESS_KEY=${S3_ACCESS_KEY:-minio}
S3_SECRET_KEY=${S3_SECRET_KEY:-minio123}

kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"
if kubectl -n "$NS" get secret postgres >/dev/null 2>&1; then
  echo "Secrets already exist in namespace $NS; nothing to do."
  exit 0
fi

pw() { openssl rand -hex 16; }
PG=$(pw); MLFLOW_DB=$(pw); FEAST_DB=$(pw); VALKEY=$(pw)
secret() { kubectl -n "$NS" create secret generic "$@" --dry-run=client -o yaml; echo "---"; }

{
  secret postgres \
    --from-literal=POSTGRES_PASSWORD="$PG" \
    --from-literal=MLFLOW_DB_PASSWORD="$MLFLOW_DB" \
    --from-literal=FEAST_DB_PASSWORD="$FEAST_DB"
  secret valkey --from-literal=VALKEY_PASSWORD="$VALKEY"
  secret mlflow \
    --from-literal=MLFLOW_BACKEND_STORE_URI="postgresql://mlflow:$MLFLOW_DB@postgres.$NS.svc.cluster.local:5432/mlflow" \
    --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
  # Feast Operator 는 저장소 타입 이름(sql, redis)을 키로 읽음
  secret feast-data-stores \
    --from-literal=sql="path: postgresql+psycopg://feast:$FEAST_DB@postgres.$NS.svc.cluster.local:5432/feast
cache_ttl_seconds: 60
sqlalchemy_config_kwargs:
  pool_pre_ping: true" \
    --from-literal=redis="connection_string: valkey.$NS.svc.cluster.local:6379,password=$VALKEY"
} | kubectl create -f -
