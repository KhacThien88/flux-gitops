# FluxCD GitOps - Service Mesh & DevSecOps

Repository GitOps quản lý infrastructure và applications cho dự án Spring PetClinic Microservices với Service Mesh và DevSecOps.

## 📁 Cấu trúc thư mục

```
flux-gitops/
├── clusters/
│   └── production/              # FluxCD Kustomizations
│       ├── flux-system/         # FluxCD components
│       ├── infrastructure.yaml  # Kustomization cho infrastructure
│       └── apps.yaml            # Kustomization cho apps
│
├── infrastructure/              # CHỈ INSTALL TOOLS
│   ├── base/
│   │   ├── istio-system/        # Istio installation (HelmReleases)
│   │   ├── kiali/               # Kiali installation
│   │   ├── sonarqube/           # SonarQube installation
│   │   ├── jenkins/             # Jenkins installation
│   │   └── namespaces/          # Infrastructure namespaces
│   └── overlays/
│       └── production/
│
├── charts/
│   └── petclinic/               # Helm chart cho Spring PetClinic
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── namespace.yaml
│           ├── config-server/   # Config Server deployment
│           ├── discovery-server/# Eureka deployment
│           ├── api-gateway/     # API Gateway deployment
│           ├── customers-service/
│           ├── vets-service/
│           ├── visits-service/
│           └── istio/           # ⭐ ISTIO CONFIG CHO APP
│               ├── peer-authentication.yaml  # mTLS
│               ├── authorization-policies.yaml
│               ├── virtual-services.yaml     # Retry policies
│               └── gateway.yaml              # Ingress gateway
│
└── apps/
    ├── base/
    │   └── petclinic.yaml       # HelmRelease cho petclinic
    └── overlays/
        └── production/
```

## 🎯 Phân tách rõ ràng

| Folder | Mục đích |
|--------|----------|
| `infrastructure/` | **Install tools**: Istio, Kiali, Jenkins, SonarQube |
| `charts/petclinic/templates/istio/` | **Cấu hình Istio cho app**: mTLS, policies, retry |
| `apps/` | **Deploy application** via HelmRelease |

## 🚀 Triển khai

### Prerequisites
- Kubernetes cluster
- kubectl, helm, flux CLI
- GitHub CLI (`gh`)

### Bootstrap FluxCD

```bash
export GITHUB_TOKEN=$(gh auth token)

flux bootstrap github \
  --owner=KhacThien88 \
  --repository=flux-gitops \
  --branch=main \
  --path=./clusters/production \
  --personal
```

### Kiểm tra trạng thái

```bash
flux get kustomizations
flux get helmreleases -A
kubectl get pods -n petclinic
```

## 📦 Helm Chart - PetClinic

### Services

| Service | Port | Description |
|---------|------|-------------|
| config-server | 8888 | Spring Cloud Config |
| discovery-server | 8761 | Eureka Discovery |
| api-gateway | 8080 | API Gateway |
| customers-service | 8080 | Customers & Pets |
| vets-service | 8080 | Veterinarians |
| visits-service | 8080 | Visits |

### Istio Features (trong chart)

```yaml
# values.yaml
istio:
  authorizationPolicy:
    enabled: true      # Enable/disable authorization
  virtualService:
    enabled: true      # Enable/disable retry policies
    timeout: 15s
    retries:
      attempts: 3
      perTryTimeout: 5s
      retryOn: "5xx,reset,connect-failure"
  gateway:
    enabled: true      # Enable/disable ingress gateway
    host: "*"
```

## 🔒 Service Mesh Features

### mTLS
- STRICT mode trong namespace petclinic
- Tất cả traffic được mã hóa

### Authorization Policies
- Deny-all mặc định
- Allow rules:
  - `istio-ingressgateway` → `api-gateway`
  - `api-gateway` → all services
  - all services → `config-server`, `discovery-server`
  - `customers-service` → `visits-service`

### Retry Policies
- 3 retries khi gặp 5xx
- perTryTimeout: 5s

## 🛡️ DevSecOps Tools

| Tool | Purpose | Namespace |
|------|---------|-----------|
| SonarQube | SAST | sonarqube |
| Jenkins | CI/CD | jenkins |
| Kiali | Mesh visualization | istio-system |

## 🧪 Test Scenarios

### 1. mTLS Test
```bash
# Pod không có sidecar → fail
kubectl run test --image=curlimages/curl --rm -it -- \
  curl http://api-gateway.petclinic:8080
```

### 2. Authorization Test
```bash
# Unauthorized request → 403
kubectl run test -n petclinic --image=curlimages/curl --rm -it -- \
  curl http://vets-service:8080/vets
```

### 3. Retry Test
```bash
# Inject fault và observe retry
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: vets-fault-test
  namespace: petclinic
spec:
  hosts: [vets-service]
  http:
    - fault:
        abort:
          percentage: {value: 50}
          httpStatus: 500
      route:
        - destination: {host: vets-service}
      retries:
        attempts: 3
        retryOn: 5xx
EOF
```

## 📊 Kiali Dashboard

```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
# http://localhost:20001/kiali
```

## 📝 Default Credentials

| Service | User | Password |
|---------|------|----------|
| SonarQube | admin | admin123 |
| Jenkins | admin | admin123 |
