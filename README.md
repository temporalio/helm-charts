# Temporal Helm Chart
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts?ref=badge_shield)

Temporal is a distributed, scalable, durable, and highly available orchestration engine designed to execute asynchronous long-running business logic in a resilient way.

This repo contains a V3 [Helm](https://helm.sh) chart that deploys Temporal to a Kubernetes cluster. The dependencies that are bundled with this solution by default offer a baseline configuration to experiment with Temporal software. This Helm chart can also be used to install just the Temporal server, configured to connect to dependencies (such as a Cassandra, MySQL, or PostgreSQL database) that you may already have available in your environment.

The only portions of the helm chart that are considered production ready are the parts that configure and manage Temporal itself. Cassandra and Elasticsearch are all using minimal development configurations, and should be reconfigured in a production deployment.

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

If you are using a git clone, you will need to download the Helm dependencies before you install the chart:

```bash
helm dependencies update
```

## Install Temporal with Helm Chart

Temporal can be configured to run with various dependencies. The default "Batteries Included" Helm Chart configuration deploys and configures a MySQL instance using the bitnami MySQL helm chart.

The sections that follow describe various deployment configurations, from a minimal one-replica installation using included dependencies, to a replicated deployment using external persistence.

### Minimal installation

To install Temporal in a limited but working and self-contained configuration (MySQL and one replica of each of Temporal's services), you can run:

```bash
helm install \
    --repo https://go.temporal.io/helm-charts \
    --set server.replicaCount=1 \
    temporal temporal \
    --timeout 15m
```

This configuration consumes limited resources and it is useful for small scale tests (such as using minikube).

Below is an example of an environment installed in this configuration:

```
$ kubectl get pods
NAME                                           READY   STATUS    RESTARTS   AGE
temporal-admintools-6cdf56b869-xdxz2       1/1     Running   0          11m
temporal-mysql-0                           1/1     Running   0          11m
temporal-frontend-5d5b6d9c59-v9g5j         1/1     Running   2          11m
temporal-history-64b9ddbc4b-bwk6j          1/1     Running   2          11m
temporal-matching-c8887ddc4-jnzg2          1/1     Running   2          11m
temporal-web-77f68bff76-ndkzf              1/1     Running   0          11m
temporal-worker-7c9d68f4cf-8tzfw           1/1     Running   2          11m
```

### Install with sidecar containers

You may need to provide your own sidecar containers.

For an example, review the values for Google's `cloud sql proxy` in the `values/values.cloudsqlproxy.yaml` and pass that file to `helm install`:

```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.cloudsqlproxy.yaml temporal temporal --timeout 900s
```

### Install with a managed MySQL for persistence and visibility

You can start Temporal with MySQL using our prepared chart:
```bash
helm install --repo https://go.temporal.io/helm-charts temporal temporal --set mysql.enabled=true
```

Note that this is the default for the helm chart.

It takes ~1 minute for the deployment to become stable. It should look similar to:
```bash
NAME                                   READY   STATUS      RESTARTS      AGE
temporal-admintools-5f9d766b5b-q7wzw   1/1     Running     0             109s
temporal-frontend-8b98b9965-gh8c6      1/1     Running     4 (53s ago)   109s
temporal-history-6ddc85b6f5-8vfr2      1/1     Running     4 (52s ago)   109s
temporal-matching-85c466498b-hvlzb     1/1     Running     4 (63s ago)   109s
temporal-mysql-0                       1/1     Running     0             109s
temporal-schema-1-dm7t8                0/1     Completed   0             109s
temporal-web-b8cd5487f-6l2g7           1/1     Running     0             109s
temporal-worker-7c5c9bd5d5-fn4zs       1/1     Running     4 (65s ago)   109s
```

You can reach the MySQL database using port-forwarding, for example:
```bash
kubectl port-forward pod/temporal-mysql-0 3306:3306
```

### Install with a managed MySQL for persistence and ElasticSearch for visibility

You can start Temporal with MySQL and ElasticSearch using our prepared chart:
```bash
helm install --repo https://go.temporal.io/helm-charts temporal temporal --set mysql.enabled=true --set elasticsearch.enabled=true
```

It takes ~3 minutes for the deployment to become stable. It should look similar to:
```bash
NAME                                   READY   STATUS      RESTARTS      AGE
elasticsearch-master-0                 1/1     Running     0             16m
temporal-admintools-5f9d766b5b-95fkv   1/1     Running     0             16m
temporal-frontend-7db8b66d8d-qgtpk     1/1     Running     2 (15m ago)   16m
temporal-history-7c5cc89fcd-twk8g      1/1     Running     2 (15m ago)   16m
temporal-matching-58fb4d9c7f-bk7nm     1/1     Running     2 (15m ago)   16m
temporal-mysql-0                       1/1     Running     0             16m
temporal-schema-1-rtqwj                0/1     Completed   0             16m
temporal-web-b8cd5487f-wjkf6           1/1     Running     0             16m
temporal-worker-767989c884-q4qxn       1/1     Running     2 (15m ago)   16m
```

You can reach the MySQL database using port-forwarding, for example:
```bash
kubectl port-forward pod/temporal-mysql-0 3306:3306
```

### Install with your own MySQL

You might already be operating a MySQL instance that you want to use with Temporal.

Copy the [MySQL values file](values/values.mysql.yaml) locally and make edits as required (setting hostname, username etc). The following example assumes you have the values file at `./mysql.values.yaml`, adjust the commands below as required if it's at a different path.

You can then install using:

```bash
helm install --repo https://go.temporal.io/helm-charts -f mysql.values.yaml temporal temporal --timeout 900s
```

### Install with your own PostgreSQL

You might already be operating a PostgreSQL instance that you want to use with Temporal.

Copy the [Postgres values file](values/values.postgresql.yaml) locally and make edits as required (setting hostname, username etc). The following example assumes you have the values file at `./postgresql.values.yaml`, adjust the commands below as required if it's at a different path.

You can then install using:

```bash
helm install --repo https://go.temporal.io/helm-charts -f postgresql.values.yaml temporal temporal --timeout 900s
```

### Install with your own Cassandra

You might already be operating a Cassandra instance that you want to use with Temporal.

Copy the [Cassandra values file](values/values.cassandra.yaml) locally and make edits as required (setting hostname, username etc). The following example assumes you have the values file at `./cassandra.values.yaml`, adjust the commands below as required if it's at a different path.

Note that Temporal cannot run without setting up a store for Visibility, and Cassandra is not a supported database for Visibility. We recommend using Elasticsearch in this case.

For this example we will assume you are using an external Elasticsearch cluster, copy the Elasticsearch values file as described in the following section.

You can then install using:

```bash
helm install --repo https://go.temporal.io/helm-charts -f cassandra.values.yaml -f elasticsearch.values.yaml temporal temporal --timeout 900s
```

### Install with your own Elasticsearch

You might already be operating a Elasticsearch instance that you want to use with Temporal.

Copy the [Elasticsearch values file](values/values.elasticsearch.yaml) locally and make edits as required (setting hostname, username etc). The following example assumes you have the values file at `./elasticsearch.values.yaml`, adjust the commands below as required if it's at a different path.

You can then install using:

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

From there, you can use `tctl` or the [`temporal` CLI](https://docs.temporal.io/cli):

```
bash-5.0# tctl namespace list
Name: temporal-system
Id: 32049b68-7872-4094-8e63-d0dd59896a83
Description: Temporal internal system namespace
OwnerEmail: temporal-core@temporal.io
NamespaceData: map[string]string(nil)
Status: Registered
RetentionInDays: 7
EmitMetrics: true
ActiveClusterName: active
Clusters: active
HistoryArchivalStatus: Disabled
VisibilityArchivalStatus: Disabled
Bad binaries to reset:
+-----------------+----------+------------+--------+
| BINARY CHECKSUM | OPERATOR | START TIME | REASON |
+-----------------+----------+------------+--------+
+-----------------+----------+------------+--------+
```

```
bash-5.0# tctl --namespace nonesuch namespace desc
Error: Namespace nonesuch does not exist.
Error Details: Namespace nonesuch does not exist.
```
```
bash-5.0# tctl --namespace nonesuch namespace re
Namespace nonesuch successfully registered.
```
```
bash-5.0# tctl --namespace nonesuch namespace desc
Name: nonesuch
UUID: 465bb575-8c01-43f8-a67d-d676e1ae5eae
Description:
OwnerEmail:
NamespaceData: map[string]string(nil)
Status: Registered
RetentionInDays: 3
EmitMetrics: false
ActiveClusterName: active
Clusters: active
HistoryArchivalStatus: ArchivalStatusDisabled
VisibilityArchivalStatus: ArchivalStatusDisabled
Bad binaries to reset:
+-----------------+----------+------------+--------+
| BINARY CHECKSUM | OPERATOR | START TIME | REASON |
+-----------------+----------+------------+--------+
+-----------------+----------+------------+--------+
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
