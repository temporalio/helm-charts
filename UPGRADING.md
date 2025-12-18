# Upgrading from Previous Helm Chart Versions

This document outlines the key differences between the previous Helm chart versions and v1.0.0-rc.1, and provides guidance on how to migrate your existing deployments.

## Major Changes

### 1. No Database Sub-Charts

**Previous versions:**
- The chart included Cassandra, Elasticsearch, Prometheus, and Grafana as Helm chart dependencies
- These were installed automatically when you installed the Temporal chart
- You could configure them via top-level keys in your values file (e.g., `cassandra:`, `elasticsearch:`, `prometheus:`, `grafana:`)

**v1.0.0-rc.1:**
- The chart **does not install any database sub-charts**
- You must provide your own persistence (databases) for Temporal to use
- The chart only installs Temporal server components (frontend, history, matching, worker, web UI, admin tools)

**Migration:**
- If you were using the bundled databases, you'll need to:
  1. Set up external databases (MySQL, PostgreSQL, Cassandra, or Elasticsearch)
  2. Migrate your data from the old databases to the new ones
  3. Update your values file to point to the external databases (see Persistence Configuration below)

### 2. Persistence Configuration Format

**Previous versions:**
- Persistence configuration was likely spread across multiple top-level keys
- Configuration was abstracted from the raw Temporal server config format

**v1.0.0-rc.1:**
- Persistence configuration follows the **raw Temporal server config format**
- All persistence configuration is under `server.config.persistence.datastores`
- The driver type is determined by which key is present: `sql:`, `cassandra:`, or `elasticsearch:`

**Example new configuration structure:**

```yaml
server:
  config:
    persistence:
      defaultStore: default
      visibilityStore: visibility
      numHistoryShards: 512
      datastores:
        default:
          sql:
            pluginName: mysql8
            driverName: mysql8
            databaseName: temporal
            connectAddr: "mysql.example.com:3306"
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
        visibility:
          sql:
            pluginName: mysql8
            driverName: mysql8
            databaseName: temporal_visibility
            connectAddr: "mysql.example.com:3306"
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
```

### 3. Helm-Specific Fields

**v1.0.0-rc.1 introduces Helm-specific fields:**
- `existingSecret`: Reference to a Kubernetes secret containing credentials
- `secretKey`: Key name within the secret (defaults to `password`)

These fields are **stripped before rendering** to the Temporal server config. The chart automatically creates environment variables from the secrets that the Temporal server reads.

**Migration:**
- If you were using plain `password` fields, you can continue using them
- Create Kubernetes secrets before installing/upgrading if using `existingSecret`

### 4. Installation Requirements

**Previous versions:**
- All dependencies were included and configured automatically

**v1.0.0-rc.1:**
- You **must** provide persistence configuration before installation
- Databases must be set up and accessible before installing Temporal

**Example installation:**

```bash
# 1. Set up your databases first
# 2. Create a values file with persistence configuration
# 3. Install with version specified to allow release candidates
helm install --repo https://go.temporal.io/helm-charts \
  --version '>=1.0.0-0' \
  -f my-persistence-values.yaml \
  temporal temporal \
  --timeout 900s
```

### 5. Values File Structure

**Key changes in values file structure:**

1. **Persistence configuration** moved to `server.config.persistence.datastores`
2. **No top-level database keys** (no `cassandra:`, `elasticsearch:`, `prometheus:`, `grafana:` at root level)

**Migration steps:**

1. Review your current values file
2. Extract persistence configuration and convert to new format
3. Remove any database sub-chart configurations
4. Update service references if needed
5. Test in a non-production environment first

### 6. Monitoring and Observability

**Previous versions:**
- Prometheus and Grafana were included as sub-charts
- Pre-configured dashboards were available

**v1.0.0-rc.1:**
- Prometheus and Grafana are **not included**
- You must provide your own monitoring stack
- Pre-configured Grafana dashboards are available for import:
  - [Server-General](https://raw.githubusercontent.com/temporalio/dashboards/helm/server/server-general.json)
  - [SDK-General](https://raw.githubusercontent.com/temporalio/dashboards/helm/sdk/sdk-general.json)
  - [Misc - Advanced Visibility Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/advanced-visibility-specific.json)
  - [Misc - Cluster Monitoring Kubernetes](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/clustermonitoring-kubernetes.json)
  - [Misc - Frontend Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/frontend-service-specific.json)
  - [Misc - History Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/history-service-specific.json)
  - [Misc - Matching Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/matching-service-specific.json)
  - [Misc - Worker Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/worker-service-specific.json)

**Migration:**
- Set up your own Prometheus instance
- Set up your own Grafana instance
- Import the dashboards listed above
- Configure Prometheus ServiceMonitor if using Prometheus Operator (enabled via `server.metrics.serviceMonitor.enabled`)

## Migration Checklist

Before upgrading to v1.0.0-rc.1:

- [ ] Review your current values file and identify all persistence configurations
- [ ] Set up external databases (MySQL, PostgreSQL, Cassandra, or Elasticsearch)
- [ ] Migrate data from old databases to new ones (if applicable)
- [ ] Convert persistence configuration to new format under `server.config.persistence.datastores`
- [ ] Create Kubernetes secrets for database credentials (if using `existingSecret`)
- [ ] Remove any database sub-chart configurations from values file
- [ ] Set up monitoring stack (Prometheus/Grafana) if needed
- [ ] Update service references in your applications/scripts
- [ ] Test the migration in a non-production environment
- [ ] Backup your data before upgrading
- [ ] Plan for downtime during migration if needed

## Example Migration

### Old Configuration (hypothetical)

```yaml
cassandra:
  config:
    cluster_size: 3
    keyspace: temporal
elasticsearch:
  enabled: true
  replicas: 3
server:
  config:
    persistence:
      default:
        cassandra:
          hosts: cassandra
          keyspace: temporal
      visibility:
        elasticsearch:
          url: elasticsearch:9200
```

### New Configuration

```yaml
server:
  config:
    persistence:
      defaultStore: default
      visibilityStore: visibility
      numHistoryShards: 512
      datastores:
        default:
          cassandra:
            hosts: "cassandra.example.com:9042"
            port: 9042
            keyspace: temporal
            user: cassandra_user
            existingSecret: temporal-cassandra-secret
            secretKey: password
            replicationFactor: 3
        visibility:
          elasticsearch:
            version: v7
            url:
              scheme: http
              host: "elasticsearch.example.com:9200"
            username: ""
            password: ""
            existingSecret: temporal-es-secret
            secretKey: password
            logLevel: error
            indices:
              visibility: temporal_visibility_v1
```

## Getting Help

If you encounter issues during migration:

1. Review the [README.md](README.md) for detailed configuration examples
2. Check the example values files in `charts/temporal/values/`
3. Join [Temporal's public Slack](https://t.mp/slack) and ask in the `#helm-charts` channel
4. Open an issue on GitHub with details about your migration

## Breaking Changes Summary

| Component | Old Behavior | New Behavior |
|-----------|--------------|--------------|
| Databases | Included as sub-charts | Must provide externally |
| Persistence Config | Top-level keys | Under `server.config.persistence.datastores` |
| Config Format | Abstracted | Raw Temporal server config format |
| Monitoring | Prometheus/Grafana included | Must provide externally |
| Installation | Simple install | Requires version flag and persistence config |
| Secrets | May have used different format | Use `existingSecret` and `secretKey` |

## Notes

- This is a **release candidate** version. Test thoroughly before using in production.
- The chart version must be specified while the chart is still an rc: `--version '>=1.0.0-0'`
- Data migration is your responsibility when moving from bundled databases to external ones
- Some configuration options may have changed - review all settings carefully

