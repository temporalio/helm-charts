# Bitnami PostgreSQL on Azure Kubernetes Service (AKS)

This Kustomize implementation deploys the Bitnami PostgreSQL Helm chart (version 18.1.10) to Azure Kubernetes Service (AKS) following best practices for production workloads.

## Overview

This deployment includes:
- PostgreSQL 16.x (Bitnami image)
- Production-ready configurations for AKS
- High Availability (HA) support with read replicas
- Azure-optimized storage (Premium SSD)
- Security best practices (non-root, read-only filesystem, network policies)
- Metrics and monitoring integration
- Automated backup configuration
- TLS/SSL support

## Architecture

### Standalone Mode (Base)
- Single PostgreSQL instance
- Suitable for development/staging
- 100Gi Premium SSD storage
- 2Gi memory, 1 CPU core

### Replication Mode (Production Overlay)
- 1 Primary + 2 Read Replicas
- Synchronous replication for data consistency
- 500Gi Premium SSD storage per instance
- 4Gi memory, 2 CPU cores per instance
- Pod Disruption Budgets for HA
- Zone-aware pod distribution

## Prerequisites

1. **AKS Cluster** (Kubernetes 1.23+)
   ```bash
   az aks create \
     --resource-group <rg-name> \
     --name <cluster-name> \
     --node-count 3 \
     --zones 1 2 3 \
     --enable-managed-identity \
     --network-plugin azure \
     --kubernetes-version 1.28
   ```

2. **Kustomize** (v4.0+)
   ```bash
   # Install kustomize
   curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
   ```

3. **Helm** (v3.8.0+)
   ```bash
   # Install Helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

4. **kubectl** configured for your AKS cluster
   ```bash
   az aks get-credentials --resource-group <rg-name> --name <cluster-name>
   ```

## Storage Classes

The deployment uses Azure managed disks:

- **managed-csi-premium**: Azure Premium SSD (LRS) for database storage
- **managed-csi**: Azure Standard SSD for backups

Verify storage classes are available:
```bash
kubectl get storageclass
```

If needed, create the premium storage class:
```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingMode: ReadOnly
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
```

## Secrets Management

### Option 1: Manual Secret Creation (Quick Start)

```bash
kubectl create namespace postgres

kubectl create secret generic postgres-credentials \
  --from-literal=postgres-password="$(openssl rand -base64 32)" \
  --from-literal=password="$(openssl rand -base64 32)" \
  --from-literal=replication-password="$(openssl rand -base64 32)" \
  --namespace=postgres
```

### Option 2: Azure Key Vault (Recommended for Production)

1. Install Azure Key Vault CSI Driver:
   ```bash
   helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
   helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --generate-name --namespace kube-system
   ```

2. Create secrets in Azure Key Vault:
   ```bash
   az keyvault secret set --vault-name <vault-name> --name postgres-password --value "<password>"
   az keyvault secret set --vault-name <vault-name> --name app-password --value "<password>"
   az keyvault secret set --vault-name <vault-name> --name replication-password --value "<password>"
   ```

3. Update ServiceAccount with Azure Workload Identity annotations.

### Option 3: Sealed Secrets

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secret
kubectl create secret generic postgres-credentials \
  --from-literal=postgres-password="<password>" \
  --from-literal=password="<password>" \
  --from-literal=replication-password="<password>" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

kubectl apply -f sealed-secret.yaml -n postgres
```

## Deployment

### Deploy Base Configuration (Standalone)

```bash
# Preview what will be deployed
kustomize build kustomize/bitnami-postgres/base --enable-helm

# Deploy to cluster
kustomize build kustomize/bitnami-postgres/base --enable-helm | kubectl apply -f -

# Check deployment status
kubectl get pods -n postgres
kubectl get pvc -n postgres
```

### Deploy Production Configuration (HA with Replicas)

```bash
# Preview production deployment
kustomize build kustomize/bitnami-postgres/overlays/production --enable-helm

# Deploy to cluster
kustomize build kustomize/bitnami-postgres/overlays/production --enable-helm | kubectl apply -f -

# Monitor rollout
kubectl rollout status statefulset/postgres-postgresql-primary -n postgres
kubectl rollout status statefulset/postgres-postgresql-read -n postgres
```

## Verification

### Check Pod Status
```bash
kubectl get pods -n postgres -o wide
```

### Check Persistent Volumes
```bash
kubectl get pvc -n postgres
kubectl get pv | grep postgres
```

### Check Services
```bash
kubectl get svc -n postgres
```

### Connect to PostgreSQL

```bash
# Get the postgres password
export POSTGRES_PASSWORD=$(kubectl get secret --namespace postgres postgres-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)

# Port forward to access locally
kubectl port-forward --namespace postgres svc/postgres-postgresql 5432:5432

# Connect using psql (from another terminal)
PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U postgres -d appdb
```

### Test Connection from Within Cluster

```bash
kubectl run postgres-client --rm --tty -i --restart='Never' \
  --namespace postgres \
  --image registry-1.docker.io/bitnami/postgresql:16 \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql -h postgres-postgresql -U postgres -d appdb
```

## Monitoring

### Prometheus Metrics

Metrics are exposed on port 9187. If using Prometheus Operator:

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n postgres

# View metrics
kubectl port-forward -n postgres svc/postgres-postgresql-metrics 9187:9187
curl http://localhost:9187/metrics
```

### Azure Monitor Integration

To integrate with Azure Monitor for containers:

```bash
# Enable Container Insights on AKS
az aks enable-addons --resource-group <rg-name> --name <cluster-name> --addons monitoring

# Metrics will be available in Azure Monitor
```

## Backup and Restore

### Automated Backups

Backups run daily at 2 AM UTC (configurable in values.yaml):

```bash
# Check backup CronJob
kubectl get cronjob -n postgres

# List backup jobs
kubectl get jobs -n postgres

# Check backup PVC
kubectl get pvc -n postgres | grep backup
```

### Manual Backup

```bash
# Create a manual backup job
kubectl create job --from=cronjob/postgres-postgresql-backup manual-backup-$(date +%s) -n postgres

# Check backup logs
kubectl logs -n postgres job/manual-backup-<timestamp>
```

### Restore from Backup

```bash
# Copy backup file from PVC
kubectl cp postgres/<backup-pod>:/backup/pgdump/<backup-file> ./local-backup.pgdump

# Restore to database
kubectl exec -it postgres-postgresql-primary-0 -n postgres -- bash
pg_restore -U postgres -d appdb /backup/pgdump/<backup-file>
```

### Velero for Disaster Recovery

For full cluster backup/restore:

```bash
# Install Velero with Azure provider
velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.9.0 \
  --bucket <backup-bucket> \
  --secret-file ./credentials-velero \
  --backup-location-config resourceGroup=<rg>,storageAccount=<sa>

# Create backup
velero backup create postgres-backup --include-namespaces postgres

# Restore
velero restore create --from-backup postgres-backup
```

## Scaling

### Vertical Scaling (Resources)

Edit the values file and update resources, then reapply:

```bash
# Update resources in values.yaml or production overlay
kustomize build kustomize/bitnami-postgres/overlays/production --enable-helm | kubectl apply -f -
```

### Horizontal Scaling (Read Replicas)

Update `readReplicas.replicaCount` in production overlay:

```yaml
readReplicas:
  replicaCount: 3  # Increase from 2 to 3
```

Apply changes:
```bash
kustomize build kustomize/bitnami-postgres/overlays/production --enable-helm | kubectl apply -f -
```

## Maintenance

### Upgrading PostgreSQL Version

1. Check available versions:
   ```bash
   helm search repo bitnami/postgresql --versions
   ```

2. Update chart version in `base/kustomization.yaml`

3. Review CHANGELOG for breaking changes

4. Test in non-production environment first

5. Apply upgrade:
   ```bash
   kustomize build kustomize/bitnami-postgres/base --enable-helm | kubectl apply -f -
   ```

### Changing Configuration

1. Update `values.yaml` or overlay values
2. Preview changes:
   ```bash
   kustomize build kustomize/bitnami-postgres/base --enable-helm | kubectl diff -f -
   ```
3. Apply:
   ```bash
   kustomize build kustomize/bitnami-postgres/base --enable-helm | kubectl apply -f -
   ```

## Security Best Practices

### ✅ Implemented

- Non-root containers (runAsUser: 1001)
- Read-only root filesystem
- Dropped all capabilities
- Security context with seccomp profile
- Network policies enabled
- Pod Disruption Budgets
- Audit logging enabled
- Password files instead of environment variables
- ServiceAccount without auto-mount token

### 🔒 Additional Recommendations

1. **Enable TLS/SSL**
   - Generate certificates using cert-manager or Azure Key Vault
   - Update `tls.enabled: true` in production

2. **Network Policies**
   - Restrict ingress to specific namespaces/pods
   - Update `networkPolicy.ingressNSMatchLabels`

3. **Azure Private Link**
   - Use Azure Private Link for ACR access
   - Eliminate public internet exposure

4. **Pod Security Standards**
   - Apply restricted Pod Security Standard to namespace
   ```bash
   kubectl label namespace postgres pod-security.kubernetes.io/enforce=restricted
   ```

5. **Regular Updates**
   - Subscribe to Bitnami security advisories
   - Keep chart and images up to date

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n postgres

# Check logs
kubectl logs <pod-name> -n postgres

# Check PVC status
kubectl get pvc -n postgres
```

### Storage Issues

```bash
# Check storage class
kubectl get sc

# Check PV status
kubectl get pv | grep postgres

# Describe PVC for events
kubectl describe pvc <pvc-name> -n postgres
```

### Connection Issues

```bash
# Check service
kubectl get svc -n postgres

# Check endpoints
kubectl get endpoints -n postgres

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres-postgresql.postgres.svc.cluster.local
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n postgres

# Check PostgreSQL logs
kubectl logs -n postgres postgres-postgresql-primary-0 --tail=100

# Connect and check queries
kubectl exec -it postgres-postgresql-primary-0 -n postgres -- psql -U postgres -d appdb -c "SELECT * FROM pg_stat_activity;"
```

## Cost Optimization

### Storage Tiers

- **Development**: Use Standard SSD (managed-csi)
- **Production**: Use Premium SSD (managed-csi-premium)
- Consider Azure Disk sizing based on IOPS requirements

### Resource Right-sizing

Monitor actual usage and adjust:
```bash
# Check resource usage over time
kubectl top pods -n postgres --containers

# Use Azure Monitor metrics for long-term analysis
```

### Backup Storage

- Use cheaper storage tier for backups
- Implement retention policies
- Consider Azure Blob Storage for long-term archival

## References

- [Bitnami PostgreSQL Chart Documentation](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Kustomize Documentation](https://kustomize.io/)

## License

This configuration is provided as-is. PostgreSQL and Bitnami charts have their own licenses.

## Support

For issues related to:
- **Bitnami Chart**: [GitHub Issues](https://github.com/bitnami/charts/issues)
- **AKS**: [Azure Support](https://azure.microsoft.com/support/)
- **This Configuration**: Open an issue in this repository
