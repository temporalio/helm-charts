# Quick Start Guide - PostgreSQL on AKS

This guide will get you up and running with PostgreSQL on AKS in under 10 minutes.

## Prerequisites Checklist

- [ ] AKS cluster running (Kubernetes 1.23+)
- [ ] `kubectl` configured and connected to your cluster
- [ ] `kustomize` installed (v4.0+)
- [ ] `helm` installed (v3.8.0+)

## 5-Minute Deployment

### Step 1: Create Namespace and Secret (1 min)

```bash
# Navigate to the kustomize directory
cd kustomize/bitnami-postgres

# Create namespace and generate random passwords
make create-secret
```

Or manually:

```bash
kubectl create namespace postgres

kubectl create secret generic postgres-credentials \
  --from-literal=postgres-password="$(openssl rand -base64 32)" \
  --from-literal=password="$(openssl rand -base64 32)" \
  --from-literal=replication-password="$(openssl rand -base64 32)" \
  --namespace=postgres
```

### Step 2: Deploy PostgreSQL (2 min)

**For Development/Staging (Standalone):**

```bash
# Using Make
make deploy-base

# Or using kustomize directly
kustomize build base --enable-helm | kubectl apply -f -
```

**For Production (High Availability):**

```bash
# Using Make
make deploy-prod

# Or using kustomize directly
kustomize build overlays/production --enable-helm | kubectl apply -f -
```

### Step 3: Verify Deployment (1 min)

```bash
# Using Make
make verify

# Or manually
kubectl get pods -n postgres
kubectl get pvc -n postgres
kubectl get svc -n postgres
```

Wait for pods to be ready:
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n postgres --timeout=300s
```

### Step 4: Test Connection (1 min)

```bash
# Using Make
make test-connection

# Or manually
export POSTGRES_PASSWORD=$(kubectl get secret --namespace postgres postgres-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)

kubectl run postgres-client --rm --tty -i --restart='Never' \
  --namespace postgres \
  --image registry-1.docker.io/bitnami/postgresql:16 \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql -h postgres-postgresql -U postgres -d appdb -c "SELECT version();"
```

## Common Commands

### Get Connection Information

```bash
make connection-string
```

Output:
```
Host: postgres-postgresql.postgres.svc.cluster.local
Port: 5432
Database: appdb
User: postgres
Password: <your-password>
```

### Access from Local Machine

```bash
make port-forward
```

Then in another terminal:
```bash
export PGPASSWORD="<password-from-previous-command>"
psql -h localhost -p 5432 -U postgres -d appdb
```

### View Logs

```bash
make logs
```

### Check Health

```bash
make health
```

### Trigger Backup

```bash
make backup-now
```

## Configuration Customization

### Minimal Custom Values

Create `custom-values.yaml`:

```yaml
primary:
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"

  persistence:
    size: 50Gi

auth:
  database: "myapp"
  username: "myuser"
```

Deploy with custom values:

```bash
# Add to kustomization.yaml
helmCharts:
  - name: postgresql
    valuesFile: custom-values.yaml
```

### Common Customizations

#### Change Database Name

In `base/values.yaml`:
```yaml
global:
  postgresql:
    auth:
      database: "your-database-name"
      username: "your-username"
```

#### Adjust Resource Limits

```yaml
primary:
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
    requests:
      cpu: 2000m
      memory: 4Gi
```

#### Change Storage Size

```yaml
primary:
  persistence:
    size: 200Gi
```

#### Enable High Availability

```yaml
architecture: replication

readReplicas:
  replicaCount: 2
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n postgres postgres-postgresql-primary-0

# Check events
kubectl get events -n postgres --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n postgres postgres-postgresql-primary-0
```

### Storage Issues

```bash
# Check storage class exists
kubectl get storageclass

# Check PVC status
kubectl get pvc -n postgres

# Describe PVC for issues
kubectl describe pvc -n postgres data-postgres-postgresql-primary-0
```

### Connection Refused

```bash
# Verify service is running
kubectl get svc -n postgres

# Check if PostgreSQL is ready
kubectl exec -n postgres postgres-postgresql-primary-0 -- pg_isready -U postgres

# Check network policy
kubectl get networkpolicy -n postgres
```

### Password Issues

If you forgot the password:

```bash
# Get the current password
kubectl get secret --namespace postgres postgres-credentials -o jsonpath="{.data.postgres-password}" | base64 -d

# Or reset it (WARNING: requires pod restart)
kubectl delete secret postgres-credentials -n postgres
make create-secret
kubectl rollout restart statefulset/postgres-postgresql-primary -n postgres
```

## Next Steps

1. **Set up Monitoring**
   - Configure Prometheus/Grafana
   - Set up Azure Monitor alerts
   - See [README.md](README.md#monitoring) for details

2. **Configure Backups**
   - Review backup schedule
   - Test restore procedure
   - Set up backup retention policy
   - See [README.md](README.md#backup-and-restore)

3. **Implement Security**
   - Enable TLS/SSL
   - Configure network policies
   - Set up Azure Key Vault integration
   - See [AZURE_SETUP.md](AZURE_SETUP.md#azure-key-vault-integration)

4. **Production Readiness**
   - Review resource limits
   - Configure high availability
   - Set up disaster recovery
   - Plan for scaling

## Cleanup

To remove everything:

```bash
make clean
```

Or manually:

```bash
# Delete PostgreSQL
kustomize build base --enable-helm | kubectl delete -f -

# Delete PVCs (WARNING: This deletes data!)
kubectl delete pvc -n postgres --all

# Delete namespace
kubectl delete namespace postgres
```

## Support

For issues:
- Check [README.md](README.md#troubleshooting)
- Check [AZURE_SETUP.md](AZURE_SETUP.md#troubleshooting)
- Review [Bitnami PostgreSQL documentation](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)

## Useful Resources

- [Full Documentation](README.md)
- [Azure-Specific Setup](AZURE_SETUP.md)
- [PostgreSQL Official Docs](https://www.postgresql.org/docs/)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Kustomize Documentation](https://kustomize.io/)
