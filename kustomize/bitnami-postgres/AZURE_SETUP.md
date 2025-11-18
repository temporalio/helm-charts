# Azure-Specific Setup Guide for PostgreSQL on AKS

This guide covers Azure-specific configurations for deploying PostgreSQL on AKS.

## Table of Contents

1. [AKS Cluster Setup](#aks-cluster-setup)
2. [Azure Storage Configuration](#azure-storage-configuration)
3. [Azure Key Vault Integration](#azure-key-vault-integration)
4. [Azure Monitor Integration](#azure-monitor-integration)
5. [Networking Configuration](#networking-configuration)
6. [Backup to Azure Blob Storage](#backup-to-azure-blob-storage)
7. [Azure Workload Identity](#azure-workload-identity)

## AKS Cluster Setup

### Create AKS Cluster with Best Practices

```bash
# Variables
RESOURCE_GROUP="rg-aks-postgres"
CLUSTER_NAME="aks-postgres-prod"
LOCATION="eastus"
NODE_COUNT=3
NODE_VM_SIZE="Standard_D4s_v3"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create AKS cluster with availability zones
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --location $LOCATION \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_VM_SIZE \
  --zones 1 2 3 \
  --enable-managed-identity \
  --network-plugin azure \
  --network-policy azure \
  --enable-addons monitoring \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10 \
  --kubernetes-version 1.28 \
  --nodepool-name systempool \
  --nodepool-labels type=system \
  --generate-ssh-keys

# Add dedicated node pool for databases
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name dbpool \
  --node-count 3 \
  --node-vm-size Standard_E4s_v3 \
  --zones 1 2 3 \
  --labels type=database workload=postgres \
  --node-taints database=true:NoSchedule \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 6

# Get credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME
```

### Update values.yaml for dedicated node pool

```yaml
primary:
  nodeSelector:
    type: database
    workload: postgres

  tolerations:
    - key: "database"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

readReplicas:
  nodeSelector:
    type: database
    workload: postgres

  tolerations:
    - key: "database"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

## Azure Storage Configuration

### Create Premium Storage Class with Zone-Redundant Storage

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-premium-zrs
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_ZRS  # Zone-redundant storage
  cachingMode: ReadOnly
  kind: Managed
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
```

### Storage Classes for Different Scenarios

```bash
# Premium SSD LRS (Locally Redundant)
cat <<EOF | kubectl apply -f -
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

# Standard SSD for backups
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-standard
provisioner: disk.csi.azure.com
parameters:
  skuName: StandardSSD_LRS
  cachingMode: ReadOnly
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
```

## Azure Key Vault Integration

### Setup Azure Key Vault Secrets Store CSI Driver

```bash
# Enable Azure Key Vault provider for Secrets Store CSI Driver
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons azure-keyvault-secrets-provider

# Create Azure Key Vault
KV_NAME="kv-postgres-$(uuidgen | cut -d'-' -f1)"
az keyvault create \
  --name $KV_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization false

# Store secrets in Key Vault
az keyvault secret set \
  --vault-name $KV_NAME \
  --name postgres-password \
  --value "$(openssl rand -base64 32)"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name app-password \
  --value "$(openssl rand -base64 32)"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name replication-password \
  --value "$(openssl rand -base64 32)"
```

### Create SecretProviderClass

```bash
# Get AKS managed identity
IDENTITY_CLIENT_ID=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query identityProfile.kubeletidentity.clientId -o tsv)

# Get Key Vault ID
KV_ID=$(az keyvault show --name $KV_NAME --query id -o tsv)

# Grant access to Key Vault
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $IDENTITY_CLIENT_ID \
  --scope $KV_ID

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create SecretProviderClass
cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: postgres-secrets
  namespace: postgres
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$IDENTITY_CLIENT_ID"
    keyvaultName: "$KV_NAME"
    cloudName: ""
    objects: |
      array:
        - |
          objectName: postgres-password
          objectType: secret
          objectVersion: ""
        - |
          objectName: app-password
          objectType: secret
          objectVersion: ""
        - |
          objectName: replication-password
          objectType: secret
          objectVersion: ""
    tenantId: "$TENANT_ID"
  secretObjects:
  - secretName: postgres-credentials
    type: Opaque
    data:
    - objectName: postgres-password
      key: postgres-password
    - objectName: app-password
      key: password
    - objectName: replication-password
      key: replication-password
EOF
```

## Azure Monitor Integration

### Enable Container Insights

```bash
# Enable monitoring addon
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --addons monitoring

# Create Log Analytics workspace (if not exists)
WORKSPACE_NAME="law-aks-postgres"
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --location $LOCATION
```

### Configure Azure Monitor for PostgreSQL

Create ConfigMap for custom metrics:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: container-azm-ms-agentconfig
  namespace: kube-system
data:
  schema-version: v1
  config-version: ver1
  prometheus-data-collection-settings: |-
    [prometheus_data_collection_settings.cluster]
        interval = "1m"
        monitor_kubernetes_pods = true
    [prometheus_data_collection_settings.node]
        interval = "1m"
  default-scrape-settings-enabled: |-
    kubelet = true
    coredns = true
    cadvisor = true
    kubeproxy = true
    apiserver = true
    kubestate = true
    nodeexporter = true
  prometheus-collector-settings: |-
    cluster_alias = "$CLUSTER_NAME"
  metric_collection_settings: |-
    [metric_collection_settings.for_type.node]
        interval = "1m"
    [metric_collection_settings.for_type.pod]
        interval = "1m"
EOF
```

### Create Alert Rules

```bash
# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query id -o tsv)

# Create action group for notifications
az monitor action-group create \
  --name "postgres-alerts" \
  --resource-group $RESOURCE_GROUP \
  --short-name "pg-alert" \
  --email-receiver "admin@example.com" receiver-email

# Create alert for high CPU
az monitor metrics alert create \
  --name "postgres-high-cpu" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP" \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action postgres-alerts
```

## Networking Configuration

### Azure CNI Configuration

The cluster uses Azure CNI for direct pod IP assignment:

```yaml
# Add to values.yaml for production
primary:
  service:
    type: ClusterIP
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      # Use internal load balancer in specific subnet
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "postgres-subnet"
```

### Network Security Groups

```bash
# Create NSG rule for PostgreSQL (if using LoadBalancer)
NSG_NAME="nsg-aks-postgres"
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name $NSG_NAME

# Allow PostgreSQL from application subnet
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name AllowPostgreSQL \
  --priority 100 \
  --source-address-prefixes "10.1.0.0/24" \
  --destination-port-ranges 5432 \
  --protocol Tcp \
  --access Allow
```

### Azure Firewall Integration

```bash
# If using Azure Firewall, add application rules
az network firewall application-rule create \
  --firewall-name "afw-aks" \
  --resource-group $RESOURCE_GROUP \
  --collection-name "postgres-rules" \
  --priority 100 \
  --action Allow \
  --name "allow-postgres-registries" \
  --source-addresses "10.0.0.0/8" \
  --protocols "https=443" \
  --target-fqdns "registry-1.docker.io" "*.docker.io" "*.docker.com"
```

## Backup to Azure Blob Storage

### Create Storage Account for Backups

```bash
# Create storage account
STORAGE_ACCOUNT="sapostgresbackup$(uuidgen | cut -d'-' -f1)"
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Cool

# Create container
az storage container create \
  --name postgres-backups \
  --account-name $STORAGE_ACCOUNT

# Get connection string
STORAGE_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' -o tsv)
```

### Create Backup Job with Azure Blob

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: azure-storage-secret
  namespace: postgres
type: Opaque
stringData:
  azure-storage-account-name: "$STORAGE_ACCOUNT"
  azure-storage-account-key: "$STORAGE_KEY"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup-to-blob
  namespace: postgres
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: registry-1.docker.io/bitnami/postgresql:16
            command:
            - /bin/bash
            - -c
            - |
              PGPASSWORD="\${POSTGRES_PASSWORD}" pg_dumpall \
                -h postgres-postgresql \
                -U postgres \
                --clean --if-exists \
                --quote-all-identifiers \
                --no-password \
                -f /tmp/backup.sql

              # Upload to Azure Blob
              curl -X PUT \
                -H "x-ms-blob-type: BlockBlob" \
                -H "x-ms-date: \$(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
                --data-binary @/tmp/backup.sql \
                "https://\${STORAGE_ACCOUNT}.blob.core.windows.net/postgres-backups/backup-\$(date +%Y%m%d-%H%M%S).sql?\${SAS_TOKEN}"
            env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: postgres-password
            - name: STORAGE_ACCOUNT
              valueFrom:
                secretKeyRef:
                  name: azure-storage-secret
                  key: azure-storage-account-name
          restartPolicy: OnFailure
EOF
```

## Azure Workload Identity

### Setup Workload Identity (Recommended)

```bash
# Enable workload identity on AKS
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get OIDC issuer URL
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create managed identity
IDENTITY_NAME="id-postgres-workload"
az identity create \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Get identity client ID
IDENTITY_CLIENT_ID=$(az identity show \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query clientId -o tsv)

# Create federated credential
az identity federated-credential create \
  --name "postgres-federated-credential" \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:postgres:postgres-sa"

# Grant Key Vault access
az keyvault set-policy \
  --name $KV_NAME \
  --object-id $(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv) \
  --secret-permissions get list
```

Update ServiceAccount in values.yaml:

```yaml
serviceAccount:
  create: true
  name: "postgres-sa"
  annotations:
    azure.workload.identity/client-id: "<IDENTITY_CLIENT_ID>"
  labels:
    azure.workload.identity/use: "true"
```

## Cost Optimization Tips

### Use Spot VMs for Non-Production

```bash
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 1 \
  --min-count 1 \
  --max-count 3 \
  --enable-cluster-autoscaler \
  --labels workload=dev
```

### Reserved Capacity for Production

Consider purchasing Azure Reserved VM Instances for production node pools to save up to 72%.

### Auto-stop for Development

For development environments, consider:
- AKS Stop/Start feature
- Scheduled scaling to 0 replicas during off-hours

```bash
# Stop AKS cluster (dev only)
az aks stop --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP

# Start AKS cluster
az aks start --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

## Disaster Recovery

### Cross-Region Replication Setup

For mission-critical workloads, set up PostgreSQL replication across Azure regions:

1. Deploy primary in Region A (e.g., East US)
2. Deploy standby in Region B (e.g., West US)
3. Configure streaming replication between regions
4. Use Azure Traffic Manager for failover

See [PostgreSQL HA documentation](https://www.postgresql.org/docs/current/high-availability.html) for details.

## Security Recommendations

### Azure Policy for AKS

Apply Azure Policy to enforce:
- Container image restrictions
- Resource limits
- Network policies
- Pod security standards

```bash
# Assign built-in policy initiative
az policy assignment create \
  --name 'aks-baseline-security' \
  --display-name 'AKS Baseline Security' \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP" \
  --policy-set-definition '/providers/Microsoft.Authorization/policySetDefinitions/a8640138-9b0a-4a28-b8cb-1666c838647d'
```

### Azure Defender for Kubernetes

Enable Microsoft Defender for Containers:

```bash
az security pricing create \
  --name Containers \
  --tier Standard
```

## Troubleshooting

### Check Azure CSI Driver

```bash
kubectl get pods -n kube-system -l app=csi-azuredisk-controller
kubectl get pods -n kube-system -l app=csi-azuredisk-node
```

### Verify Storage Provisioning

```bash
kubectl describe pvc -n postgres
kubectl get events -n postgres --sort-by='.lastTimestamp'
```

### Network Connectivity Issues

```bash
# Check NSG rules
az network nsg rule list \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --output table

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres-postgresql.postgres.svc.cluster.local
```

## References

- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Azure Storage Classes](https://learn.microsoft.com/en-us/azure/aks/concepts-storage)
- [Azure Key Vault CSI Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)
- [Azure Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
