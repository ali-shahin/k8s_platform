locals {
  cluster_name = "terraform-k8s-demo"
}

#  configue dns to point to the ingress had recently created
data "kubernetes_service" "ingress_service" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}

data "aws_route53_zone" "default" {
  name         = "k8s.demo"
  private_zone = true
}

resource "aws_route53_record" "ingress_record" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = "app.k8s.demo"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.ingress_service.status.0.load_balancer.0.ingress.0.hostname]
}

# configure cert-manager to create tls certificate
resource "kubernetes_manifest" "cert_issuer" {
  manifest = yamldecode(<<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ali@intx.io
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
    YAML
  )
  depends_on = [
    aws_route53_record.ingress_record
  ]
}

# configure the secret manager to enable eso to fitch secrets from aws parameter store.
data "aws_caller_identity" "current" {}

resource "kubernetes_service_account" "secret_store" {
  metadata {
    name      = "secret-store"
    namespace = "external-secrets"
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/secret-store"
    }
  }
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = yamldecode(<<YAML
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-store
spec:
  provider:
    aws:
      service: ParameterStore
      region: eu-central-1
      auth:
        jwt:
          serviceAccountRef:
            name: secret-store
            namespace: external-secrets
    YAML
  )
  depends_on = [
    kubernetes_service_account.secret_store
  ]
}
