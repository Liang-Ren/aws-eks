# AWS EKS with Terraform

This project codifies an `EKS` where we creates:
- A dedicated `VPC` with public and private `subnets`
- An `EKS` cluster with a single managed `nodegroup`
- An `ECR repository` for your Flask/FastAPI demo image
- An S3 bucket that you can use in `IRSA` (IAM Roles for Service Accounts) 
- A troubleshooting scenarios via `kubectl logs/events/describe` 
- A case of `securitycontext` and `NetworkPolicy` 

---

## Prerequisites

- Terraform >= 1.5
- An AWS account and credentials configured (e.g., via `aws configure`)
- AWS IAM permissions to create VPC, EKS, ECR, S3, and related IAM roles
- kubectl installed on your machine

By default, the lab deploys to `us-east-1` and uses:
- Cluster name: `lab-eks`
- Node instance type: `t3.small`
- Node count: 1–2 nodes

You can override these via Terraform variables.

---

## How to use

1. **Change into the project directory**

   ```bash
   cd aws-eks-lab-terraform
   ```

2. **Initialize Terraform** (downloads AWS and module providers)

   ```bash
   terraform init
   ```

3. **Review the plan**

   ```bash
   terraform plan
   ```

4. **Apply the configuration**

   ```bash
   terraform apply
   ```

   Type `yes` when prompted. Provisioning the EKS cluster can take several minutes.

5. **Export useful outputs**

   After apply succeeds:

   ```bash
   terraform output
   ```

   You should see values such as:
   - `cluster_name`
   - `cluster_endpoint`
   - `ecr_repository_url`
   - `irsa_demo_bucket_name`

6. **Configure kubectl for the new cluster**

   ```bash
   aws eks update-kubeconfig \
     --name lab-eks \
     --region us-east-1

   kubectl get nodes -o wide
   kubectl get pods -A
   ```

   You should see 1–2 worker nodes in `Ready` state.

---

## Using this lab

### Deploy a sample Flask/FastAPI app to EKS

1. **Build and push your image to ECR**

   Get the repository URL:

   ```bash
   terraform output -raw ecr_repository_url
   ```

   Build, tag, and push (example):

   ```bash
   export ECR_URL=$(terraform output -raw ecr_repository_url)

   docker build -t flask-eks:v1 .
   docker tag flask-eks:v1 "$ECR_URL:v1"
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin "${ECR_URL%/*}"
   docker push "$ECR_URL:v1"
   ```

2. **Apply the Kubernetes manifests**

   You can reuse your existing manifests or start from the sample provided in this repo:

   - `k8s/app/flask-eks.yaml` – Deployment + LoadBalancer Service in namespace `liang-eks`.

   Update the `image: REPLACE_ECR_IMAGE` value to the ECR URL (for example, `"$ECR_URL:v1"`), then:

   ```bash
   kubectl create namespace liang-eks --dry-run=client -o yaml | kubectl apply -f -
   kubectl apply -f k8s/app/flask-eks.yaml
   kubectl get deploy,svc -n liang-eks
   ```

### IRSA and S3 access

Terraform creates an S3 bucket for you:

```bash
terraform output -raw irsa_demo_bucket_name
```

You can then follow your IRSA steps (using `eksctl utils associate-iam-oidc-provider`, `eksctl create iamserviceaccount`, etc.) and reuse this bucket in the IAM policy.

This repo also includes a simple pod manifest that uses a ServiceAccount named `s3-reader` in namespace `liang-eks`:

- `k8s/irsa/s3-reader-pod.yaml`

After you create the IAM role and the IRSA-bound ServiceAccount via `eksctl`, deploy the pod and test S3 access from inside it.

If you prefer, you can later extend this Terraform project to also manage IRSA roles and Kubernetes service accounts.

### Troubleshooting scenarios

With this lab cluster running, you can apply the sample manifests in this repo to practice pod and workload troubleshooting:

- Troubleshooting (namespace `liang-eks`):
  - `k8s/troubleshooting/buggy-env-deploy.yaml` – env var missing → `CrashLoopBackOff`.
  - `k8s/troubleshooting/buggy-image-deploy.yaml` – bad image tag → `ImagePullBackOff`.

Use these workloads with:
- `kubectl logs`
- `kubectl describe`
- `kubectl get events -A`

to build intuition for common failure modes in Kubernetes and EKS.

### Security context and NetworkPolicy

You can also use this cluster to validate basic pod security settings and network policies:

- SecurityContext (namespace `dev`):
  - `k8s/security-networkpolicy/sec-backend.yaml` – `runAsNonRoot`, `readOnlyRootFilesystem`, drop capabilities.
- NetworkPolicy (namespace `dev`):
  - `k8s/security-networkpolicy/np-backend.yaml` – backend Deployment + Service.
  - `k8s/security-networkpolicy/np-frontend-pod.yaml` – frontend curl pod.
  - `k8s/security-networkpolicy/np-deny-all.yaml` – default deny ingress to backend.
  - `k8s/security-networkpolicy/np-allow-frontend.yaml` – allow only pods with `role=frontend`.

Apply them into namespaces such as `dev` or `liang-eks` and then:
- Verify pods run as non-root and with restricted capabilities.
- Confirm that backend traffic is denied by default and only allowed from pods with the correct labels.

---

## Cleanup

To avoid unnecessary AWS charges, always destroy the lab when you are done:

```bash
terraform destroy
```

This will remove the EKS cluster, node group, VPC, ECR repository, and S3 bucket created by this project.

---

## Customization

You can override defaults using a `terraform.tfvars` file or `-var` flags, for example:

```hcl
region          = "us-east-1"
cluster_name    = "lab-eks"
project_name    = "eks-lab"
node_instance_type = "t3.small"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 2
```

This project is intentionally small and focused on lab scenarios, not production hardening. For production, you would add more controls (encryption, logging, stricter security groups, IRSA roles managed via Terraform, etc.).
