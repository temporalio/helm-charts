# Temporal

Temporal is a distributed, scalable, durable, and highly available orchestration engine to execute asynchronous long-running business logic in a scalable and resilient way.

This repo contains a basic [Helm](https://helm.sh) chart that allows you to install temporal to a kubernetes cluster, and to play with it.

The version of Helm chart is provided for demo purposes and provides not intended to be used in a production systems.

# Deploying Temporal Service to a Kubernetes Cluster

## Prerequisites

This sequence assumes that your system is configured to access a kubernetes cluster (e. g. [AWS EKS](https://aws.amazon.com/eks/), or [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)), and that your machine has [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and [Helm v3.1.x](https://helm.sh) installed and able to access your cluster.

## Install an Instance of Temporal to Your k8s Cluster

Download Helm dependencies:

```bash
~/temporal-helm$ helm dependencies update
```

Install an instance of Temporal to your kubernetes cluster:

```bash
~/temporal-helm$ helm install temporaltest . --timeout 900s
```

## Play With It

### Exploring your cluster

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

### Running temporal CLI from the admin tools container

You can also drop into `admin-tools` container via k9s and run Temporal CLI from there:

```
bash-5.0# tctl --domain nonesuch domain desc
Error: Domain nonesuch does not exist.
Error Details: Domain nonesuch does not exist.
```
```
bash-5.0# tctl --domain nonesuch domain re
Domain nonesuch successfully registered.
```
```
bash-5.0# tctl --domain nonesuch domain desc
Name: nonesuch
UUID: 465bb575-8c01-43f8-a67d-d676e1ae5eae
Description:
OwnerEmail:
DomainData: map[string]string(nil)
Status: DomainStatusRegistered
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


## Uninstalling

Note: in this example chart, uninstalling a Temporal instance also removes all the data that might have been created during its  lifetime.

```bash
~/temporal-helm $ helm uninstall temporaltest
```

# Acknowledgements

Many thanks to [Banzai Cloud](https://github.com/banzaicloud) whose [Cadence Helm Charts](https://github.com/banzaicloud/banzai-charts/tree/master/cadence) heavily inspired this work.
