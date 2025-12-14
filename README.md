# Terraform Provisioning

AWS 인프라 및 SaaS 서비스를 코드로 관리하는 Terraform 프로젝트입니다.  
**Atlantis**를 통한 GitOps 기반 인프라 자동화를 지원합니다.

---

## 📋 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [프로젝트 구조](#프로젝트-구조)
- [관리 리소스](#관리-리소스)
- [Atlantis 워크플로우](#atlantis-워크플로우)
- [시작하기](#시작하기)
- [Terraform 예제](#terraform-예제)
- [코딩 컨벤션](#코딩-컨벤션)
- [문제 해결](#문제-해결)

---

## 개요

이 프로젝트는 다음을 목표로 합니다:

| 목표 | 설명 |
|------|------|
| **Infrastructure as Code** | 모든 인프라를 Terraform 코드로 버전 관리 |
| **GitOps** | PR 기반 인프라 변경 및 리뷰 (Atlantis 활용) |
| **멀티 서비스** | AWS, GitHub, Datadog, Sumo Logic 통합 관리 |
| **보안** | SOPS를 통한 민감 정보 암호화 |

### 기술 스택

| 기술 | 버전 | 용도 |
|------|------|------|
| Terraform | 1.3.7 ~ 1.7.0 | Infrastructure as Code |
| Atlantis | - | GitOps 자동화 |
| SOPS | 3.7.x | 시크릿 암호화 |
| AWS KMS | - | 암호화 키 관리 |

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GitHub Repository                              │
│                      (terraform-provisioning)                            │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │ Webhook (PR 이벤트)
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Atlantis Server (ECS)                            │
│                                                                          │
│   PR 생성 → terraform plan 자동 실행 → PR 코멘트로 결과 표시            │
│   'atlantis apply' 코멘트 → terraform apply 실행                        │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Workflow:id │  │Workflow:    │  │Workflow:    │  │Workflow:    │    │
│  │ (AWS 인프라)│  │github       │  │datadog      │  │sumologic    │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
└─────────┼────────────────┼────────────────┼────────────────┼───────────┘
          │                │                │                │
          ▼                ▼                ▼                ▼
┌─────────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐
│  AWS Account    │ │   GitHub    │ │   Datadog   │ │   Sumo Logic    │
│ (066346343248)  │ │     API     │ │     API     │ │      API        │
│  zerone-id      │ │             │ │             │ │                 │
└─────────────────┘ └─────────────┘ └─────────────┘ └─────────────────┘
```

---

## 프로젝트 구조

```
terraform-provisioning/
│
├── atlantis.yaml              # Atlantis 프로젝트 및 워크플로우 설정
├── README.md                  # 프로젝트 문서 (현재 파일)
│
├── scripts/                   # 유틸리티 스크립트
│   └── terraform_setup.sh     # AWS Assume Role 설정 헬퍼
│
├── terraform/                 # ──────── AWS 인프라 ────────
│   ├── init/                  # Terraform 백엔드 (S3 + DynamoDB)
│   │   └── zerone-id/         #   └─ State 저장소 및 Lock 테이블
│   │
│   ├── vpc/                   # 네트워크 인프라
│   │   ├── tmcd_apnortheast2/ #   └─ VPC, Subnet, NAT GW, IGW
│   │   └── testd_apnortheast2/
│   │
│   ├── iam/                   # IAM 리소스
│   │   └── zerone-id/         #   └─ Role, Policy, User
│   │
│   ├── kms/                   # 암호화 키
│   │   └── zerone-id/         #   └─ KMS Key
│   │
│   ├── ssm/                   # Parameter Store
│   │   └── zerone-id/         #   └─ 애플리케이션 설정, 시크릿
│   │
│   ├── secretsmanager/        # Secrets Manager
│   │   └── zerone-id/         #   └─ 민감 정보 관리
│   │
│   ├── ecr/                   # Container Registry
│   │   └── zerone-id/         #   └─ Docker 이미지 저장소
│   │
│   ├── ecs/                   # ECS 컨테이너 서비스
│   │   ├── demo/              #   └─ Cluster, Service, Task Definition
│   │   └── nginx/
│   │
│   ├── eks/                   # Kubernetes (EKS)
│   │   ├── _module/           #   └─ 클러스터, 노드 그룹, Add-ons
│   │   └── tmcd_apnortheast2/ #      Karpenter, External DNS 등
│   │
│   ├── s3/                    # S3 버킷
│   ├── acm/                   # SSL/TLS 인증서
│   ├── route53/               # DNS 관리
│   ├── securitygroup/         # 보안 그룹
│   ├── codebuild/             # CI 빌드 파이프라인
│   ├── codedeploy/            # CD 배포 자동화
│   ├── platform/              # 플랫폼 도구 (Jenkins)
│   ├── services/              # 애플리케이션 서비스
│   └── variables/             # 공통 변수 정의
│
├── github/                    # ──────── GitHub 리소스 ────────
│   ├── _module/action/        # GitHub Actions Secret 모듈
│   ├── springboot-sample/     # 샘플 앱 레포 시크릿 관리
│   └── terraform-provisioning/# 이 레포의 Actions 시크릿
│
├── datadog/                   # ──────── Datadog 모니터링 ────────
│   ├── integration/           # AWS 연동 설정
│   ├── monitor/               # 알림 규칙 (Atlantis 모니터링 등)
│   └── dashboard/             # 커스텀 대시보드
│
├── sumologic/                 # ──────── Sumo Logic 로그 ────────
│   ├── collector/             # Hosted Collector
│   ├── partition/             # 데이터 파티셔닝
│   └── sources/vpcflow/       # VPC Flow 로그 수집
│
└── example/                   # ──────── Terraform 학습 예제 ────────
    ├── condition/             # 조건문 예제
    │   ├── simple/            #   └─ count 조건부 생성
    │   ├── complex/           #   └─ 복잡한 조건 로직
    │   ├── pre_post/          #   └─ precondition/postcondition
    │   └── assert/            #   └─ check 블록
    └── iteration/             # 반복문 예제
        ├── count/             #   └─ count 반복
        ├── for_each/          #   └─ for_each 맵/셋 반복
        └── dynamic_block/     #   └─ dynamic 블록
```

---

## 관리 리소스

### AWS 인프라 (`terraform/`)

| 디렉토리 | 리소스 | 설명 |
|----------|--------|------|
| `init/` | S3, DynamoDB | Terraform State 저장소 및 Lock |
| `vpc/` | VPC, Subnet, NAT/IGW | 네트워크 인프라 |
| `iam/` | Role, Policy, User | 접근 권한 관리 |
| `kms/` | KMS Key | 데이터 암호화 |
| `ssm/` | Parameter Store | 설정 및 시크릿 |
| `secretsmanager/` | Secrets Manager | 민감 정보 |
| `ecr/` | ECR Repository | 컨테이너 이미지 |
| `ecs/` | ECS Cluster/Service | 컨테이너 오케스트레이션 |
| `eks/` | EKS Cluster | Kubernetes |
| `s3/` | S3 Bucket | 객체 스토리지 |
| `acm/` | Certificate | SSL/TLS 인증서 |
| `route53/` | Hosted Zone | DNS |
| `securitygroup/` | Security Group | 방화벽 |
| `codebuild/` | CodeBuild | CI 파이프라인 |
| `codedeploy/` | CodeDeploy | CD 자동화 |

### SaaS 서비스

| 디렉토리 | 서비스 | 리소스 |
|----------|--------|--------|
| `github/` | GitHub | Repository Secrets (Actions) |
| `datadog/` | Datadog | AWS Integration, Monitor, Dashboard |
| `sumologic/` | Sumo Logic | Collector, Partition, Sources |

---

## Atlantis 워크플로우

### 워크플로우 종류

| 이름 | 대상 | IAM Role |
|------|------|----------|
| `id` | AWS 인프라 (terraform/) | `atlantis-zerone-id-admin` |
| `github` | GitHub 리소스 | `atlantis-zerone-id-admin` |
| `datadog` | Datadog 리소스 | `atlantis-zerone-id-admin` |
| `sumologic` | Sumo Logic 리소스 | `atlantis-zerone-id-admin` |

### 자동 Plan 트리거

PR에서 아래 파일이 변경되면 자동으로 `terraform plan`이 실행됩니다:

- `*.tf` - Terraform 설정
- `*.tfvars` - 변수 값
- `secrets.sops.yaml` - 암호화된 시크릿

### 사용법

```bash
# PR 코멘트로 특정 프로젝트 Plan
atlantis plan -p vpc/tmcd_apnortheast2

# PR 코멘트로 Apply
atlantis apply -p vpc/tmcd_apnortheast2

# 모든 프로젝트 Plan
atlantis plan
```

---

## 시작하기

### 사전 요구사항

- Terraform >= 1.3.7
- AWS CLI 설정
- SOPS (시크릿 관리 시)
- jq

### 로컬 개발

```bash
# 1. AWS Assume Role 설정
eval $(source scripts/terraform_setup.sh --setup)

# 2. 작업 디렉토리 이동
cd terraform/vpc/tmcd_apnortheast2

# 3. Terraform 초기화
terraform init \
  -backend-config="role_arn=arn:aws:iam::066346343248:role/atlantis-zerone-id-admin"

# 4. Plan 확인
terraform plan \
  -var "assume_role_arn=arn:aws:iam::066346343248:role/atlantis-zerone-id-admin"

# 5. 환경 변수 정리
eval $(source scripts/terraform_setup.sh --clean)
```

### PR 기반 배포 (권장)

```bash
# 1. 브랜치 생성
git checkout -b feature/update-vpc

# 2. 코드 수정 및 커밋
git add .
git commit -m "Update VPC configuration"

# 3. PR 생성 → Atlantis 자동 Plan
git push origin feature/update-vpc

# 4. PR에서 Plan 결과 확인 후 'atlantis apply' 코멘트
```

---

## Terraform 예제

`example/` 디렉토리에 학습용 예제가 포함되어 있습니다.

### 조건문 (`count`)

```hcl
# example/condition/simple/docker.tf
resource "docker_container" "nginx" {
  count = var.deploy_container ? 1 : 0  # true면 1개, false면 0개 생성
  image = docker_image.nginx.image_id
  name  = "nginx_container"
}
```

### 반복문 (`for_each`)

```hcl
# example/iteration/for_each/docker.tf
resource "docker_container" "nginx" {
  for_each = { for port in var.ports : port.container_name => port }
  image    = docker_image.nginx.image_id
  name     = each.key
  ports {
    internal = 80
    external = each.value.port
  }
}
```

---

## 코딩 컨벤션

> 참고: [Terraform Style Guide](https://github.com/jonbrouse/terraform-style-guide)

### 기본 규칙

| 항목 | 규칙 |
|------|------|
| 들여쓰기 | 2칸 스페이스 |
| 문자열 | 큰따옴표 (`"`) |
| 주석 | `# ` (해시 + 공백) |
| 정렬 | `terraform fmt` 사용 |

### 파일 구성

```
├── provider.tf      # Provider 설정
├── variables.tf     # 변수 정의
├── locals.tf        # Local 값
├── data.tf          # Data sources
├── main.tf          # 주요 리소스 (또는 리소스별 파일)
├── outputs.tf       # Output 값
└── terraform.tfvars # 변수 값
```

### 변수 정의 순서

```hcl
# 1. 기본값 없는 변수
variable "environment" {}

# 2. 기본값 있는 변수  
variable "instance_type" {
  default = "t3.micro"
}

# 3. Locals
locals {
  name_prefix = "${var.project}-${var.environment}"
}
```

### 네이밍 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| Terraform 리소스명 | 언더스코어 (`_`) | `aws_instance.web_server` |
| AWS 리소스 이름 | 하이픈 (`-`) | `name = "my-web-server"` |

---

## 문제 해결

### Atlantis Plan이 실행되지 않음

1. 변경된 파일이 `atlantis.yaml`의 `when_modified` 패턴과 일치하는지 확인
2. Atlantis 서버 로그 확인
3. 수동 실행: `atlantis plan -p <project-name>`

### AWS 인증 오류

```bash
# Assume Role 설정
eval $(source scripts/terraform_setup.sh --setup)

# 확인
aws sts get-caller-identity
```

### SOPS 복호화 오류

```bash
# KMS 키 접근 권한 확인
aws kms describe-key --key-id <key-id>

# 복호화 테스트
sops -d secrets.sops.yaml
```

---

## 라이선스

내부 교육 및 인프라 관리 목적으로 사용됩니다.
