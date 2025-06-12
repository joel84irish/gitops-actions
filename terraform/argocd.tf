########################################
# EKS Cluster Auth (NO eks_cluster data)
########################################

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

########################################
# Kubernetes & Helm Providers with Alias
########################################

provider "kubernetes" {
  alias                  = "argocd"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  alias = "argocd"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

########################################
# Namespace for ArgoCD
########################################

resource "kubernetes_namespace" "argocd" {
  provider = kubernetes.argocd

  metadata {
    name = "argocd"
  }
}

########################################
# ArgoCD Helm Installation
########################################

resource "helm_release" "argocd" {
  provider = helm.argocd

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  create_namespace = false

  values = [
    <<-EOF
server:
  service:
    type: LoadBalancer
EOF
  ]
}

########################################
# Outputs
########################################

output "argocd_server_info" {
  value = "Run: kubectl get svc -n argocd argocd-server"
}

output "argocd_login_details" {
  value = <<EOT
To log in to ArgoCD:
1. Get initial password:
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

2. Open the ArgoCD UI in your browser at:
https://<external-ip-from-service>

Username: admin
EOT
}
