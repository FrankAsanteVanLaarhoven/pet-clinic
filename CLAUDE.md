# Petclinic Platform — Claude Code Instructions

This repo contains ALL infrastructure code for deploying Spring Petclinic Microservices to AWS.
The application repo (spring-petclinic-microservices) is READ-ONLY — never modify it.

## Workspace Architecture

```
IDE:          Antigravity IDE (Google, Gemini-backed)
Coding Agent: Claude Code  → claude mcp serve  (Anthropic Sonnet)
Local LLM:    Ollama        → http://localhost:11434/v1  (gpt-oss:20b, qwen2.5-coder:32b)
```

### When to use which agent

| Task | Use |
|------|-----|
| Complex architecture, multi-file refactor, security review | Claude Code (Anthropic) |
| Quick completions, boilerplate, fast iteration | Ollama gpt-oss:20b |
| Large code exploration (32B context) | Ollama qwen2.5-coder:32b |
| AWS/GCP infra knowledge, pricing, documentation | Antigravity + AWS MCP |
| Terraform write/validate/plan | Claude Code + terraform MCP |

## Directory Layout

```
terraform/environments/{dev,prod}/          # Root modules (one per environment)
terraform/modules/{vpc,eks,ecr,rds,dns,secrets,github-oidc,karpenter,observability}/
helm/petclinic-service/                     # Generic Helm chart (shared by all 8 services)
helm-values/{service}.yaml                  # Per-service overrides (8 files)
helm-values/{dev,prod}.yaml                 # Per-env overrides
k8s/base/{service}/                         # deployment, service, serviceaccount, configmap
k8s/base/external-secrets/                  # ClusterSecretStore + 2 ExternalSecret CRs
k8s/base/namespaces.yaml
k8s/argocd/install/                         # ArgoCD installation manifests (E-17, next)
k8s/argocd/applications/{dev,prod}/         # ArgoCD Application CRDs (E-16, next)
.github/workflows/update-image-tags.yml     # repository_dispatch → yq patch → git commit
scripts/{bootstrap-state,start-env,stop-env,env-status}.sh
docs/{jira-backlog,technical-spec}.md
```

## Autonomous Task Execution

Claude Code is authorised to autonomously execute the following without asking:
- Read any file in this repo
- Write/edit Terraform, Helm, K8s YAML, GitHub Actions YAML in this repo
- Run `terraform fmt`, `terraform validate`, `helm template`, `helm lint`
- Run `git add`, `git commit`, `git diff`, `git status`, `git log`
- Run `checkov`, `trivy`, `kube-score` scans
- Run `kubectl get/describe/logs` (read-only kubectl)
- Run `aws sts get-caller-identity` (identity check only)

Claude Code MUST ask before:
- `terraform plan` or `terraform apply` (always confirm env + save plan.out first)
- `kubectl apply/delete/patch` in prod namespace
- `git push`
- Any AWS API call that creates or deletes resources

## Terraform Conventions

- **Provider:** AWS provider ~> 5.0, region eu-central-1
- **State:** S3 + DynamoDB locking, key pattern: `petclinic/{env}/terraform.tfstate`
- **Modules:** `terraform/modules/`. Environments call modules.
- **Naming:** `petclinic-{env}-{resource}`
- **Tagging:** `Project=petclinic`, `Environment={dev|prod}`, `ManagedBy=terraform` on every resource
- **Files per module:** `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- Always run `terraform fmt -recursive` before committing

## Kubernetes Conventions

- **Namespaces:** `petclinic-dev`, `petclinic-prod`
- **Probes:** Every Deployment MUST have readinessProbe + livenessProbe on `/actuator/health/{readiness,liveness}`
- **Resources:** Every container — requests: 128Mi/100m, limits: 512Mi/500m
- **Image tags:** Commit SHA, never `latest` in production
- **Secrets:** ExternalSecret CRs → AWS Secrets Manager only
- **Startup order:** Config Server → Discovery Server → all others (init containers)

## Helm Conventions

- Single generic chart in `helm/petclinic-service/` shared by all 8 services
- Per-service config in `helm-values/{service}.yaml`
- Per-env config in `helm-values/{dev,prod}.yaml`

## ArgoCD GitOps

- CI pushes images. ArgoCD deploys. GitHub Actions NEVER runs `kubectl apply`.
- Dev: auto-sync. Prod: manual sync.

## Security Rules (NON-NEGOTIABLE)

1. No secrets in code — use AWS Secrets Manager + External Secrets Operator
2. No public S3 buckets
3. No 0.0.0.0/0 ingress except ALB on 80/443
4. Encryption everywhere (RDS, S3, EBS)
5. Least privilege IAM
6. Never `terraform destroy` without explicit user approval

## Application Services (8 total)

| Service | Port | Needs MySQL |
|---------|------|-------------|
| config-server | 8888 | No |
| discovery-server | 8761 | No |
| api-gateway | 8080 | No |
| customers-service | 8081 | Yes |
| visits-service | 8082 | Yes |
| vets-service | 8083 | Yes |
| genai-service | 8084 | Optional |
| admin-server | 9090 | No |

## Jira Backlog Progress

Work tracked in `docs/jira-backlog.md`. Current status:

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
| E-16 | ArgoCD Application CRDs | ✅ Done | `1f9fa89` |
| E-17 | ArgoCD Install Manifests | ✅ Done | `1f9fa89` |
| E-18 | ESO + ALB Controller (addons) | ✅ Done | `b54d3f5` |
| E-11 | Observability (Prometheus/Grafana) | ✅ Done | `c482455` |
| E-13 | Security & Compliance | ✅ Done | `c482455` |
| E-14 | Karpenter autoscaler | ✅ Done | `c482455` |
| E-15 | Prod Environment Terraform | ✅ Done | `f281285` |
| E-12 | App repo fork CI/CD | ✅ Done | `f281285` |

## AWS Environment

| Setting | Dev | Prod |
|---------|-----|------|
| Region | eu-central-1 | eu-central-1 |
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| EKS nodes | 2x t4g.small ARM | 2x t4g.small ARM |
| RDS | db.t4g.micro, single-AZ | db.t4g.micro, single-AZ |
| K8s namespace | petclinic-dev | petclinic-prod |

## MCP Servers Active

| Server | Purpose |
|--------|---------|
| `claude-code` | Full coding agent (Anthropic Sonnet) |
| `ollama` | Local LLM inference (gpt-oss:20b) |
| `filesystem` | Direct repo file access |
| `terraform` | HashiCorp Terraform docs + execution |
| `aws-knowledge-mcp` | AWS documentation |
| `awslabs.aws-pricing-mcp-server` | Cost estimation |
| `context7` | Library documentation (live) |

## Technical Spec

All infrastructure values in `docs/technical-spec.md`. Read it before implementing any story.
