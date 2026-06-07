# Petclinic Platform — AWS Infrastructure

Production AWS infrastructure for [Spring Petclinic Microservices](https://github.com/FrankAsanteVanLaarhoven/spring-petclinic-microservices) (8 Spring Boot services, Spring Cloud, ARM64/Graviton).

## Repository Structure

```
petclinic-platform/
│
├── terraform/
│   ├── environments/
│   │   ├── dev/                      # Dev root module
│   │   │   ├── main.tf               # Wires all 7 modules
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── backend.tf            # S3 state: petclinic/dev/terraform.tfstate
│   │   │   ├── providers.tf
│   │   │   └── versions.tf
│   │   └── prod/                     # Prod root module (same structure)
│   └── modules/
│       ├── vpc/                      # VPC, subnets, IGW, 4 SGs (all-public, no NAT — see ADR-0001)
│       ├── eks/                      # EKS 1.29, Graviton node group, OIDC provider
│       ├── ecr/                      # 8 repos per env, lifecycle keeps last 10 images
│       ├── rds/                      # RDS MySQL 8.0, random_password → Secrets Manager
│       ├── secrets/                  # OpenAI API key secret, ESO IAM policy
│       ├── dns/                      # Route 53 hosted zone, ACM wildcard cert, ALB controller policy
│       ├── github-oidc/              # GitHub Actions OIDC provider + ECR-push role
│       ├── karpenter/                # Karpenter NodePool + EC2NodeClass (Spot, ARM64)
│       └── observability/            # Prometheus/Grafana/FluentBit/CloudWatch (future)
│
├── k8s/
│   └── base/                         # Base manifests for all 8 services
│       ├── namespaces.yaml           # petclinic-dev, petclinic-prod
│       ├── config-server/            # deployment, service, serviceaccount, configmap
│       ├── discovery-server/         # + waits for config-server (init container)
│       ├── api-gateway/              # + waits for config-server + discovery-server
│       ├── customers-service/        # + RDS credentials from ExternalSecret
│       ├── visits-service/
│       ├── vets-service/             # Caffeine cache enabled via production profile
│       ├── genai-service/            # + openai-api-key from ExternalSecret
│       ├── admin-server/
│       └── external-secrets/
│           ├── cluster-secret-store.yaml   # ClusterSecretStore → AWS Secrets Manager
│           ├── rds-credentials.yaml        # ExternalSecret → petclinic/{env}/rds
│           └── openai-api-key.yaml         # ExternalSecret → petclinic/{env}/openai
│
├── helm/
│   └── petclinic-service/            # Generic Helm chart shared by all 8 services
│       ├── Chart.yaml
│       ├── values.yaml               # Default values (overridden per service + per env)
│       └── templates/
│           ├── _helpers.tpl          # fullname = Release.Name
│           ├── deployment.yaml       # HPA-aware, init containers, security contexts
│           ├── service.yaml
│           ├── serviceaccount.yaml   # IRSA annotation support
│           ├── configmap.yaml
│           ├── hpa.yaml              # autoscaling/v2, enabled via values
│           └── pdb.yaml              # policy/v1, enabled via values
│
├── helm-values/                      # Per-service and per-env value overrides
│   ├── config-server.yaml
│   ├── discovery-server.yaml
│   ├── api-gateway.yaml
│   ├── customers-service.yaml
│   ├── visits-service.yaml
│   ├── vets-service.yaml
│   ├── genai-service.yaml
│   ├── admin-server.yaml
│   ├── dev.yaml                      # replicaCount: 1, autoscaling disabled
│   └── prod.yaml                     # replicaCount: 2, autoscaling enabled (2-4 pods), PDB
│
├── .github/workflows/
│   └── update-image-tags.yml         # repository_dispatch → yq patch → git commit
│
├── scripts/
│   ├── bootstrap-state.sh            # Create S3 bucket + DynamoDB table for TF state
│   ├── start-env.sh                  # terraform apply for an environment
│   ├── stop-env.sh                   # terraform destroy (cost management)
│   └── env-status.sh                 # Show cluster + RDS status
│
└── docs/
    ├── jira-backlog.md               # Epic tracker and story breakdown
    ├── technical-spec.md             # All infra values, sizing, cost model
    └── adr/
        └── 0001-public-subnets.md    # All-public subnet design (no NAT, ~$50/mo saving)
```

## Tech Stack

| Layer | Tool | Details |
|-------|------|---------|
| Cloud | AWS | eu-central-1 |
| IaC | Terraform >= 1.6 | AWS provider ~> 5.0, S3 + DynamoDB state |
| Cluster | Amazon EKS 1.29 | Graviton t4g.small managed nodes, OIDC federation |
| Registry | Amazon ECR | 8 repos × 2 envs, scan-on-push, keep last 10 images |
| Database | Amazon RDS MySQL 8.0 | db.t4g.micro, single-AZ, utf8mb4 |
| DNS | Route 53 + ACM | Wildcard cert `*.{domain}`, DNS validation |
| Secrets | AWS Secrets Manager + ESO | ExternalSecret CRs, IRSA scoped to `petclinic/{env}/*` |
| Ingress | AWS ALB Ingress Controller | Public ALB → API Gateway service |
| Packaging | Helm | Generic chart, per-service + per-env values |
| CI | GitHub Actions | OIDC → AWS, ARM64 build → ECR push → tag update |
| CD | ArgoCD | GitOps — auto-sync dev, manual sync prod *(E-16/E-17 next)* |
| Node Scaling | Karpenter | NodePool + EC2NodeClass, Spot + ARM64 diversification |

## Environments

| Setting | Dev | Prod |
|---------|-----|------|
| Region | eu-central-1 | eu-central-1 |
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| EKS nodes | 2 × t4g.small (Graviton) | 2 × t4g.small (Graviton) |
| RDS | db.t4g.micro, single-AZ | db.t4g.micro, single-AZ |
| Replicas | 1 per service | 2 per service (HPA 2–4) |
| K8s namespace | `petclinic-dev` | `petclinic-prod` |

## Epic Progress

| Epic | Description | Status | Commit |
|------|-------------|--------|--------|
| E-0 | Claude Code Setup | ✅ Done | — |
| E-1 | Foundation & Remote State | ✅ Done | `7c3a8d6` |
| E-2 | Networking (VPC) | ✅ Done | `d12f791` |
| E-3 | EKS Cluster | ✅ Done | `c7e0800` |
| E-4 | ECR Registry | ✅ Done | `42a8d2e` |
| E-5 | RDS Database | ✅ Done | `5267a1c` |
| E-6 | DNS & TLS | ✅ Done | `e3be546` |
| E-7 | Secrets Management | ✅ Done | `e3be546` |
| E-8 | K8s Base Manifests | ✅ Done | `1b4a5a7` |
| E-9 | Helm Chart | ✅ Done | `189192f` |
| E-10 | CI Pipeline | ✅ Done | `104e625` |
| E-16 | ArgoCD Application CRDs | 🔲 Next | — |
| E-17 | ArgoCD Install Manifests | 🔲 Blocked by E-16 | — |

## Quick Start

### 1. Bootstrap state backend (once per AWS account)

```bash
export AWS_PROFILE=petclinic
export TF_VAR_openai_api_key=sk-...
bash scripts/bootstrap-state.sh
```

### 2. Apply dev environment

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="domain_name=dev.petclinic.example.com" -out plan.out
terraform apply plan.out
```

### 3. Set GitHub Secrets in the app repo

After `terraform apply`, copy the outputs and set these secrets in `FrankAsanteVanLaarhoven/spring-petclinic-microservices`:

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | `terraform output -raw github_actions_role_arn` |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `AWS_REGION` | `eu-central-1` |
| `PLATFORM_REPO_TOKEN` | GitHub PAT with `repo` scope (for repository_dispatch) |

### 4. Deploy a service manually (before ArgoCD)

```bash
# Authenticate kubectl
aws eks update-kubeconfig --region eu-central-1 --name petclinic-dev

# Apply External Secrets prerequisites
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/base/external-secrets/

# Deploy a service
helm upgrade --install config-server helm/petclinic-service/ \
  --namespace petclinic-dev \
  -f helm-values/config-server.yaml \
  -f helm-values/dev.yaml \
  --set image.repository=<ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/petclinic-dev/config-server \
  --set image.tag=<GIT_SHA>
```

## CI/CD Flow

```
App repo push (main branch)
  └─ build-push.yml (in spring-petclinic-microservices)
      ├─ dorny/paths-filter → detect changed services
      ├─ QEMU + Buildx → linux/arm64 Docker image
      ├─ Trivy scan (CRITICAL exit-code 1)
      ├─ Push to ECR: petclinic-dev/{service}:{sha}
      └─ repository_dispatch → pet-clinic repo
           └─ update-image-tags.yml (this repo)
                ├─ yq patch helm-values/{service}.yaml .image.tag
                └─ git commit "ci: update image tags to {sha}"
                     └─ ArgoCD detects change → deploys to EKS (E-16/E-17)
```

## Cost Management

**Rule: always `terraform destroy` after each dev session. The EKS control plane costs $0.10/hr (~$72/mo) whether pods are running or not.**

| Resource | Cost |
|----------|------|
| EKS control plane | $0.10/hr — only unavoidable cost |
| t4g.small nodes (2×) | Free trial until Dec 2026 |
| RDS db.t4g.micro | Free tier (750 hrs/mo) |
| NAT Gateway | $0 — all-public subnet design (ADR-0001) |
| ECR storage | ~$0.01/GB — negligible |
| **Total active session** | ~$0.10/hr |
| **Total per 5-hr session** | ~$0.50 |

```bash
# Destroy dev after each session
bash scripts/stop-env.sh dev

# Recreate next session (takes ~12 min)
bash scripts/start-env.sh dev
```

## Application Services

| Service | Port | MySQL | Waits For |
|---------|------|-------|-----------|
| config-server | 8888 | No | — |
| discovery-server | 8761 | No | config-server |
| api-gateway | 8080 | No | config-server, discovery-server |
| customers-service | 8081 | Yes | config-server, discovery-server |
| visits-service | 8082 | Yes | config-server, discovery-server |
| vets-service | 8083 | Yes | config-server, discovery-server |
| genai-service | 8084 | Optional | config-server, discovery-server |
| admin-server | 9090 | No | config-server, discovery-server |

Startup order enforced via `initContainers` using `busybox:1.36` wget health checks.
