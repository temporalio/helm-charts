# Temporal Helm Chart
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts?ref=badge_shield)

Temporal is a distributed, scalable, durable, and highly available orchestration engine designed to execute asynchronous long-running business logic in a resilient way.

This repo contains a V3 [Helm](https://helm.sh) chart that deploys Temporal to a Kubernetes cluster. The dependencies that are bundled with this solution by default offer a baseline configuration to experiment with Temporal software. This Helm chart can also be used to install just the Temporal server, configured to connect to dependencies (such as a Cassandra, MySQL, or PostgreSQL database) that you may already have available in your environment.

The only portions of the helm chart that are considered production ready are the parts that configure and manage Temporal itself. Cassandra, Elasticsearch, Prometheus, and Grafana are all using minimal development configurations, and should be reconfigured in a production deployment.

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

The [Helm repo](https://go.temporal.io/helm-charts/) is the preferred method of installing the chart as it avoids the need for you to clone the repo locally, and also ensures you are using a release which has been tested. All of the examples in this README will use the Helm repo to install the chart.

Note: The values files that we refer to in the examples are not available from the Helm repo. You will need to download them from Github to use them.

The second way of installing the Temporal chart is to clone this git repo and install from there. This method is useful if you are testing changes to the helm chart, but is otherwise not recommended. To use this method, rather than passing `--repo https://go.temporal.io/helm-charts <options> temporal` as in the examples below, run `helm install <options> .` from within the `charts/temporal` directory to tell helm to use the local directory (`.`) for the chart.

If you are using a git clone, you will need to download the Helm dependencies before you install the chart:

```bash
helm dependencies update
```

## Install Temporal with Helm Chart

Temporal can be configured to run with various dependencies. The default "Batteries Included" Helm Chart configuration deploys and configures the following components:

* Cassandra
* Elasticsearch
* Prometheus
* Grafana

The sections that follow describe various deployment configurations, from a minimal one-replica installation using included dependencies, to a replicated deployment on existing infrastructure.

### Minimal installation with required dependencies only

To install Temporal in a limited but working and self-contained configuration (one replica of Cassandra, Elasticsearch and each of Temporal's services, no metrics), you can run:

```bash
helm install \
    --repo https://go.temporal.io/helm-charts \
    --set server.replicaCount=1 \
    --set cassandra.config.cluster_size=1 \
    --set elasticsearch.replicas=1 \
    --set prometheus.enabled=false \
    --set grafana.enabled=false \
    temporaltest temporal \
    --timeout 15m
```

This configuration consumes limited resources and it is useful for small scale tests (such as using minikube).

Note: It used to be possible to install Temporal with just Cassandra. Since Temporal 1.21, this is no longer supported. Cassandra is not supported as a visibility store, so Elasticsearch or an SQL store must be enabled.

Below is an example of an environment installed in this configuration:

```
$ kubectl get pods
NAME                                           READY   STATUS    RESTARTS   AGE
temporaltest-admintools-6cdf56b869-xdxz2       1/1     Running   0          11m
temporaltest-cassandra-0                       1/1     Running   0          11m
temporaltest-frontend-5d5b6d9c59-v9g5j         1/1     Running   2          11m
temporaltest-history-64b9ddbc4b-bwk6j          1/1     Running   2          11m
temporaltest-matching-c8887ddc4-jnzg2          1/1     Running   2          11m
temporaltest-metrics-server-7fbbf65cff-rp2ks   1/1     Running   0          11m
temporaltest-web-77f68bff76-ndkzf              1/1     Running   0          11m
temporaltest-worker-7c9d68f4cf-8tzfw           1/1     Running   2          11m
```

### Install with required and optional dependencies

This method requires a three node kubernetes cluster to successfully bring up all the dependencies.

When installed without manully setting dependency replicas to 1, this Temporal Helm Chart configures Temporal to run with a three node Cassandra cluster (for persistence) and Elasticsearch (for "visibility" features), Prometheus, and Grafana. By default, Temporal Helm Chart installs all dependencies, out of the box.

To install Temporal with all of its dependencies run this command:

```bash
helm install --repo https://go.temporal.io/helm-charts temporaltest temporal --timeout 900s
```

To use your own instance of Elasticsearch, MySQL, PostgreSQL, or Cassandra, please read the "Bring Your Own" sections below.

Other components (Prometheus, Grafana) can be omitted from the installation by setting their corresponding `enable` flag to `false`:

```bash
helm install \
    --repo https://go.temporal.io/helm-charts \
    --set prometheus.enabled=false \
    --set grafana.enabled=false \
    temporaltest temporal \
    --timeout 900s
```

### Install with sidecar containers

You may need to provide your own sidecar containers.

For an example, review the values for Google's `cloud sql proxy` in the `values/values.cloudsqlproxy.yaml` and pass that file to `helm install`:

```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.cloudsqlproxy.yaml temporaltest temporal --timeout 900s
```

### Install with your own Elasticsearch

You might already be operating an instance of Elasticsearch that you want to use with Temporal.

To do so, fill in the relevant configuration values in `values.elasticsearch.yaml`, and pass the file to 'helm install'.

Example:

```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.elasticsearch.yaml temporaltest temporal --timeout 900s
```

### Install with your own MySQL

You might already be operating a MySQL instance that you want to use with Temporal.

In this case, create and configure temporal databases on your MySQL host with `temporal-sql-tool`. The tool is part of [temporal repo](https://github.com/temporalio/temporal), and it relies on the schema definition, in the same repo.

Here are example commands you can use to create and initialize the databases:

```bash
# in https://github.com/temporalio/temporal git repo dir
export SQL_PLUGIN=mysql8
export SQL_HOST=mysql_host
export SQL_PORT=3306
export SQL_USER=mysql_user
export SQL_PASSWORD=mysql_password

make temporal-sql-tool

./temporal-sql-tool --database temporal create-database
SQL_DATABASE=temporal ./temporal-sql-tool setup-schema -v 0.0
SQL_DATABASE=temporal ./temporal-sql-tool update -schema-dir schema/mysql/v8/temporal/versioned

./temporal-sql-tool --database temporal_visibility create-database
SQL_DATABASE=temporal_visibility ./temporal-sql-tool setup-schema -v 0.0
SQL_DATABASE=temporal_visibility ./temporal-sql-tool update -schema-dir schema/mysql/v8/visibility/versioned
```

Once you've initialized the two databases, fill in the configuration values in `values/values.mysql.yaml`, and run

```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.mysql.yaml temporaltest temporal --timeout 900s
```

Alternatively, instead of modifying `values/values.mysql.yaml`, you can supply those values in your command line:

```bash
helm install \
  --repo https://go.temporal.io/helm-charts \
  -f values/values.mysql.yaml \
  --set elasticsearch.enabled=false \
  --set server.config.persistence.default.sql.user=mysql_user \
  --set server.config.persistence.default.sql.password=mysql_password \
  --set server.config.persistence.visibility.sql.user=mysql_user \
  --set server.config.persistence.visibility.sql.password=mysql_password \
  --set server.config.persistence.default.sql.host=mysql_host \
  --set server.config.persistence.visibility.sql.host=mysql_host \
  temporaltest temporal \
  --timeout 900s
```
*NOTE:* Requires MySQL 8.0.17+, older versions are not supported.

### Install with your own PostgreSQL

You might already be operating a PostgreSQL instance that you want to use with Temporal.

In this case, create and configure temporal databases on your PostgreSQL host with `temporal-sql-tool`. The tool is part of [temporal repo](https://github.com/temporalio/temporal), and it relies on the schema definition, in the same repo.

Here are example commands you can use to create and initialize the databases:

```bash
# in https://github.com/temporalio/temporal git repo dir
export SQL_PLUGIN=postgres12
export SQL_HOST=postgresql_host
export SQL_PORT=5432
export SQL_USER=postgresql_user
export SQL_PASSWORD=postgresql_password

make temporal-sql-tool

./temporal-sql-tool --database temporal create-database
SQL_DATABASE=temporal ./temporal-sql-tool setup-schema -v 0.0
SQL_DATABASE=temporal ./temporal-sql-tool update -schema-dir schema/postgresql/v12/temporal/versioned

./temporal-sql-tool --database temporal_visibility create-database
SQL_DATABASE=temporal_visibility ./temporal-sql-tool setup-schema -v 0.0
SQL_DATABASE=temporal_visibility ./temporal-sql-tool update -schema-dir schema/postgresql/v12/visibility/versioned
```

Once you initialized the two databases, fill in the configuration values in `values/values.postgresql.yaml`, and run

```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.postgresql.yaml temporaltest temporal --timeout 900s
```

Alternatively, instead of modifying `values/values.postgresql.yaml`, you can supply those values in your command line:

```bash
helm install \
  --repo https://go.temporal.io/helm-charts \
  -f values/values.postgresql.yaml \
  --set elasticsearch.enabled=false \
  --set server.config.persistence.default.sql.user=postgresql_user \
  --set server.config.persistence.default.sql.password=postgresql_password \
  --set server.config.persistence.visibility.sql.user=postgresql_user \
  --set server.config.persistence.visibility.sql.password=postgresql_password \
  --set server.config.persistence.default.sql.host=postgresql_host \
  --set server.config.persistence.visibility.sql.host=postgresql_host \
  temporaltest temporal --timeout 900s
```

*NOTE:* Requires PostgreSQL 12+, older versions are not supported.

### Install with your own Cassandra

You might already be operating a Cassandra instance that you want to use with Temporal.

In this case, create and setup keyspaces in your Cassandra instance with `temporal-cassandra-tool`. The tool is part of [temporal repo](https://github.com/temporalio/temporal), and it relies on the schema definition, in the same repo.

Here are example commands you can use to create and initialize the keyspaces:

```bash
# in https://github.com/temporalio/temporal git repo dir
export CASSANDRA_HOST=cassandra_host
export CASSANDRA_PORT=9042
export CASSANDRA_USER=cassandra_user
export CASSANDRA_PASSWORD=cassandra_user_password

./temporal-cassandra-tool create-Keyspace -k temporal
CASSANDRA_KEYSPACE=temporal ./temporal-cassandra-tool setup-schema -v 0.0
CASSANDRA_KEYSPACE=temporal ./temporal-cassandra-tool update -schema-dir schema/cassandra/temporal/versioned
```

Once you initialized the two keyspaces, fill in the configuration values in `values/values.cassandra.yaml`, and run

```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.cassandra.yaml temporaltest temporal --timeout 900s
```

Note that Temporal cannot run without setting up a store for Visibility, and Cassandra is not a supported database for Visibility. We recommend using Elasticsearch in this case.

### Enable Archival

By default archival is disabled. You can enable it with one of the three provider options:

* File Store, values file `values/values.archival.filestore.yaml`
* S3, values file `values/values.archival.s3.yaml`
* GCloud, values file `values/values.archival.gcloud.yaml`

So to use the minimal command again and to enable archival with file store provider:
```bash
helm install \
  --repo https://go.temporal.io/helm-charts \
  -f values/values.archival.filestore.yaml \
  --set server.replicaCount=1 \
  --set cassandra.config.cluster_size=1 \
  --set prometheus.enabled=false \
  --set grafana.enabled=false \
  --set elasticsearch.enabled=false \
  temporaltest temporal \
  --timeout 15m
```

Note that if archival is enabled, it is also enabled for all newly created namespaces.
Make sure to update the specific archival provider values file to set your configs.

### Install and configure Temporal

If a live application environment already uses systems that Temporal can use as dependencies, then those systems can continue to be used. This Helm chart can install the minimal pieces of Temporal so that it can then be configured to use those systems as its dependencies.

The example below demonstrates a few things:

1. How to set values via the command line rather than the environment.
2. How to configure a database (shows Cassandra, but MySQL works the same way)
3. How to enable TLS for the database connection.

```bash
helm install \
  --repo https://go.temporal.io/helm-charts \
  -f values/values.cassandra.yaml \
  -f values/values.elasticsearch.yaml \
  --set elasticsearch.enabled=true \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set server.replicaCount=5 \
  --set server.config.persistence.default.cassandra.hosts=cassandra.data.host.example \
  --set server.config.persistence.default.cassandra.user=cassandra_user \
  --set server.config.persistence.default.cassandra.password=cassandra_user_password \
  --set server.config.persistence.default.cassandra.tls.caData=$(base64 --wrap=0 cassandra.ca.pem) \
  --set server.config.persistence.default.cassandra.tls.enabled=true \
  --set server.config.persistence.default.cassandra.replicationFactor=3 \
  --set server.config.persistence.default.cassandra.keyspace=temporal \
  temporaltest temporal \
  --timeout 15m \
  --wait
```

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
temporaltest-admintools                ClusterIP   172.20.237.59    <none>        22/TCP                                         15m
temporaltest-frontend-headless         ClusterIP   None             <none>        7233/TCP,9090/TCP                              15m
temporaltest-history-headless          ClusterIP   None             <none>        7234/TCP,9090/TCP                              15m
temporaltest-matching-headless         ClusterIP   None             <none>        7235/TCP,9090/TCP                              15m
temporaltest-worker-headless           ClusterIP   None             <none>        7239/TCP,9090/TCP                              15m
...
```

```
$ kubectl get pods
...
temporaltest-admintools-7b6c599855-8bk4x                1/1     Running   0          25m
temporaltest-frontend-54d94fdcc4-bx89b                  1/1     Running   2          25m
temporaltest-history-86d8d7869-lzb6f                    1/1     Running   2          25m
temporaltest-matching-6c7d6d7489-kj5pj                  1/1     Running   3          25m
temporaltest-worker-769b996fd-qmvbw                     1/1     Running   2          25m
...
```

### Running Temporal CLI From the Admin Tools Container

You can also shell into `admin-tools` container via [k9s](https://github.com/derailed/k9s) or by running `kubectl exec`:

```
$ kubectl exec -it services/temporaltest-admintools /bin/bash
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

### Forwarding Your Machine's Local Port to Temporal FrontEnd

You can also expose your instance's frontend port on your local machine:

```
$ kubectl port-forward services/temporaltest-frontend-headless 7233:7233
Forwarding from 127.0.0.1:7233 -> 7233
Forwarding from [::1]:7233 -> 7233
```

and, from a separate window, use the local port to access the service from your application or Temporal samples.

### Forwarding Your Machine's Local Port to Temporal Web UI

Similarly to how you accessed the Temporal frontend via Kubernetes port forwarding, you can access your Temporal instance's web user interface.

To do so, forward your machine's local port to the Web service in your Temporal installation:

```
$ kubectl port-forward services/temporaltest-web 8080:8080
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

and navigate to http://127.0.0.1:8080 in your browser.

### Exploring Metrics via Grafana

By default, the full "Batteries Included" configuration comes with a few Grafana dashboards.

To access those dashboards, follow the following steps:

1. Extract Grafana's `admin` password from your installation:

```
$ kubectl get secret --namespace default temporaltest-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

t7EqZQpiB6BztZV321dEDppXbeisdpiEAMgnu6yy%
```

2. Set up port forwarding, so you can access Grafana from your host:

```
$ kubectl port-forward services/temporaltest-grafana 8081:80
Forwarding from 127.0.0.1:8081 -> 3000
Forwarding from [::1]:8081 -> 3000
...
```

3. Navigate to the forwarded Grafana port in your browser (http://localhost:8081/), login as `admin` (using the password from step 1), and click on the "Home" button (upper left corner) to see available dashboards.

### Updating Dynamic Configs

By default dynamic config is empty, if you want to override some properties for your cluster, you should:
1. Create a yaml file with your config (for example dc.yaml).
2. Populate it with some values under server.dynamicConfig prefix (use the sample provided at `values/values.dynamic_config.yaml` as a starting point)
3. Install your helm configuration:
```bash
helm install --repo https://go.temporal.io/helm-charts -f values/values.dynamic_config.yaml temporaltest temporal --timeout 900s
```
Note that if you already have a running cluster you can use the "helm upgrade" command to change dynamic config values:
```bash
helm upgrade --repo https://go.temporal.io/helm-charts -f values/values.dynamic_config.yaml temporaltest temporal --timeout 900s
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

Note: in this example chart, uninstalling a Temporal instance also removes all the data that might have been created during its lifetime.

```bash
helm uninstall temporaltest
```

## Upgrading

To upgrade your cluster, upgrade your database schema (if the release includes schema changes), and then use `helm upgrade` command to perform a rolling upgrade of your installation.

Note:
* Not supported: running newer binaries with an older schema.
* Supported: downgrading binaries – running older binaries with a newer schema.

Example:

### Upgrade Schema

Here are examples of commands you can use to upgrade the "default" schema in your "bring your own" Cassandra database.

Upgrade default schema:

```bash
temporal-cassandra-tool \
   --tls \
   --tls-ca-file ... \
   --user cassandra-user \
   --password cassandra-password \
   --endpoint cassandra.example.com \
   --keyspace temporal \
   --timeout 120 \
   update \
   --schema-dir ./schema/cassandra/temporal/versioned
```

To upgrade a MySQL or PostgreSQL database, use `temporal-sql-tool` tool instead of `temporal-cassandra-tool`.

### Upgrade Temporal Instance's Docker Images

Here is an example of a `helm upgrade` command that can be used to upgrade a cluster:

```bash
helm upgrade \
  --repo https://go.temporal.io/helm-charts \
  -f values/values.cassandra.yaml \
  -f values/values.elasticsearch.yaml \
  --set elasticsearch.enabled=true \
  --set server.replicaCount=8 \
  --set server.config.persistence.default.cassandra.hosts='{c1.example.com,c2.example.com,c3.example.com}' \
  --set server.config.persistence.default.cassandra.user=cassandra-user \
  --set server.config.persistence.default.cassandra.password=cassandra-password \
  --set server.config.persistence.default.cassandra.tls.caData=... \
  --set server.config.persistence.default.cassandra.tls.enabled=true \
  --set server.config.persistence.default.cassandra.replicationFactor=3 \
  --set server.config.persistence.default.cassandra.keyspace=temporal \
  --set server.image.tag=1.24.1 \
  --set server.image.repository=temporalio/server \
  --set admintools.image.tag=1.24.1-tctl-1.18.1-cli-0.12.0 \
  --set admintools.image.repository=temporalio/admin-tools \
  --set web.image.tag=2.27.2 \
  --set web.image.repository=temporalio/web \
  temporaltest temporal \
  --wait \
  --timeout 15m
```

# Contributing

Please see our [CONTRIBUTING guide](CONTRIBUTING.md).

# Acknowledgements

Many thanks to [Banzai Cloud](https://github.com/banzaicloud) whose [Cadence Helm Charts](https://github.com/banzaicloud/banzai-charts/tree/master/cadence) heavily inspired this work.


## License
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts?ref=badge_large)
