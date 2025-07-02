locals {
  cluster_name = "terraform-k8s-demo"
}

# create application namespace
resource "kubernetes_namespace" "onlineboutique" {
  metadata {
    name = "onlineboutique"
    labels = {
      "app.kubernetes.io/name" = "onlineboutique"
      "app.kubernetes.io/part-of" = "onlineboutique"
    }
  }
}

# create argo-cd custom resource to enable argocd sync with the git repo,
# this manifest is used to sync the application from helm-chart to our cluster.
# https://github.com/GoogleCloudPlatform/microservices-demo.git
resource "kubernetes_manifest" "app_chart" {
  manifest = yamldecode(<<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: onlineboutique
  namespace: argo-cd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    # The default behaviour is foreground cascading deletion
    - resources-finalizer.argocd.argoproj.io
    # Alternatively, you can use background cascading deletion
    # - resources-finalizer.argocd.argoproj.io/background
spec:
  project: default
  source:
    chart: onlineboutique
    repoURL: us-docker.pkg.dev/online-boutique-ci/charts
    targetRevision: 0.10.1
    helm:
      releaseName: onlineboutique
      values: |
        frontend:
            externalService: false
  destination:
    server: "https://kubernetes.default.svc"
    namespace: onlineboutique
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
    YAML
  )

  depends_on = [
    kubernetes_namespace.onlineboutique,
  ]
}

# create frontend service as an ingress to be the entrypoint of the application.
resource "kubernetes_ingress_v1" "frontend" {
  metadata {
    name      = "frontend"
    namespace = "onlineboutique"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = [
        "app.k8s.demo",
      ]
      secret_name = "app-k8s-demo-tls"
    }
    rule {
      host = "app.k8s.demo"
      http {
        path {
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_manifest.app_chart,
    kubernetes_namespace.onlineboutique,
  ]
}

# create custom resource (external secret) to point to the secret manager
resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = yamldecode(<<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: onlineboutique-secret
  namespace: onlineboutique
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: aws-store
    kind: ClusterSecretStore
  target:
    name: onlineboutique-secret
  data:
    - secretKey: THE_ANSWER
      remoteRef:
        key: ${local.cluster_name}-appsecret

    YAML
  )

  depends_on = [
    kubernetes_namespace.onlineboutique,
  ]
}
