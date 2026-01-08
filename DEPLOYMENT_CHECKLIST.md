# CloudSound Azure Deployment Checklist

Quick reference checklist for deploying CloudSound to Azure.

## 📋 Pre-Deployment Checklist

### Tools Installation
- [ ] Azure CLI installed (`az --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Helm 3.10+ installed (`helm version`)
- [ ] Terraform 1.0+ installed (`terraform --version`)
- [ ] Docker installed and running (`docker --version`)
- [ ] Git configured

### Azure Account
- [ ] Azure account created
- [ ] Student credits activated ($100)
- [ ] Logged into Azure (`az login`)
- [ ] Correct subscription selected (`az account show`)

### Repository
- [ ] Code cloned from GitHub
- [ ] All dependencies installed
- [ ] Environment ready

---

## 🏗️ Infrastructure Setup (15-20 min)

### Terraform Configuration
- [ ] Navigated to `infrastructure/terraform/`
- [ ] Copied `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Updated `terraform.tfvars` with your email
- [ ] Reviewed resource sizes and adjusted if needed

### Deploy Infrastructure
- [ ] Run `terraform init`
- [ ] Run `terraform validate`
- [ ] Run `terraform plan` (review changes)
- [ ] Run `terraform apply` (type 'yes')
- [ ] Waited for completion (~10-15 minutes)
- [ ] Verified all resources created successfully

### Save Outputs
- [ ] Run `terraform output` and saved important values
- [ ] Noted ACR login server
- [ ] Noted PostgreSQL server FQDN
- [ ] Noted storage account name

**Resources Created:**
- ✅ Resource Group: `cloudsound-rg`
- ✅ AKS Cluster: `cloudsound-aks`
- ✅ Container Registry: `cloudsoundacrXXXXXX`
- ✅ PostgreSQL Server
- ✅ Storage Account
- ✅ Virtual Network
- ✅ Log Analytics Workspace
- ✅ Application Insights

---

## ⚙️ Kubernetes Setup (10-15 min)

### Configure kubectl
- [ ] Run `az aks get-credentials --resource-group cloudsound-rg --name cloudsound-aks`
- [ ] Run `kubectl cluster-info` (verify connection)
- [ ] Run `kubectl get nodes` (should show 2 nodes)

### Install Ingress Controller
- [ ] Add helm repo: `helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx`
- [ ] Install nginx-ingress
- [ ] Wait for external IP assignment
- [ ] Noted external IP address

### Install cert-manager
- [ ] Add helm repo: `helm repo add jetstack https://charts.jetstack.io`
- [ ] Install cert-manager with CRDs
- [ ] Verify cert-manager pods running

### Create Secrets
- [ ] Run `./scripts/azure-secrets.sh`
- [ ] Verified secrets created: `kubectl get secrets -n cloudsound`

**Secrets Created:**
- ✅ acr-secret (ACR authentication)
- ✅ postgres-secret (database connection)
- ✅ cloudsound-secrets (app secrets)
- ✅ storage-secret (Azure Storage)
- ✅ app-insights-secret (monitoring)

---

## 🐳 Docker Images (10-15 min)

### Build and Push
- [ ] Logged into ACR: `az acr login --name <acr-name>`
- [ ] Set REGISTRY environment variable
- [ ] Run `./scripts/build-and-push-azure.sh`
- [ ] Waited for all images to build and push
- [ ] Verified images in ACR: `az acr repository list --name <acr-name>`

**Images Pushed:**
- ✅ api-gateway
- ✅ authentication
- ✅ radio-streaming
- ✅ concert-management
- ✅ analytics
- ✅ music-discovery
- ✅ event-manager
- ✅ frontend

---

## 🌐 DNS Configuration (5 min)

### Domain Setup
- [ ] Got ingress external IP
- [ ] Added DNS A records:
  - [ ] `api.yourdomain.com` → Ingress IP
  - [ ] `app.yourdomain.com` → Ingress IP
  - [ ] `monitoring.yourdomain.com` → Ingress IP (optional)
- [ ] Waited for DNS propagation (5-10 minutes)
- [ ] Tested DNS: `nslookup api.yourdomain.com`

---

## 🚀 Application Deployment (10 min)

### Deploy with Helm
- [ ] Navigated to `infrastructure/helm/cloudsound/`
- [ ] Updated domain names in `values-azure.yaml`
- [ ] Run `helm dependency update`
- [ ] Run `helm install cloudsound . --values values-azure.yaml --namespace cloudsound --create-namespace`
- [ ] Waited for deployment (~5 minutes)

### Verify Deployment
- [ ] All pods running: `kubectl get pods -n cloudsound`
- [ ] All services created: `kubectl get svc -n cloudsound`
- [ ] Ingress configured: `kubectl get ingress -n cloudsound`
- [ ] No errors in pod logs

### Run Migrations
- [ ] Applied migration job
- [ ] Checked job completion: `kubectl get jobs -n cloudsound`
- [ ] Verified no errors in migration logs

---

## ✅ Verification (5 min)

### Health Checks
- [ ] API health: `curl https://api.yourdomain.com/health`
- [ ] Frontend accessible: `https://app.yourdomain.com`
- [ ] All services responding

### SSL Certificates
- [ ] Certificates issued: `kubectl get certificate -n cloudsound`
- [ ] TLS working: `curl -I https://api.yourdomain.com` (returns 200)
- [ ] No certificate warnings in browser

### Application Testing
- [ ] Can access Swagger docs: `https://api.yourdomain.com/docs`
- [ ] Can make API requests
- [ ] Frontend loads correctly
- [ ] No JavaScript errors in console

---

## 📊 Monitoring Setup (10 min)

### Grafana Access
- [ ] Port-forward Grafana: `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`
- [ ] Logged into Grafana (admin / password from secret)
- [ ] Verified data sources connected
- [ ] Imported dashboards

### Azure Monitor
- [ ] Container Insights enabled
- [ ] Log Analytics workspace accessible
- [ ] Application Insights receiving data
- [ ] No errors in Azure Portal

### Set Up Alerts
- [ ] Created alert for high CPU usage
- [ ] Created alert for pod restarts
- [ ] Created alert for error rates
- [ ] Tested alert notifications

---

## 🔄 CI/CD Setup (15 min)

### GitHub Secrets
- [ ] Added AZURE_CREDENTIALS
- [ ] Added ACR_LOGIN_SERVER
- [ ] Added ACR_USERNAME
- [ ] Added ACR_PASSWORD
- [ ] Added AKS_RESOURCE_GROUP
- [ ] Added AKS_CLUSTER_NAME
- [ ] Added POSTGRES_HOST
- [ ] Added POSTGRES_ADMIN_PASSWORD
- [ ] Added DOMAIN_NAME

See [.github/SECRETS_SETUP.md](.github/SECRETS_SETUP.md) for details.

### Test Pipeline
- [ ] Pushed code to main branch
- [ ] Workflow triggered automatically
- [ ] Build jobs succeeded
- [ ] Deploy job succeeded
- [ ] Application updated successfully

---

## 🎯 Optional Components

### Azure Functions
- [ ] Created Function App
- [ ] Configured app settings
- [ ] Deployed metadata extractor function
- [ ] Tested function invocation

### Advanced Monitoring
- [ ] Loki installed for log aggregation
- [ ] Prometheus configured with custom metrics
- [ ] Grafana dashboards customized
- [ ] Alerts fine-tuned

### Security Hardening
- [ ] Network policies enabled
- [ ] Pod security policies configured
- [ ] RBAC configured
- [ ] Secrets in Azure Key Vault (optional)

---

## 📝 Post-Deployment

### Documentation
- [ ] Updated README with actual domain names
- [ ] Documented any custom configurations
- [ ] Created runbook for common tasks
- [ ] Shared credentials securely with team

### Team Access
- [ ] Added team members to Azure Portal
- [ ] Configured RBAC roles
- [ ] Shared Grafana credentials
- [ ] Set up team communication channels

### Backup & DR
- [ ] Configured database backups
- [ ] Documented disaster recovery process
- [ ] Tested backup restoration (optional)
- [ ] Set up off-site backup storage (optional)

---

## 🎉 Success Criteria

Your deployment is successful when:

- ✅ All pods are in "Running" state
- ✅ All services are accessible via HTTPS
- ✅ SSL certificates are valid
- ✅ API endpoints respond correctly
- ✅ Frontend loads without errors
- ✅ Monitoring dashboards show data
- ✅ CI/CD pipeline runs successfully
- ✅ No critical errors in logs
- ✅ Database connection is working
- ✅ Storage is accessible

---

## 📞 Need Help?

If something goes wrong, check:

1. **Pod Status**: `kubectl get pods -n cloudsound`
2. **Pod Logs**: `kubectl logs <pod-name> -n cloudsound`
3. **Events**: `kubectl get events -n cloudsound --sort-by='.lastTimestamp'`
4. **Ingress**: `kubectl describe ingress -n cloudsound`
5. **Certificates**: `kubectl describe certificate -n cloudsound`

**Documentation:**
- [Azure Deployment Guide](docs/AZURE_DEPLOYMENT.md)
- [Troubleshooting Section](docs/AZURE_DEPLOYMENT.md#troubleshooting)
- [Azure Portal](https://portal.azure.com)

---

## 💰 Cost Tracking

After deployment, monitor costs:

- [ ] Set up cost alerts in Azure Portal
- [ ] Review cost breakdown weekly
- [ ] Optimize resource usage
- [ ] Stop AKS when not needed (dev/test)

**Monthly Budget**: ~$60-80 (within student credits)

---

## 🔄 Maintenance Tasks

### Weekly
- [ ] Check pod status
- [ ] Review error logs
- [ ] Check resource usage
- [ ] Review costs

### Monthly
- [ ] Update dependencies
- [ ] Review and rotate secrets
- [ ] Clean up old images
- [ ] Review monitoring alerts

### As Needed
- [ ] Scale resources based on load
- [ ] Update application code
- [ ] Apply security patches
- [ ] Optimize costs

---

**Last Updated**: January 2026
**Version**: 1.0

✅ **Deployment Complete!** Your CloudSound platform is now running on Azure! 🚀

