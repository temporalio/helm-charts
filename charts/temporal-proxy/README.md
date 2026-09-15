# Temporal Proxy

A Helm chart for the [Temporal Proxy](https://github.com/temporalio/temporal-proxy), which handles routing between
clusters, namespace translation, encryption, and more.

The chart deploys the proxy as a single Deployment fronted by a ClusterIP Service, with its runtime configuration
supplied through a ConfigMap.

With a plaintext gateway the default probes are native gRPC probes, which need Kubernetes 1.27 or newer. See
[Health checks](#health-checks) for the alternatives on older clusters.

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

## Health checks

The gateway serves gRPC and has no HTTP handler, so an `httpGet` probe against it can never pass: the kubelet's prober
speaks HTTP/1.1 and gets a protocol error, and a request forced onto HTTP/2 gets `415 invalid gRPC request
content-type`. The probes in `values.yaml` therefore carry timings only, and the chart supplies the handler:

| Gateway | Handler | Why |
| --- | --- | --- |
| plaintext (default) | `grpc` | Checks the proxy's [gRPC health service](https://github.com/grpc/grpc/blob/master/doc/health-checking.md). Needs Kubernetes 1.27, where native gRPC probes went GA. |
| TLS (`config.tls` set) | `tcpSocket` | The kubelet's `grpc` probe dials plaintext and cannot do TLS ([kubernetes/enhancements#4939](https://github.com/kubernetes/enhancements/issues/4939)), so it would never connect. |

Only the gateway listener matters here; an upstream's own `tls` block does not change how the kubelet reaches the pod.

A `grpc` probe takes a numeric port and cannot reference a named container port the way `httpGet` can, so the chart
fills an unset `grpc.port` in from `service.port`. Leaving `grpc.service` unset probes the empty service name, which
the proxy reports process-wide health under; set it to a proto service full name to probe a single service. Note the
proxy only answers for a service it forwards, so naming one left out of `config.allowedServices` fails the probe.

### What each probe is for

- **`livenessProbe`** is deliberately dumb. A restart only fixes process-local faults, so it reports whether the gateway
  is still serving and nothing about the upstream. Wiring upstream health into it turns one upstream blip into a
  fleet-wide restart, where every replica drops its connection pool and caches at the moment the upstream is recovering.
- **`readinessProbe`** gates traffic and rollouts. `timeoutSeconds` is raised off the Kubernetes default of 1s on both,
  which is shorter than a GC pause or a CPU-throttled moment; a probe that times out counts as a failure.

There is no `startupProbe`. The proxy binds the gateway only once its upstream connections are ready, and that whole
sequence is bounded by the fx start timeout — 15s by default — after which the process exits rather than starting
slowly. `failureThreshold: 4` at `periodSeconds: 15` already tolerates several times that, so a `startupProbe` would
gate a boot that cannot outlast it. If you tighten `livenessProbe` below the boot ceiling (for example
`periodSeconds: 5` with `failureThreshold: 2`, to catch a wedged process in 10s), add one then — otherwise liveness
will start killing containers mid-boot:

```yaml
startupProbe:
  periodSeconds: 2
  failureThreshold: 30
```

### Overriding the handler

Naming any handler replaces the default. The chart's defaults carry no handler key, so there is nothing left behind to
merge with yours — a probe with two handlers would be rejected by the API server.

The strongest option for a TLS gateway, or for a cluster older than 1.27, is an `exec` probe running
[`grpc-health-probe`](https://github.com/grpc-ecosystem/grpc-health-probe), which does support TLS. It has to be added
to the image, since the published one contains only the proxy binary:

```yaml
livenessProbe:
  exec:
    command: ["/bin/grpc_health_probe", "-addr=:8443", "-tls", "-tls-ca-cert=/etc/temporal-proxy/certs/gateway/ca.crt"]
```

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
