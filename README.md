# Temporal Helm Chart
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts?ref=badge_shield)

> **Note:** This version is currently an RC (release candidate). To install it, you must specify the version using `--version '>=1.0.0-0'` in your helm install command.

> **For existing users:** If you're upgrading from a previous version of the Temporal Helm chart, please see [UPGRADING.md](UPGRADING.md) for important migration information and breaking changes.

Temporal is a distributed, scalable, durable, and highly available orchestration engine designed to execute asynchronous long-running business logic in a resilient way.

This repo contains a V3 [Helm](https://helm.sh) chart that deploys Temporal to a Kubernetes cluster. This Helm chart installs only the Temporal server components. You must provide persistence (databases) for Temporal to use - the chart does not install any database sub-charts.

The persistence configuration follows the raw Temporal server config format, allowing you to configure MySQL, PostgreSQL, Cassandra, or Elasticsearch databases directly.

This Helm Chart code is tested by a dedicated test pipeline. It is also used extensively by other Temporal pipelines for testing various aspects of Temporal systems. Our test pipeline currently uses Helm 3.1.1.

# Install Temporal service on a Kubernetes cluster

## Prerequisites

This sequence assumes
* that your system is configured to access a kubernetes cluster (e. g. [AWS EKS](https://aws.amazon.com/eks/), [kind](https://kind.sigs.k8s.io/), or [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/))
* that your machine has the following installed and able to access your cluster:
  - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  - [Helm v3](https://helm.sh)

This repo only contains one chart currently, but is structured in the standard helm repo way. This means you will find the chart in the `charts/temporal` directory. All example `helm` commands below should be run from that directory.

## Methods for installing

There are two ways to install the Temporal chart, via our helm repo, or using a local git clone of this repo.

The Helm repo (`https://go.temporal.io/helm-charts/`) is the preferred method of installing the chart as it avoids the need for you to clone the repo locally, and also ensures you are using a release which has been tested. All of the examples in this README will use the Helm repo to install the chart.

Note: The values files that we refer to in the examples are not available from the Helm repo. You will need to download them from Github to use them.

The second way of installing the Temporal chart is to clone this git repo and install from there. This method is useful if you are testing changes to the helm chart, but is otherwise not recommended. To use this method, rather than passing `--repo https://go.temporal.io/helm-charts <options> temporal` as in the examples below, run `helm install <options> .` from within the `charts/temporal` directory to tell helm to use the local directory (`.`) for the chart.

## Install Temporal with Helm Chart

This Helm chart deploys only the Temporal server components. You must provide persistence (databases) for Temporal to use. The chart does not install any database sub-charts.

The sections that follow describe various deployment configurations using persistence.

### Persistence Configuration

Temporal requires persistence stores for:
- **Default store**: Stores workflow execution data (history, tasks, etc.)
- **Visibility store**: Stores workflow visibility/search data

You can use SQL databases (MySQL, PostgreSQL) or Cassandra for the default store, and SQL databases or Elasticsearch for the visibility store.

The persistence configuration follows the raw Temporal server config format. Configure it under `server.config.persistence.datastores`:

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
            createDatabase: true
            manageSchema: true
            pluginName: mysql8  # or postgres12, postgres12_pgx
            driverName: mysql8
            databaseName: temporal
            connectAddr: "mysql.example.com:3306"
            connectProtocol: tcp
            user: temporal_user
            password: ""  # Use existingSecret in production
            existingSecret: temporal-db-secret
            secretKey: password
            maxConns: 20
            maxIdleConns: 20
            maxConnLifetime: "1h"
        visibility:
          sql:
            createDatabase: true
            manageSchema: true
            pluginName: mysql8
            driverName: mysql8
            databaseName: temporal_visibility
            connectAddr: "mysql.example.com:3306"
            connectProtocol: tcp
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
```

**Key points:**
- Driver is determined by which key is present (`sql:`, `cassandra:`, or `elasticsearch:`)
- Helm-specific fields (`existingSecret`, `secretKey`) are stripped before rendering to server config
- Password fields are stored in Kubernetes secrets and the server configuration reads them from the environment
- All other fields pass through directly to the Temporal server config

See the example values files in the `values/` directory for complete examples.

### Install with sidecar containers

You may need to provide your own sidecar containers (e.g., for database proxies).

For an example, review the values for Google's `cloud sql proxy` in the `values/values.cloudsqlproxy.yaml` and pass that file to `helm install`:

```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.cloudsqlproxy.yaml temporal temporal --timeout 900s
```

### Install with MySQL

To use a MySQL database, copy the [MySQL values file](values/values.mysql.yaml) locally and edit it with your database connection details:

```yaml
server:
  config:
    persistence:
      datastores:
        default:
          sql:
            createDatabase: true
            manageSchema: true
            pluginName: mysql8
            driverName: mysql8
            databaseName: temporal
            connectAddr: "mysql.example.com:3306"
            user: temporal_user
            password: your_password
            # Or use existingSecret for production
            # existingSecret: temporal-db-secret
            # secretKey: password
        visibility:
          sql:
            createDatabase: true
            manageSchema: true
            pluginName: mysql8
            driverName: mysql8
            databaseName: temporal_visibility
            connectAddr: "mysql.example.com:3306"
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
```

Then install:

```bash
helm install --repo https://go.temporal.io/helm-charts -f mysql.values.yaml temporal temporal --timeout 900s
```

### Install with PostgreSQL

To use a PostgreSQL database, copy the [PostgreSQL values file](values/values.postgresql.yaml) locally and edit it with your database connection details:

```yaml
server:
  config:
    persistence:
      datastores:
        default:
          sql:
            createDatabase: true
            manageSchema: true
            pluginName: postgres12
            driverName: postgres12
            databaseName: temporal
            connectAddr: "postgres.example.com:5432"
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
        visibility:
          sql:
            createDatabase: true
            manageSchema: true
            pluginName: postgres12
            driverName: postgres12
            databaseName: temporal_visibility
            connectAddr: "postgres.example.com:5432"
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
```

Then install:

```bash
helm install --repo https://go.temporal.io/helm-charts -f postgresql.values.yaml temporal temporal --timeout 900s
```

### Install with Cassandra

To use a Cassandra cluster, copy the [Cassandra values file](values/values.cassandra.yaml) locally and edit it with your cluster connection details.

**Note:** Cassandra cannot be used for the visibility store. You must use SQL or Elasticsearch for visibility.

```yaml
server:
  config:
    persistence:
      datastores:
        default:
          cassandra:
            createDatabase: true
            manageSchema: true
            hosts: "cassandra1.example.com,cassandra2.example.com"
            port: 9042
            keyspace: temporal
            user: cassandra_user
            password: your_password
            replicationFactor: 3
        visibility:
          # Use SQL or Elasticsearch for visibility
          sql:
            createDatabase: true
            manageSchema: true
            pluginName: mysql8
            driverName: mysql8
            databaseName: temporal_visibility
            connectAddr: "mysql.example.com:3306"
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
```

Then install:

```bash
helm install --repo https://go.temporal.io/helm-charts -f cassandra.values.yaml temporal temporal --timeout 900s
```

### Install with Elasticsearch

To use an Elasticsearch cluster for visibility, copy the [Elasticsearch values file](values/values.elasticsearch.yaml) locally and edit it:

```yaml
server:
  config:
    persistence:
      datastores:
        default:
          # Configure your default store (SQL or Cassandra)
          sql:
            createDatabase: true
            manageSchema: true
            pluginName: mysql8
            driverName: mysql8
            databaseName: temporal
            connectAddr: "mysql.example.com:3306"
            user: temporal_user
            existingSecret: temporal-db-secret
            secretKey: password
        visibility:
          elasticsearch:
            version: v7
            url:
              scheme: http
              host: "elasticsearch.example.com:9200"
            username: ""
            password: ""
            # Or use existingSecret
            # existingSecret: temporal-es-secret
            # secretKey: password
            logLevel: error
            indices:
              visibility: temporal_visibility_v1
```

Then install:

```bash
helm install --repo https://go.temporal.io/helm-charts -f elasticsearch.values.yaml temporal temporal --timeout 900s
```

### Enable Archival

By default archival is disabled. You can enable it with one of the three provider options:

* File Store, values file `values/values.archival.filestore.yaml`
* S3, values file `values/values.archival.s3.yaml`
* GCloud, values file `values/values.archival.gcloud.yaml`

So to use the minimal command again and to enable archival with file store provider:
```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.archival.filestore.yaml temporal temporal --timeout 900s
```

Note that if archival is enabled, it is also enabled for all newly created namespaces.
Make sure to update the specific archival provider values file to set your configs.

### Enable SSO in Temporal UI

To enable SSO in the temporal UI set following env variables in the `web.additionalEnv`:

```yaml
- name: TEMPORAL_AUTH_ENABLED
  value: "true"
- name: TEMPORAL_AUTH_PROVIDER_URL
  value: "https://accounts.google.com"
- name: TEMPORAL_AUTH_CLIENT_ID
  value: "xxxxx-xxxx.apps.googleusercontent.com"
- name: TEMPORAL_AUTH_CALLBACK_URL
  value: "https://xxxx.com:8080/auth/sso/callback"
```

In the `web.additionalEnvSecretName` set the secret name, the secret should have following

```yaml
TEMPORAL_AUTH_CLIENT_SECRET: xxxxxxxxxxxxxxx
```

Reference: <https://docs.temporal.io/references/web-ui-server-env-vars>

## Play With It

### Exploring Your Cluster

You can use your favorite kubernetes tools ([k9s](https://github.com/derailed/k9s), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), etc.) to interact with your cluster.

```bash
$ kubectl get svc
NAME                                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                        AGE
...
temporal-admintools                ClusterIP   172.20.237.59    <none>        22/TCP                                         15m
temporal-frontend-headless         ClusterIP   None             <none>        7233/TCP,9090/TCP                              15m
temporal-history-headless          ClusterIP   None             <none>        7234/TCP,9090/TCP                              15m
temporal-matching-headless         ClusterIP   None             <none>        7235/TCP,9090/TCP                              15m
temporal-worker-headless           ClusterIP   None             <none>        7239/TCP,9090/TCP                              15m
...
```

```
$ kubectl get pods
...
temporal-admintools-7b6c599855-8bk4x                1/1     Running   0          25m
temporal-frontend-54d94fdcc4-bx89b                  1/1     Running   2          25m
temporal-history-86d8d7869-lzb6f                    1/1     Running   2          25m
temporal-matching-6c7d6d7489-kj5pj                  1/1     Running   3          25m
temporal-worker-769b996fd-qmvbw                     1/1     Running   2          25m
...
```

### Running Temporal CLI From the Admin Tools Container

You can also shell into `admin-tools` container via [k9s](https://github.com/derailed/k9s) or by running `kubectl exec`:

```
$ kubectl exec -it services/temporal-admintools /bin/bash
bash-5.0#
```

From there, you can use [`temporal` CLI](https://docs.temporal.io/cli):

```
bash-5.0# temporal operator namespace list
  NamespaceInfo.Name                    temporal-system
  NamespaceInfo.Id                      32049b68-7872-4094-8e63-d0dd59896a83
  NamespaceInfo.Description             Temporal internal system namespace
  NamespaceInfo.OwnerEmail              temporal-core@temporal.io
  NamespaceInfo.State                   Registered
  NamespaceInfo.Data                    map[]
  Config.WorkflowExecutionRetentionTtl  168h0m0s
  ReplicationConfig.ActiveClusterName   active
  ReplicationConfig.Clusters            [{"clusterName":"active"}]
  ReplicationConfig.State               Unspecified
  Config.HistoryArchivalState           Disabled
  Config.VisibilityArchivalState        Disabled
  IsGlobalNamespace                     false
  FailoverVersion                       0
  FailoverHistory                       []
  Config.HistoryArchivalUri
  Config.VisibilityArchivalUri
  Config.CustomSearchAttributeAliases   map[]
```

```
bash-5.0# temporal operator namespace -n nonesuch describe
time=2025-12-03T13:49:04.285 level=ERROR msg="unable to describe namespace nonesuch: Namespace nonesuch is not found."
```

```
bash-5.0# temporal operator namespace create -n nonesuch
Namespace nonesuch successfully registered.
```

```
bash-5.0# temporal operator namespace -n nonesuch describe
  NamespaceInfo.Name                    nonesuch
  NamespaceInfo.Id                      ab41501e-ee33-40d8-8b67-bf247e0bc0d2
  NamespaceInfo.Description
  NamespaceInfo.OwnerEmail
  NamespaceInfo.State                   Registered
  NamespaceInfo.Data                    map[]
  Config.WorkflowExecutionRetentionTtl  72h0m0s
  ReplicationConfig.ActiveClusterName   active
  ReplicationConfig.Clusters            [{"clusterName":"active"}]
  ReplicationConfig.State               Normal
  Config.HistoryArchivalState           Disabled
  Config.VisibilityArchivalState        Disabled
  IsGlobalNamespace                     false
  FailoverVersion                       0
  FailoverHistory                       []
  Config.HistoryArchivalUri
  Config.VisibilityArchivalUri
  Config.CustomSearchAttributeAliases   map[]
```

### Forwarding Your Machine's Local Port to Temporal Frontend

You can also expose your instance's frontend port on your local machine:

```
$ kubectl port-forward services/temporal-frontend-headless 7233:7233
Forwarding from 127.0.0.1:7233 -> 7233
Forwarding from [::1]:7233 -> 7233
```

and, from a separate window, use the local port to access the service from your application or Temporal samples.

### Forwarding Your Machine's Local Port to Temporal Web UI

Similarly to how you accessed the Temporal frontend via Kubernetes port forwarding, you can access your Temporal instance's web user interface.

To do so, forward your machine's local port to the Web service in your Temporal installation:

```
$ kubectl port-forward services/temporal-web 8080:8080
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

and navigate to http://127.0.0.1:8080 in your browser.

### Exploring Metrics via Grafana

There are a number of preconfigured dashboards that you may import into your Grafana installation.

* [Server-General](https://raw.githubusercontent.com/temporalio/dashboards/helm/server/server-general.json)
* [SDK-General](https://raw.githubusercontent.com/temporalio/dashboards/helm/sdk/sdk-general.json)
* [Misc - Advanced Visibility Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/advanced-visibility-specific.json)
* [Misc - Cluster Monitoring Kubernetes](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/clustermonitoring-kubernetes.json)
* [Misc - Frontend Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/frontend-service-specific.json)
* [Misc - History Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/history-service-specific.json)
* [Misc - Matching Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/matching-service-specific.json)
* [Misc - Worker Service Specific](https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/worker-service-specific.json)

### Updating Dynamic Configs

By default dynamic config is empty, if you want to override some properties for your cluster, you should:
1. Create a yaml file with your config (for example dc.yaml).
2. Populate it with some values under server.dynamicConfig prefix (use the sample provided at `values/values.dynamic_config.yaml` as a starting point)
3. Install your helm configuration:
```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.dynamic_config.yaml temporal temporal --timeout 900s
```
Note that if you already have a running cluster you can use the "helm upgrade" command to change dynamic config values:
```bash
helm upgrade --repo https://go.temporal.io/helm-charts -f values/values.dynamic_config.yaml temporal temporal --timeout 900s
```

WARNING: The "helm upgrade" approach will trigger a rolling upgrade of all the pods.

If a rolling upgrade is not desirable, you can also generate the ConfigMap file explicitly and then apply it using the following command:

```bash
kubectl apply -f dynamicconfigmap.yaml
```
You can use helm upgrade with the "--dry-run" option to generate the content for the dynamicconfigmap.yaml.

The dynamic-config ConfigMap is referenced as a mounted volume within the Temporal Containers, so any applied change will be automatically picked up by all pods within a few minutes without the need for pod recycling. See k8S documentation (https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#mounted-configmaps-are-updated-automatically) for more details on how this works.

### Updating Temporal Web UI Config

The default web UI configuration is shown here (https://docs.temporal.io/references/web-ui-configuration). To override the default config, you need to provide environment variables in `web.additionalEnv` in the `values.yml` file. You can refer to the available environment variables here (https://docs.temporal.io/references/web-ui-environment-variables).

For example, to serve the UI from a subpath:

```
web:
  additionalEnv:
    - name: TEMPORAL_UI_PUBLIC_PATH
      value: /custom-path
```

## Uninstalling

Note: Depending on how the persistence is configured, this may remove all of the Temporal data.

```bash
helm uninstall temporal
```

## Upgrading

To upgrade your cluster, upgrade your database schema (if the release includes schema changes), and then use `helm upgrade` command to perform a rolling upgrade of your installation.

Note:
* Not supported: running newer binaries with an older schema.
* Supported: downgrading binaries – running older binaries with a newer schema.

# Contributing

Please see our [CONTRIBUTING guide](CONTRIBUTING.md).

# Acknowledgements

Many thanks to [Banzai Cloud](https://github.com/banzaicloud) whose [Cadence Helm Charts](https://github.com/banzaicloud/banzai-charts/tree/master/cadence) heavily inspired this work.


## License
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts?ref=badge_large)
