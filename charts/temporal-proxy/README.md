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
`/etc/temporal-proxy/config.yaml`. See [`values.yaml`](./values.yaml) for the full set of options and their defaults.

## Supplying configuration

### Inline config

`config` mirrors the [temporal-proxy config schema](https://github.com/temporalio/temporal-proxy) directly; whatever you
put under `config` in `values.yaml` is what ends up in the ConfigMap. The chart does not run this through Helm's `tpl`
function, so the proxy's own per-request templates (for example `{{ .RemoteNamespace }}` in an upstream `hostPort`) pass
through untouched and are evaluated by the proxy itself at request time, not by Helm.

If `config.hostPort` (the gateway's listen address) is left unset, it defaults to `:<service.port>`.

```yaml
config:
  routing:
    default: default
  upstreams:
    - name: default
      hostPort: localhost:7233
```

### Secret-aware credentials

Two fields accept either a plain string or a `secretKeyRef` object, so the ConfigMap never has to hold a secret in
plaintext:

- `upstreams[].credentials.static.apiKey`
- `auth.staticToken.token`

When you use the `secretKeyRef` form, the chart adds an environment variable to the proxy container sourced from that
Secret, and rewrites the config value to `${VAR}` so the proxy substitutes it at startup. The generated variable names
are:

- `TP_UPSTREAM_<NAME>_API_KEY` for `upstreams[].credentials.static.apiKey`, where `<NAME>` is the upstream's `name`
  upper-cased (non-alphanumeric characters become `_`)
- `TP_AUTH_STATIC_TOKEN` for `auth.staticToken.token`

```yaml
config:
  upstreams:
    - name: cloud
      hostPort: localhost:7233
      credentials:
        static:
          apiKey:
            secretKeyRef:
              name: temporal-cloud
              key: api-key
```

renders a ConfigMap with `apiKey: ${TP_UPSTREAM_CLOUD_API_KEY}` and adds a matching `TP_UPSTREAM_CLOUD_API_KEY`
environment variable to the container, backed by the `temporal-cloud`/`api-key` Secret.

### TLS

The gateway's `config.tls` block and each `upstreams[].tls` block accept a `secretName`. When set, the chart mounts that
Secret at `/etc/temporal-proxy/certs/gateway` (for `config.tls`) or `/etc/temporal-proxy/certs/upstream-<name>` (for an
upstream's `tls`), and sets:

- `cert` to `<mount>/tls.crt` by default, or `<mount>/<certKey>` if `certKey` is set
- `key` to `<mount>/tls.key` by default, or `<mount>/<keyKey>` if `keyKey` is set
- `ca` only when `caKey` is set, to `<mount>/<caKey>`

`ca` is opt-in: it is only written when `caKey` is provided. Setting a `ca` on the gateway's `config.tls` enables
mTLS/client-cert enforcement for inbound connections, so only set it when you intend to require client certificates.

Note: keep upstream `name` values DNS-safe (lowercase alphanumeric characters and `-`), since they are used to build the
generated volume name (`certs-upstream-<name>`).

This mounting scheme lines up with how [cert-manager](https://cert-manager.io/) issues Secrets (a `tls.crt`/`tls.key`
pair, plus `ca.crt` when using `Certificate.spec.additionalOutputFormats` or a CA issuer), but cert-manager is not
required; any Secret with the right keys works, and `certKey`/`keyKey`/`caKey` let you point at whatever keys your
Secret actually uses.

```yaml
config:
  tls:
    secretName: temporal-proxy-server-tls
  upstreams:
    - name: cloud
      hostPort: "{{ .RemoteNamespace }}.tmprl.cloud:7233"
      tls:
        secretName: temporal-cloud-client-tls
        caKey: ca.crt
```

If you'd rather manage certificate files yourself, skip `secretName` and use the chart's generic `volumes` /
`volumeMounts` values to mount them at whatever path you set `cert`/`key`/`ca` to.

### env / envFrom passthrough

`env` and `envFrom` on the Deployment let you supply arbitrary environment variables the config references with `${VAR}`
syntax, such as a Temporal Cloud account id or KMS credentials. Chart-generated secret env vars (from the secret-aware
fields above) are merged in automatically alongside anything you set in `.Values.env`.

```yaml
env:
  - name: TEMPORAL_ACCOUNT
    value: a1b2c

envFrom:
  - secretRef:
      name: proxy-kms-credentials
```

### Full example: Temporal Cloud

Putting the pieces above together, an upstream routing to Temporal Cloud with the API key sourced from a Secret and the
namespace derived from the proxy's own per-request template:

```yaml
env:
  - name: TEMPORAL_ACCOUNT
    value: a1b2c
  - name: TEMPORAL_NAMESPACE
    value: testing

extraObjects:
  # Typically not created like this to avoid putting your API key in plain text.
  # Demo purposes only.
  - |
    apiVersion: v1
    kind: Secret
    metadata:
      name: temporal-cloud
    type: Opaque
    stringData:
      api-key: <YOUR_API_KEY>

config:
  routing:
    default: cloud
    system: system
  upstreams:
    - name: cloud
      hostPort: "{{ .RemoteNamespace }}.tmprl.cloud:7233"
      namespaces:
        rules:
          suffix: .$TEMPORAL_ACCOUNT
      tls: {}
      credentials:
        static:
          apiKey:
            secretKeyRef:
              name: temporal-cloud
              key: api-key
    - name: system
      hostPort: "$TEMPORAL_NAMESPACE.$TEMPORAL_ACCOUNT.tmprl.cloud:7233"
      tls: {}
      credentials:
        static:
          apiKey:
            secretKeyRef:
              name: temporal-cloud
              key: api-key
```
