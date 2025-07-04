# Terraform AWS Kubernetes Platform (k8s platform)

A modular Terraform project to provision a complete Kubernetes platform on AWS, including networking, security, platform services, and a demo application.

This project uses layers to separate foundational AWS resources, platform-level Kubernetes services, integrations, and application deployments, ensuring a scalable and maintainable infrastructure.

## Why Use Layers in Infrastructure as Code?

Layering your infrastructure as code (IaC) brings modularity, clarity, and maintainability to complex cloud environments. By splitting resources into logical layers (such as networking, platform services, and applications), you can:

- **Promote Reusability**: Common building blocks (like VPCs or IAM roles) can be reused across projects or environments.
- **Enable Clear Dependencies**: Each layer builds on the outputs of the previous, making dependencies explicit and reducing errors.
- **Simplify Management**: Changes can be made to a specific layer without affecting the entire stack, making updates and rollbacks safer and faster.
- **Support Team Collaboration**: Different teams can own and manage different layers, improving workflow and reducing conflicts.
- **Facilitate Testing and Promotion**: Layers can be tested and promoted independently, supporting robust CI/CD pipelines.

---

## 00 Foundations

- **VPC & Subnets**: AWS VPC with public, private, and intra subnets across multiple AZs.
- **NAT Gateway**: For outbound internet access from private subnets.
- **DNS**: Route53 private zone for internal cluster DNS.
- **EKS Cluster**: Managed Kubernetes cluster with Bottlerocket nodes and autoscaling.
- **Cluster Autoscaling**: Managed node group scaling via EKS.
- **IAM**: Roles for EKS, cert-manager, and external secrets.

## 10 Platform

- **Ingress**: NGINX Ingress Controller (Helm).
- **Secret Management**: External Secrets Operator (Helm) with AWS SSM Parameter Store integration.
- **Certificate Management**: cert-manager (Helm) with Route53 DNS challenge.
- **Continuous Delivery**: Argo CD (Helm) for GitOps deployment.

## 15 Platform (Integrations)

- **DNS Integration**: Route53 record for app ingress.
- **TLS Certificates**: cert-manager ClusterIssuer for Let's Encrypt.
- **Secret Store Integration**: ServiceAccount and ClusterSecretStore for AWS SSM.

## 100 App

- **Namespace**: Dedicated namespace for the demo app.
- **GitOps App Deployment**: Argo CD Application resource for Online Boutique (Helm chart).
- **Ingress**: TLS-enabled Ingress for the frontend.
- **External Secrets**: App secrets synced from AWS SSM.

---

## Usage

1. **Initialize**: `terraform init` in each module directory.
2. **Plan & Apply**: `terraform plan` and `terraform apply` in order: `00_foundations` → `10_platform` → `15_platform` → `100_app`.
3. **Access**: The demo app will be available at `https://app.k8s.demo` (internal DNS).

---

## Requirements

- Terraform >= 1.0
- AWS credentials
- kubectl & awscli
- Helm

---
