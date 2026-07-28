# Temporal Proxy

A Helm chart for the [Temporal Proxy](https://github.com/temporalio/temporal-proxy), which handles routing between
clusters, namespace translation, encryption, and more.

The chart deploys the proxy as a single Deployment fronted by a ClusterIP Service, with its runtime configuration
supplied through a ConfigMap.

## Installation

The chart is published to the Temporal Helm repo at `https://go.temporal.io/helm-charts`.

```bash
# Install the latest release
helm install temporal-proxy temporal-proxy \
  --repo https://go.temporal.io/helm-charts

# Or pin a specific version
helm install temporal-proxy temporal-proxy \
  --repo https://go.temporal.io/helm-charts \
  --version 0.1.0
```

To install from a local checkout of this repo instead (useful when testing chart changes), run the following from the
repo root:

```bash
helm install temporal-proxy ./charts/temporal-proxy
```

## Configuration

The proxy's runtime configuration is set under `config` in `values.yaml` and rendered into a ConfigMap mounted at
`/etc/temporal-proxy/config.yaml`. Values are treated as templates, so they can reference other values. See
[`values.yaml`](./values.yaml) for the full set of options and their defaults.
