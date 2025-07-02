locals {
  cluster_name = "terraform-k8s-demo"
  tags = {
    "author"                 = "alix"
    "karpenter.sh/discovery" = local.cluster_name
    "Environment"            = "demo"
    "Terraform"              = "true"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"

  name = local.cluster_name
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  intra_subnets   = ["10.0.51.0/24", "10.0.52.0/24", "10.0.53.0/24"] # used for the controlplane.

  enable_nat_gateway = true

  tags = local.tags

}

module "cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    default = {
      iam_role_name            = "node-${local.cluster_name}"
      iam_role_use_name_prefix = false
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups.
      # BOTTLEROCKET is one of the most common container optimized OS.
      # Read on https://aws.amazon.com/bottlerocket/
      ami_type       = "BOTTLEROCKET_x86_64"
      platform       = "bottlerocket"
      instance_types = ["t3.xlarge"]

      min_size     = 2
      max_size     = 5
      desired_size = 2
    }
  }

  tags = local.tags
}

# iam role for the cert manager
module "cert_manager_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                     = "cert-manager"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z09675111PMPGFA7YFH7T"]

  oidc_providers = {
    main = {
      provider_arn               = module.cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cert-manager"]
    }
  }

  tags = local.tags
}

# iam role to fetch secrets stored on aws
module "external_secrets_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                           = "secret-store"
  attach_external_secrets_policy      = true
  external_secrets_ssm_parameter_arns = ["arn:aws:ssm:*:*:parameter/${local.cluster_name}-*"]

  oidc_providers = {
    main = {
      provider_arn               = module.cluster.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:secret-store"]
    }
  }

  tags = local.tags
}
