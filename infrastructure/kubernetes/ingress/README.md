# Ingress Configuration for CloudSound

This directory contains Ingress configurations for exposing CloudSound services externally.

## Prerequisites

1. **Ingress Controller** (nginx-ingress) installed
2. **cert-manager** installed (for automatic SSL certificates)
3. **Domain names** configured in DNS

## Quick Setup

### 1. Install nginx-ingress

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### 2. Get External IP

```bash
kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller

# Wait for EXTERNAL-IP to be assigned
INGRESS_IP=$(kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

### 3. Configure DNS

Add A records in your DNS provider:

```
api.cloudsound.example.com         -> <INGRESS_IP>
app.cloudsound.example.com         -> <INGRESS_IP>
monitoring.cloudsound.example.com  -> <INGRESS_IP>
```

### 4. Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### 5. Update ClusterIssuer with Your Email

Edit `cluster-issuer.yaml` and replace `your-email@example.com` with your actual email:

```yaml
spec:
  acme:
    email: your-email@example.com  # Your email here
```

### 6. Apply Configurations

```bash
# Create ClusterIssuer for Let's Encrypt
kubectl apply -f cluster-issuer.yaml

# Verify ClusterIssuers
kubectl get clusterissuer

# Update ingress.yaml with your domain names
# Replace all occurrences of cloudsound.example.com with your actual domains

# Apply Ingress configuration
kubectl apply -f ingress.yaml

# Check Ingress
kubectl get ingress -n cloudsound
kubectl describe ingress -n cloudsound
```

## Configuration Files

### cluster-issuer.yaml

Creates two ClusterIssuers for Let's Encrypt:
- `letsencrypt-staging`: For testing (to avoid rate limits)
- `letsencrypt-prod`: For production SSL certificates

### ingress.yaml

Configures Ingress resources for:
- **API Gateway**: `api.cloudsound.example.com`
- **Frontend**: `app.cloudsound.example.com`
- **Monitoring (Grafana)**: `monitoring.cloudsound.example.com`

## SSL Certificate Management

### Using Staging (Testing)

For testing, use the staging issuer to avoid Let's Encrypt rate limits:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-staging
```

### Using Production

Once DNS is configured and tested, switch to production:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```

### Check Certificate Status

```bash
# List certificates
kubectl get certificate -n cloudsound

# Describe certificate
kubectl describe certificate cloudsound-tls -n cloudsound

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### Troubleshooting Certificates

If certificate issuance fails:

```bash
# Check certificate request
kubectl get certificaterequest -n cloudsound
kubectl describe certificaterequest -n cloudsound <request-name>

# Check orders
kubectl get order -n cloudsound
kubectl describe order -n cloudsound <order-name>

# Check challenges
kubectl get challenge -n cloudsound
kubectl describe challenge -n cloudsound <challenge-name>

# Delete and recreate certificate
kubectl delete certificate cloudsound-tls -n cloudsound
# Certificate will be recreated automatically by cert-manager
```

## Features

### CORS Configuration

CORS is enabled by default for all origins. To restrict:

```yaml
nginx.ingress.kubernetes.io/cors-allow-origin: "https://app.cloudsound.example.com"
```

### Rate Limiting

To enable rate limiting (requests per second):

```yaml
nginx.ingress.kubernetes.io/limit-rps: "100"
```

### Basic Authentication

To add basic auth to Grafana:

```bash
# Create auth file
htpasswd -c auth admin

# Create secret
kubectl create secret generic grafana-auth \
  --from-file=auth \
  -n cloudsound

# Uncomment annotations in ingress.yaml:
# nginx.ingress.kubernetes.io/auth-type: basic
# nginx.ingress.kubernetes.io/auth-secret: grafana-auth
```

### File Upload Size

Configured to allow up to 100MB file uploads:

```yaml
nginx.ingress.kubernetes.io/proxy-body-size: "100m"
```

### Timeouts

Configured with 600s timeouts for long-running requests:

```yaml
nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
```

## Testing

### Test HTTP to HTTPS Redirect

```bash
curl -I http://api.cloudsound.example.com
# Should return 301 or 308 redirect to https://
```

### Test SSL Certificate

```bash
curl -I https://api.cloudsound.example.com
# Should return 200 OK

# Check certificate details
openssl s_client -connect api.cloudsound.example.com:443 -servername api.cloudsound.example.com
```

### Test API Endpoint

```bash
curl https://api.cloudsound.example.com/health
curl https://api.cloudsound.example.com/api/v1/health
```

### Test Frontend

```bash
curl https://app.cloudsound.example.com
# Should return HTML
```

## Multiple Domains

To add more domains:

```yaml
spec:
  tls:
  - hosts:
    - api.cloudsound.example.com
    - api2.cloudsound.example.com  # Additional domain
    secretName: cloudsound-tls
  
  rules:
  - host: api2.cloudsound.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 8000
```

## Custom Domain Per Service

To use different domains for different services:

```yaml
# api-gateway-ingress.yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway-ingress
  namespace: cloudsound
spec:
  tls:
  - hosts:
    - api.example.com
    secretName: api-tls
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 8000
```

## Security Best Practices

1. **Always use HTTPS** in production (enforced by default)
2. **Use strong passwords** for basic auth
3. **Enable rate limiting** to prevent abuse
4. **Restrict CORS** to specific domains in production
5. **Monitor access logs** regularly
6. **Keep nginx-ingress updated**

## Monitoring

### View Ingress Controller Logs

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

### Check Metrics

```bash
# nginx-ingress exposes Prometheus metrics
kubectl port-forward -n ingress-nginx svc/nginx-ingress-ingress-nginx-controller-metrics 9913:9913
curl http://localhost:9913/metrics
```

## Cleanup

```bash
# Delete Ingress resources
kubectl delete -f ingress.yaml

# Delete ClusterIssuers
kubectl delete -f cluster-issuer.yaml

# Uninstall nginx-ingress
helm uninstall nginx-ingress -n ingress-nginx

# Uninstall cert-manager
helm uninstall cert-manager -n cert-manager
```

## References

- [nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

