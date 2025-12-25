# FluxCD GitOps - Service Mesh & DevSecOps

Repository GitOps quản lý infrastructure và applications cho dự án Spring PetClinic Microservices với Service Mesh và DevSecOps.

## 📁 Cấu trúc thư mục

```
flux-gitops/
├── clusters/
│   └── production/              # FluxCD Kustomizations cho production
│       ├── infrastructure.yaml  # Kustomization cho infrastructure
│       └── apps.yaml            # Kustomization cho apps
├── charts/
│   └── petclinic/               # Helm chart cho Spring PetClinic
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── namespace.yaml
│           ├── config-server/
│           ├── discovery-server/
│           ├── api-gateway/
│           ├── customers-service/
│           ├── vets-service/
│           └── visits-service/
├── infrastructure/
│   ├── base/
│   │   ├── istio-system/        # Istio Service Mesh (HelmReleases)
│   │   ├── istio-config/        # mTLS, Authorization, VirtualServices
│   │   │   ├── peer-auth/       # PeerAuthentication (mTLS)
│   │   │   ├── policies/        # AuthorizationPolicy
│   │   │   ├── virtualservices/ # VirtualService với retry
│   │   │   └── gateways/        # Istio Gateway
│   │   ├── kiali/               # Service Mesh visualization
│   │   ├── sonarqube/           # Code quality (SAST)
│   │   ├── jenkins/             # CI/CD pipeline
│   │   └── namespaces/          # Kubernetes namespaces
│   └── overlays/
│       └── production/
└── apps/
    ├── base/
    │   └── petclinic.yaml       # HelmRelease cho petclinic chart
    └── overlays/
        └── production/
```

## 🚀 Triển khai

### Prerequisites
- Kubernetes cluster (đã có)
- kubectl configured
- FluxCD CLI (`flux`)
- GitHub CLI (`gh`) với quyền repo
- Helm 3.x

### Bootstrap FluxCD

```bash
# Export GitHub token
export GITHUB_TOKEN=$(gh auth token)

# Bootstrap FluxCD
flux bootstrap github \
  --owner=KhacThien88 \
  --repository=flux-gitops \
  --branch=main \
  --path=./clusters/production \
  --personal
```

### Kiểm tra trạng thái

```bash
# Check FluxCD status
flux check

# Check Kustomizations
flux get kustomizations

# Check HelmReleases
flux get helmreleases -A

# Check petclinic pods
kubectl get pods -n petclinic
```

## 📦 Helm Chart - PetClinic

### Cấu trúc Services

| Service | Port | Description |
|---------|------|-------------|
| config-server | 8888 | Spring Cloud Config Server |
| discovery-server | 8761 | Eureka Service Discovery |
| api-gateway | 8080 | API Gateway (Spring Cloud Gateway) |
| customers-service | 8080 | Customer & Pet management |
| vets-service | 8080 | Veterinarian management |
| visits-service | 8080 | Visit scheduling |

### Override Values

```yaml
# Ví dụ override trong HelmRelease
values:
  global:
    istio:
      enabled: true
  apiGateway:
    replicaCount: 2
  customersService:
    resources:
      limits:
        memory: 1Gi
```

## 🔒 Service Mesh Features

### mTLS (Mutual TLS)
- STRICT mTLS được enable cho toàn mesh
- Tất cả traffic giữa services được mã hóa
- Cấu hình trong `infrastructure/base/istio-config/peer-auth/`

### Authorization Policies
- Deny-all mặc định trong namespace petclinic
- Chỉ allow traffic theo quy định:
  - `api-gateway` ← `istio-ingressgateway`
  - internal services ← `api-gateway`
  - `config-server` ← all petclinic services
  - `discovery-server` ← all petclinic services
- Cấu hình trong `infrastructure/base/istio-config/policies/`

### Retry Policies
- Tự động retry khi gặp lỗi 5xx
- 3 attempts với perTryTimeout 5-10s
- Cấu hình trong `infrastructure/base/istio-config/virtualservices/`

## 🛡️ DevSecOps Tools

| Tool | Purpose | Namespace |
|------|---------|-----------|
| SonarQube | SAST - Code Quality | sonarqube |
| Jenkins | CI/CD Pipeline | jenkins |
| Snyk | Dependency Scanning | (CLI) |
| OWASP ZAP | DAST | (Pipeline) |
| Gitleaks | Secret Detection | (Pre-commit) |

## 📊 Monitoring & Visualization

- **Kiali**: Service Mesh topology và traffic flow
  ```bash
  kubectl port-forward -n istio-system svc/kiali 20001:20001
  # Access: http://localhost:20001/kiali
  ```

## 🧪 Test Scenarios

### 1. mTLS Test
```bash
# Từ pod không có sidecar, curl sẽ fail
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://api-gateway.petclinic:8080
```

### 2. Authorization Policy Test
```bash
# Tạo pod test trong petclinic namespace
kubectl run test-unauthorized -n petclinic --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://vets-service:8080/vets
# Expected: 403 Forbidden (vì không có SA được authorize)
```

### 3. Retry Test
```bash
# Inject fault 50% error rate
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: vets-fault-injection
  namespace: petclinic
spec:
  hosts:
    - vets-service
  http:
    - fault:
        abort:
          percentage:
            value: 50
          httpStatus: 500
      route:
        - destination:
            host: vets-service
      retries:
        attempts: 3
        perTryTimeout: 5s
        retryOn: 5xx
EOF

# Observe retries in Kiali hoặc qua logs
kubectl logs -n petclinic -l app=api-gateway -c istio-proxy | grep -i retry
```

## 📝 Credentials mặc định

| Service | Username | Password |
|---------|----------|----------|
| SonarQube | admin | admin123 |
| Jenkins | admin | admin123 |

⚠️ **Lưu ý**: Thay đổi credentials sau khi deploy!

## 🔗 Links

- [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)
- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Istio Documentation](https://istio.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
