# Auto-detect the operator's current public IP for the EKS endpoint
# allowlist, used only when eks_cluster_endpoint_public_access_cidrs is left
# at its default empty list. This makes terraform plan/apply depend on
# checkip.amazonaws.com being reachable; set the variable explicitly to
# avoid that dependency (e.g. in CI, or behind a firewall).
data "http" "operator_public_ip" {
  count = length(var.eks_cluster_endpoint_public_access_cidrs) == 0 ? 1 : 0

  url                = "https://checkip.amazonaws.com"
  request_timeout_ms = 10000
}

locals {
  # Build a consistent resource name prefix, for example atlas-commerce-alpha.
  name_prefix = "${var.project}-${var.environment}"

  # Define tags automatically applied to Atlas development resources.
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "platform"
    },
    var.additional_tags
  )

  # Use the explicit override when set; otherwise fall back to the
  # auto-detected operator IP as a /32 CIDR.
  eks_cluster_endpoint_public_access_cidrs = length(var.eks_cluster_endpoint_public_access_cidrs) > 0 ? (
    var.eks_cluster_endpoint_public_access_cidrs
    ) : [
    "${trimspace(data.http.operator_public_ip[0].response_body)}/32"
  ]
}