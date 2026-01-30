output "region" {
  description = "AWS region in which the lab is deployed"
  value       = var.region
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "ID of the VPC created for this lab"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by worker nodes"
  value       = module.vpc.private_subnets
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing your app image"
  value       = aws_ecr_repository.app.repository_url
}

output "irsa_demo_bucket_name" {
  description = "S3 bucket name used for IRSA demo labs"
  value       = aws_s3_bucket.irsa_demo.bucket
}
