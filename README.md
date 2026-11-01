# kubeflow-argo

Argo CD ApplicationSet 으로 Kubeflow 와 MLOps 플랫폼(MLflow, Feast)을 설치하는 GitOps 저장소입니다.
[gasida/kubeflow-argo](https://github.com/gasida/kubeflow-argo) 를 fork 해서 다음을 바꿨습니다.

| 항목 | 원본 | 이 저장소 |
|---|---|---|
| Kubeflow | 1.7 기반 manifests 를 저장소에 복사 (Istio 1.16) | 공식 [kubeflow/manifests](https://github.com/kubeflow/manifests) **26.03.1** 을 원격 참조 (복사하지 않음) |
| 오브젝트 저장소 | MinIO | **SeaweedFS** (Kubeflow Pipelines 기본값, MLflow·Feast 도 같이 사용) |
| MLflow | 없음 | **3.17.2** (PostgreSQL + SeaweedFS) |
| Feast | 없음 | **0.67.0** Operator (레지스트리 PostgreSQL, 온라인 스토어 **Valkey 9.2**) |
| 배포 방식 | App of Apps (Application 15개 파일) | Root Application → **ApplicationSet 2개** (디렉터리 = 앱) |
| Argo CD | v2.6.7 | **v3.5.6** |

## 구조

```
bootstrap/
  argocd/              # Argo CD 설치 (NodePort 30001)
  create-secrets.sh    # mlops 네임스페이스 비밀번호 Secret 생성 (저장소에 비밀번호를 두지 않음)
  root.yaml            # Root Application → appsets/
appsets/
  kubeflow.yaml        # kubeflow/* 디렉터리마다 Application 생성
  platform.yaml        # platform/* 디렉터리마다 Application 생성 (namespace: mlops)
kubeflow/              # kubeflow/manifests@26.03.1 원격 참조 + 필요한 패치만
  cert-manager  istio  auth  kubeflow-base  pipelines  dashboard  notebooks  user-namespace
platform/
  postgres  valkey  mlflow  feast-operator  feast
```

- 앱 추가: `kubeflow/` 또는 `platform/` 아래에 kustomization 디렉터리를 만들면 ApplicationSet 이 Application 을 자동으로 만듭니다.
- Kubeflow 버전 올리기: `kubeflow/*/kustomization.yaml` 의 `?ref=26.03.1` 을 새 태그로 바꿉니다.
- 앱 간 순서(CRD → CR 등)는 sync wave 대신 재시도(최대 20회, 최대 5분 간격)로 맞춥니다. 처음 설치할 때 일부 앱이 잠시 Degraded/OutOfSync 로 보이는 것은 정상입니다.

## 구성 요소

| 앱 | 내용 | 버전 |
|---|---|---|
| cert-manager | 웹훅 인증서, Kubeflow self-signed ClusterIssuer | 1.20.2 |
| istio | Istio (CNI 모드), ingressgateway NodePort 30080/30443 | 1.30.1 |
| auth | oauth2-proxy + Dex | 7.15.2 / 2.45.1 |
| kubeflow-base | kubeflow 네임스페이스, 역할, kubeflow-gateway (+HTTPS) | - |
| pipelines | Kubeflow Pipelines (멀티유저) + SeaweedFS | 2.16.1 / 4.00 |
| dashboard | Central Dashboard, Profiles(KFAM), PodDefaults 웹훅 | 2.0.0 |
| notebooks | Notebook 컨트롤러, Jupyter/Volumes/Tensorboards 웹앱 | 1.11.0 |
| user-namespace | 기본 Profile `kubeflow-user-example-com` | - |
| postgres | MLflow·Feast 공용 DB | 18.6 |
| valkey | Feast 온라인 스토어 | 9.2 |
| mlflow | 트래킹 서버 + 모델 레지스트리 | 3.17.2 |
| feast-operator / feast | Feast Operator, FeatureStore `mlops` (+UI) | 0.67.0 |

## 사전 조건

- Kubernetes 1.36 (kubeflow/manifests 26.03.1 테스트 버전), 기본 StorageClass (예: local-path)
- CNI 가 Cilium 이면 `cni.exclusive: false` (Istio CNI 를 체이닝하기 위함. kubespray: `cilium_cni_exclusive: false`)
- 워커 메모리 합계 약 16 GiB 이상 권장

## 설치

```bash
# 1. Argo CD
kubectl apply -k bootstrap/argocd --server-side --force-conflicts
kubectl -n argocd rollout status deploy/argocd-applicationset-controller deploy/argocd-repo-server

# 2. mlops 비밀번호 Secret (최초 1회)
./bootstrap/create-secrets.sh

# 3. Root Application → ApplicationSet → 모든 앱
kubectl apply -f bootstrap/root.yaml
```

## 접속

| 서비스 | 주소 | 계정 |
|---|---|---|
| Argo CD | https://<노드 IP>:30001 | `admin` / `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Kubeflow | https://<노드 IP>:30443 | `user@example.com` / `12341234` |
| MLflow | http://<노드 IP>:30500 | 없음 |
| Feast UI | `kubectl -n mlops port-forward svc/feast-mlops-ui 8888:80` → http://localhost:8888 | 없음 |

Kubeflow 웹앱은 Secure 쿠키를 쓰므로 HTTPS(30443)로 접속해야 로그인됩니다. 인증서는 self-signed 라서 브라우저 경고가 한 번 나옵니다.

## 주의

- Dex 기본 사용자 비밀번호(`12341234`)와 SeaweedFS S3 키(`minio`/`minio123`)는 kubeflow/manifests 기본값입니다. 홈랩 내부망 전용으로만 쓰고, 외부에 노출한다면 [Kubeflow 문서](https://github.com/kubeflow/manifests#change-default-user-password)대로 바꾸세요.
- MLflow 는 인증 없이 NodePort 로 열려 있습니다.
