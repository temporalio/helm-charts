# Temporal Proxy

A Helm chart for the [Temporal Proxy](https://github.com/temporalio/temporal-proxy), which handles routing between
clusters, namespace translation, encryption, and more.

The chart deploys the proxy as a single Deployment fronted by a ClusterIP Service, with its runtime configuration
supplied through a ConfigMap.

> This chart is in alpha. The configuration surface and defaults may change between releases.

## Installation

The chart is published to the Temporal Helm repo at `https://go.temporal.io/helm-charts`.

Because releases are currently pre-release (alpha) versions, Helm will not select them unless you opt in with `--devel`
or pin an explicit `--version`:

```bash
# Install the latest pre-release
helm install temporal-proxy temporal-proxy \
  --repo https://go.temporal.io/helm-charts \
  --devel

# Or pin a specific version
helm install temporal-proxy temporal-proxy \
  --repo https://go.temporal.io/helm-charts \
  --version 0.1.0-alpha1
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
