# Temporal
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts?ref=badge_shield)


Temporal is a distributed, scalable, durable, and highly available orchestration engine to execute asynchronous long-running business logic in a scalable and resilient way.

This repo contains a basic [Helm](https://helm.sh) chart that allows you to install temporal to a kubernetes cluster, and to play with it.

The version of Helm chart is provided for demo purposes and is not intended to be used in production systems.

# Deploying Temporal Service to a Kubernetes Cluster

## Prerequisites

This sequence assumes that your system is configured to access a kubernetes cluster (e. g. [AWS EKS](https://aws.amazon.com/eks/), or [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)), and that your machine has [AWS CLI V2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and [Helm v3.1.x](https://helm.sh) installed and able to access your cluster.

## Install an Instance of Temporal to Your k8s Cluster

Download Helm dependencies:

```bash
~/temporal-helm$ helm dependencies update
```

### Install Temporal

Temporal can be configured to run with a couple of database choices.

#### [Tiny] Batteries Included

To install Temporal in a limited but working configuration (one replica of Cassandra and each of Temporal's services, no metrics or Elastic Search), you can run the following command

```
~/temporal-helm$ helm install \
    --set server.replicaCount=1 \
    --set cassandra.config.cluster_size=1 \
    --set prometheus.enabled=false \
    --set grafana.enabled=false \
    --set elasticsearch.enabled=false \
    --set kafka.enabled=false \
    temporaltest . --timeout 15m
```

This configuration consumes limited resources and it is useful for small scale test deployments (such as minikube).

Below is an example of an enviroment installed in this configuration:

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


#### Default Installation: Batteries Included

By default, Temporal Helm Chart configures Temporal to runs with Cassandra (for persistence) and ElasticSearch/Kafka (for "visibility" features), Prometheus, and Grafana. By default, Temporal Helm Chart installs all dependencies, out of the box.

To install Temporal with all of its dependencies, including Cassandra and ElasticSearch, run this command:

```bash
~/temporal-helm$ helm install temporaltest . --timeout 900s
```

To use your own instance of ElasticSearch, MySQL, or Cassandra, please read the "Bring Your Own" sections below.

Other components (Prometheus, Kafka, Grafana) can be omitted from the installation by setting their corresponding 'enable' flag to `false` (and by pointing `server.kafka.host` to your existing instance of Kafka):


```bash
~/temporal-helm$ helm install
    --set prometheus.enabled=false \
    --set grafana.enabled=false \
    --set kafka.enabled=false \
    --set server.kafka.host=mykafka-headless:9092
    temporaltest . --timeout 900s
```


#### Bring Your Own ElasticSearch

You might already be operating an instance of ElasticSearch that you want to use with Temporal.

To do so, fill in the relevant configuration values in `values.elasticsearch.yaml`, and pass the file to 'helm install'.

Example:

```bash
~/temporal-helm$ helm install -f values/values.elasticsearch.yaml temporaltest . --timeout 900s
```


#### Bring Your Own MySQL

You might already be operating a MySQL instance that you want to use with Temporal.

In this case, create and configure temporal databases on your MySQL host with `temporal-sql-tool`. The tool is part of [temporal repo](https://github.com/temporalio/temporal), and it relies on the schema definition, in the same repo.


Here are the commands you can use to create and initialize the databases:

```bash
~/temporal$ export SQL_DRIVER=sql
~/temporal$ export SQL_HOST=mysqlhost
~/temporal$ export SQL_PORT=3306
~/temporal$ export SQL_USER=mysqluser
~/temporal$ export SQL_PASSWORD=userpassword

~/temporal$ ./temporal-sql-tool create-database -database temporal
~/temporal$ SQL_DATABASE=temporal ./temporal-sql-tool setup-schema -v 0.0
~/temporal$ SQL_DATABASE=temporal ./temporal-sql-tool update -schema-dir schema/mysql/v57/temporal/versioned

~/temporal$ ./temporal-sql-tool create-database -database temporal_visibility
~/temporal$ SQL_DATABASE=temporal_visibility ./temporal-sql-tool setup-schema -v 0.0
~/temporal$ SQL_DATABASE=temporal_visibility ./temporal-sql-tool update -schema-dir schema/mysql/v57/visibility/versioned
```


Once you initialized the two databases, fill in the configuration values in `values/values.mysql.yaml`, and run

```bash
~/temporal-helm$ helm install -f values/values.mysql.yaml temporaltest . --timeout 900s
```

Alternatively, instad of modifying `values/values.mysql.yaml`, you can supply those values in your command line:

```bash
~/temporal-helm$ helm install -f values/values.mysql.yaml temporaltest --set server.config.persistence.default.sql.user=mysqluser --set server.config.persistence.default.sql.password=userpassword --set server.config.persistence.visibility.sql.user=mysqluser --set server.config.persistence.visibility.sql.password=userpassword --set server.config.persistence.default.sql.host=mysqlhost --set server.config.persistence.visibility.sql.host=mysqlhost . --timeout 900s
```

#### Bring Your Own Cassandra

You might already be operating a Cassandra instance that you want to use with Temporal.

In this case, create and setup keyspaces in your Cassandra instance with `temporal-cassandra-tool`. The tool is part of [temporal repo](https://github.com/temporalio/temporal), and it relies on the schema definition, in the same repo.


Here are the commands you can use to create and initialize the keyspaces:

```bash

~/temporal$ export CASSANDRA_HOST=cassandra.default.svc.cluster.local
~/temporal$ export CASSANDRA_PORT=9042
~/temporal$ export CASSANDRA_USER=cassandra_user
~/temporal$ export CASSANDRA_PASSWORD=cassandra_user_password

~/temporal$ ./temporal-cassandra-tool create-Keyspace -k temporal
~/temporal$ CASSANDRA_KEYSPACE=temporal ./temporal-cassandra-tool setup-schema -v 0.0
~/temporal$ CASSANDRA_KEYSPACE=temporal ./temporal-cassandra-tool update -schema-dir schema/cassandra/temporal/versioned

~/temporal$ ./temporal-cassandra-tool create-Keyspace -k temporal_visibility
~/temporal$ CASSANDRA_KEYSPACE=temporal_visibility ./temporal-cassandra-tool setup-schema  -v 0.0
~/temporal$ CASSANDRA_KEYSPACE=temporal_visibility ./temporal-cassandra-tool update -schema-dir schema/cassandra/visibility/versioned
```

Once you initialized the two keyspaces, fill in the configuration values in `values/values.cassandra.yaml`, and run

```bash
~/temporal-helm$ helm install -f values/values.cassandra.yaml temporaltest . --timeout 900s
```


## Play With It

### Exploring Your Cluster

As always, you can use your favorite kubernetes tools ([k9s](https://github.com/derailed/k9s), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), etc.) to interact with your cluster.

```bash
$ kubectl get svc 
NAME                                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                        AGE
...
temporaltest-admintools                ClusterIP   172.20.237.59    <none>        22/TCP                                         15m
temporaltest-frontend-headless         ClusterIP   None             <none>        7233/TCP,9090/TCP                              15m
temporaltest-history-headless          ClusterIP   None             <none>        7934/TCP,9090/TCP                              15m
temporaltest-matching-headless         ClusterIP   None             <none>        7935/TCP,9090/TCP                              15m
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

You can also shell into `admin-tools` container via [k9s](https://github.com/derailed/k9s) or by running

```
$ kubectl exec -it services/temporaltest-admintools /bin/bash
bash-5.0#
```

and run Temporal CLI from there:

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

### Forwarding Your Machine's Local Port

You can also expose your instance's front end port on your local machine:

```
$ kubectl port-forward services/temporaltest-frontend-headless 7233:7233 
Forwarding from 127.0.0.1:7233 -> 7233
Forwarding from [::1]:7233 -> 7233
```

and, from a separate window, use the local port to access the service.


### Exploring Metrics via Grafana

By default, the full "Batteries Included" configuration comes with a few Grafana dashboards.

To access those dashboards, follow the following steps:

1. Extract Grafana's `admin` password from your installation:

```
$ kubectl get secret --namespace default temporaltest-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

t7EqZQpiB6BztZV321dEDppXbeisdpiEAMgnu6yy%
```

2. Setup port forwarding, so you can access Grafana from your host:

```
$ kubectl port-forward services/temporaltest-grafana 8081:80
Forwarding from 127.0.0.1:8081 -> 3000
Forwarding from [::1]:8081 -> 3000
...
```

3. Navigate to the forwarded Grafana port in your browser (http://localhost:8081/), login as `admin` (using the password from step 1), and click on the "Home" button (upper left corner) to see available dashboards.

### Updating dynamic config
By default dynamic config is empty, if you want to override some properties for your cluster, you should:
1. Create a yaml file with your config (for example dc.yaml).
2. Populate it with some values under server.dynamicConfig prefix (use the sample provided at `values/values.dynamic_config.yaml` as a starting point)
3. Install or upgrade your helm configuration:
```bash
$ helm install -f values/values.dynamic_config.yaml temporaltest . --timeout 900s
```


## Uninstalling

Note: in this example chart, uninstalling a Temporal instance also removes all the data that might have been created during its  lifetime.

```bash
~/temporal-helm $ helm uninstall temporaltest
```

# Acknowledgements

Many thanks to [Banzai Cloud](https://github.com/banzaicloud) whose [Cadence Helm Charts](https://github.com/banzaicloud/banzai-charts/tree/master/cadence) heavily inspired this work.


## License
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Ftemporalio%2Ftemporal-helm-charts?ref=badge_large)
