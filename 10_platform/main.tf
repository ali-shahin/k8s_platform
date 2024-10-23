locals {
  cluster_name = "terraform-k8s-demo"
}

resource "helm_release" "eso" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  repository       = "https://external-secrets.io"
  chart            = "external-secrets"
  version          = "0.10.4"
  create_namespace = true
  atomic           = true # revert all created reources if any resource failed.
  timeout          = 300  # default is 300
}

resource "helm_release" "certm" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.16.1"
  create_namespace = true
  atomic           = true
  timeout          = 300

  values = [ # set custom resource definition to ture
    <<YAML
installCRDs: true
    YAML
  ]
}

resource "helm_release" "ingress" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  create_namespace = true
  atomic           = true
  timeout          = 300

  values = [
    <<YAML
controller:
    podSecurityContext:
        runAsNotRoot: true
    service:
        enableHttp: true
        enableHttps: true
        annotations:
            service.beta.kubernetes.io/aws-load-balancer-type: nlb
    YAML
  ]
}

resource "helm_release" "argocd" {
  name             = "argo-cd"
  namespace        = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm/"
  chart            = "argo-cd"
  version          = "7.6.12"
  create_namespace = true
  atomic           = true
  timeout          = 300

  values = [
    <<YAML
nameOverride: argo-cd
redis-ha: 
    enabled: false
controller:
    replicas: 1
server:
    replicas: 1
repoServer:
    replicas: 1
applicationSet:
    replicaCount: 1
    YAML
  ]
}
