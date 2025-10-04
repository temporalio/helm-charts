# temporal

![Version: 0.60.0](https://img.shields.io/badge/Version-0.60.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.27.2](https://img.shields.io/badge/AppVersion-1.27.2-informational?style=flat-square)

Temporal is a distributed, scalable, durable, and highly available orchestration engine to execute asynchronous long-running business logic in a scalable and resilient way.

**Homepage:** <https://temporal.io/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| temporalio |  | <https://temporal.io/> |

## Source Code

* <https://github.com/temporalio/temporal>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.helm.sh/incubator | cassandra | 0.14.3 |
| https://grafana.github.io/helm-charts | grafana | 8.0.2 |
| https://helm.elastic.co | elasticsearch | 7.17.3 |
| https://prometheus-community.github.io/helm-charts | prometheus | 25.22.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalAnnotations | object | `{}` |  |
| additionalLabels | object | `{}` |  |
| additionalSecrets | list | `[]` |  |
| admintools.additionalEnv | list | `[]` |  |
| admintools.additionalEnvSecretName | string | `""` |  |
| admintools.additionalInitContainers | list | `[]` |  |
| admintools.additionalVolumeMounts | list | `[]` |  |
| admintools.additionalVolumes | list | `[]` |  |
| admintools.affinity | object | `{}` |  |
| admintools.containerSecurityContext | object | `{}` |  |
| admintools.deploymentAnnotations | object | `{}` |  |
| admintools.deploymentLabels | object | `{}` |  |
| admintools.enabled | bool | `true` |  |
| admintools.image.pullPolicy | string | `"IfNotPresent"` |  |
| admintools.image.repository | string | `"temporalio/admin-tools"` |  |
| admintools.image.tag | string | `"1.27.2-tctl-1.18.2-cli-1.3.0"` |  |
| admintools.nodeSelector | object | `{}` |  |
| admintools.podAnnotations | object | `{}` |  |
| admintools.podDisruptionBudget | object | `{}` |  |
| admintools.podLabels | object | `{}` |  |
| admintools.resources | object | `{}` |  |
| admintools.securityContext | object | `{}` |  |
| admintools.service.annotations | object | `{}` |  |
| admintools.service.port | int | `22` |  |
| admintools.service.type | string | `"ClusterIP"` |  |
| admintools.tolerations | list | `[]` |  |
| cassandra.config.cluster_size | int | `3` |  |
| cassandra.config.heap_new_size | string | `"128M"` |  |
| cassandra.config.max_heap_size | string | `"512M"` |  |
| cassandra.config.num_tokens | int | `4` |  |
| cassandra.config.ports.cql | int | `9042` |  |
| cassandra.config.seed_size | int | `0` |  |
| cassandra.enabled | bool | `true` |  |
| cassandra.image.pullPolicy | string | `"IfNotPresent"` |  |
| cassandra.image.repo | string | `"cassandra"` |  |
| cassandra.image.tag | string | `"3.11.3"` |  |
| cassandra.persistence.enabled | bool | `false` |  |
| cassandra.service.type | string | `"ClusterIP"` |  |
| certificates.certificate.isCA | bool | `false` |  |
| certificates.certificate.name | string | `"temporal-cert"` |  |
| certificates.certificate.privateKey.algorithm | string | `"RSA"` |  |
| certificates.certificate.privateKey.rotationPolicy | string | `"Always"` |  |
| certificates.certificate.privateKey.size | int | `2048` |  |
| certificates.certificate.secret.name | string | `"temporal-tls-certs"` |  |
| certificates.enabled | bool | `false` |  |
| certificates.issuer.name | string | `"temporal-issuer"` |  |
| certificates.issuer.secretName | string | `"tls-certs"` |  |
| debug | bool | `false` |  |
| elasticsearch.enabled | bool | `true` |  |
| elasticsearch.host | string | `"elasticsearch-master-headless"` |  |
| elasticsearch.imageTag | string | `"7.17.3"` |  |
| elasticsearch.logLevel | string | `"error"` |  |
| elasticsearch.password | string | `""` |  |
| elasticsearch.persistence.enabled | bool | `false` |  |
| elasticsearch.port | int | `9200` |  |
| elasticsearch.replicas | int | `3` |  |
| elasticsearch.scheme | string | `"http"` |  |
| elasticsearch.username | string | `""` |  |
| elasticsearch.version | string | `"v7"` |  |
| elasticsearch.visibilityIndex | string | `"temporal_visibility_v1_dev"` |  |
| fullnameOverride | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".apiVersion | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].disableDeletion | bool | `false` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].editable | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].folder | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].name | string | `"default"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].options.path | string | `"/var/lib/grafana/dashboards/default"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].orgId | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].type | string | `"file"` |  |
| grafana.dashboards.default.misc-advanced-visibility-specific-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.misc-advanced-visibility-specific-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/advanced-visibility-specific.json"` |  |
| grafana.dashboards.default.misc-clustermonitoring-kubernetes-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.misc-clustermonitoring-kubernetes-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/clustermonitoring-kubernetes.json"` |  |
| grafana.dashboards.default.misc-frontend-service-specific-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.misc-frontend-service-specific-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/frontend-service-specific.json"` |  |
| grafana.dashboards.default.misc-history-service-specific-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.misc-history-service-specific-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/history-service-specific.json"` |  |
| grafana.dashboards.default.misc-matching-service-specific-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.misc-matching-service-specific-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/matching-service-specific.json"` |  |
| grafana.dashboards.default.misc-worker-service-specific-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.misc-worker-service-specific-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/misc/worker-service-specific.json"` |  |
| grafana.dashboards.default.sdk-general-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.sdk-general-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/sdk/sdk-general.json"` |  |
| grafana.dashboards.default.server-general-github.datasource | string | `"TemporalMetrics"` |  |
| grafana.dashboards.default.server-general-github.url | string | `"https://raw.githubusercontent.com/temporalio/dashboards/helm/server/server-general.json"` |  |
| grafana.datasources."datasources.yaml".apiVersion | int | `1` |  |
| grafana.datasources."datasources.yaml".datasources[0].access | string | `"proxy"` |  |
| grafana.datasources."datasources.yaml".datasources[0].isDefault | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[0].name | string | `"TemporalMetrics"` |  |
| grafana.datasources."datasources.yaml".datasources[0].type | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].url | string | `"http://{{ .Release.Name }}-prometheus-server"` |  |
| grafana.enabled | bool | `true` |  |
| grafana.rbac.create | bool | `false` |  |
| grafana.rbac.namespaced | bool | `true` |  |
| grafana.rbac.pspEnabled | bool | `false` |  |
| grafana.replicas | int | `1` |  |
| grafana.testFramework.enabled | bool | `false` |  |
| imagePullSecrets | object | `{}` |  |
| mysql.enabled | bool | `false` |  |
| nameOverride | string | `""` |  |
| prometheus.enabled | bool | `true` |  |
| prometheus.nodeExporter.enabled | bool | `false` |  |
| schema.containerSecurityContext | object | `{}` |  |
| schema.createDatabase.enabled | bool | `true` |  |
| schema.podAnnotations | object | `{}` |  |
| schema.podLabels | object | `{}` |  |
| schema.resources | object | `{}` |  |
| schema.securityContext | object | `{}` |  |
| schema.setup.backoffLimit | int | `100` |  |
| schema.setup.enabled | bool | `true` |  |
| schema.update.backoffLimit | int | `100` |  |
| schema.update.enabled | bool | `true` |  |
| server.additionalEnv | list | `[]` |  |
| server.additionalInitContainers | list | `[]` |  |
| server.additionalVolumeMounts | list | `[]` |  |
| server.additionalVolumes | list | `[]` |  |
| server.affinity | object | `{}` |  |
| server.config.logLevel | string | `"debug,info"` |  |
| server.config.namespaces.create | bool | `false` |  |
| server.config.namespaces.namespace[0].name | string | `"default"` |  |
| server.config.namespaces.namespace[0].retention | string | `"3d"` |  |
| server.config.numHistoryShards | int | `512` |  |
| server.config.persistence.additionalStores | object | `{}` |  |
| server.config.persistence.default.cassandra.consistency.default.consistency | string | `"local_quorum"` |  |
| server.config.persistence.default.cassandra.consistency.default.serialConsistency | string | `"local_serial"` |  |
| server.config.persistence.default.cassandra.existingSecret | string | `""` |  |
| server.config.persistence.default.cassandra.hosts | list | `[]` |  |
| server.config.persistence.default.cassandra.keyspace | string | `"temporal"` |  |
| server.config.persistence.default.cassandra.password | string | `"password"` |  |
| server.config.persistence.default.cassandra.replicationFactor | int | `1` |  |
| server.config.persistence.default.cassandra.user | string | `"user"` |  |
| server.config.persistence.default.driver | string | `"cassandra"` |  |
| server.config.persistence.default.sql.database | string | `"temporal"` |  |
| server.config.persistence.default.sql.driver | string | `"mysql8"` |  |
| server.config.persistence.default.sql.existingSecret | string | `""` |  |
| server.config.persistence.default.sql.host | string | `"mysql"` |  |
| server.config.persistence.default.sql.maxConnLifetime | string | `"1h"` |  |
| server.config.persistence.default.sql.maxConns | int | `20` |  |
| server.config.persistence.default.sql.maxIdleConns | int | `20` |  |
| server.config.persistence.default.sql.password | string | `"temporal"` |  |
| server.config.persistence.default.sql.port | int | `3306` |  |
| server.config.persistence.default.sql.secretName | string | `""` |  |
| server.config.persistence.default.sql.user | string | `"temporal"` |  |
| server.config.persistence.defaultStore | string | `"default"` |  |
| server.config.persistence.visibility.cassandra.consistency.default.consistency | string | `"local_quorum"` |  |
| server.config.persistence.visibility.cassandra.consistency.default.serialConsistency | string | `"local_serial"` |  |
| server.config.persistence.visibility.cassandra.existingSecret | string | `""` |  |
| server.config.persistence.visibility.cassandra.hosts | list | `[]` |  |
| server.config.persistence.visibility.cassandra.keyspace | string | `"temporal_visibility"` |  |
| server.config.persistence.visibility.cassandra.password | string | `"password"` |  |
| server.config.persistence.visibility.cassandra.replicationFactor | int | `1` |  |
| server.config.persistence.visibility.cassandra.user | string | `"user"` |  |
| server.config.persistence.visibility.driver | string | `"cassandra"` |  |
| server.config.persistence.visibility.sql.database | string | `"temporal_visibility"` |  |
| server.config.persistence.visibility.sql.driver | string | `"mysql8"` |  |
| server.config.persistence.visibility.sql.existingSecret | string | `""` |  |
| server.config.persistence.visibility.sql.host | string | `"mysql"` |  |
| server.config.persistence.visibility.sql.maxConnLifetime | string | `"1h"` |  |
| server.config.persistence.visibility.sql.maxConns | int | `20` |  |
| server.config.persistence.visibility.sql.maxIdleConns | int | `20` |  |
| server.config.persistence.visibility.sql.password | string | `"temporal"` |  |
| server.config.persistence.visibility.sql.port | int | `3306` |  |
| server.config.persistence.visibility.sql.secretName | string | `""` |  |
| server.config.persistence.visibility.sql.user | string | `"temporal"` |  |
| server.deploymentAnnotations | object | `{}` |  |
| server.deploymentLabels | object | `{}` |  |
| server.enabled | bool | `true` |  |
| server.frontend.additionalEnv | list | `[]` |  |
| server.frontend.affinity | object | `{}` |  |
| server.frontend.containerSecurityContext | object | `{}` |  |
| server.frontend.deploymentAnnotations | object | `{}` |  |
| server.frontend.deploymentLabels | object | `{}` |  |
| server.frontend.ingress.annotations | object | `{}` |  |
| server.frontend.ingress.enabled | bool | `false` |  |
| server.frontend.ingress.hosts[0] | string | `"/"` |  |
| server.frontend.ingress.tls | list | `[]` |  |
| server.frontend.metrics.annotations.enabled | bool | `true` |  |
| server.frontend.metrics.prometheus | object | `{}` |  |
| server.frontend.metrics.serviceMonitor | object | `{}` |  |
| server.frontend.nodeSelector | object | `{}` |  |
| server.frontend.podAnnotations | object | `{}` |  |
| server.frontend.podDisruptionBudget | object | `{}` |  |
| server.frontend.podLabels | object | `{}` |  |
| server.frontend.resources | object | `{}` |  |
| server.frontend.service.annotations | object | `{}` |  |
| server.frontend.service.httpPort | int | `7243` |  |
| server.frontend.service.membershipPort | int | `6933` |  |
| server.frontend.service.port | int | `7233` |  |
| server.frontend.service.type | string | `"ClusterIP"` |  |
| server.frontend.tolerations | list | `[]` |  |
| server.frontend.topologySpreadConstraints | list | `[]` |  |
| server.history.additionalEnv | list | `[]` |  |
| server.history.additionalEnvSecretName | string | `""` |  |
| server.history.affinity | object | `{}` |  |
| server.history.containerSecurityContext | object | `{}` |  |
| server.history.deploymentAnnotations | object | `{}` |  |
| server.history.deploymentLabels | object | `{}` |  |
| server.history.metrics.annotations.enabled | bool | `true` |  |
| server.history.metrics.prometheus | object | `{}` |  |
| server.history.metrics.serviceMonitor | object | `{}` |  |
| server.history.nodeSelector | object | `{}` |  |
| server.history.podAnnotations | object | `{}` |  |
| server.history.podDisruptionBudget | object | `{}` |  |
| server.history.podLabels | object | `{}` |  |
| server.history.resources | object | `{}` |  |
| server.history.service.membershipPort | int | `6934` |  |
| server.history.service.port | int | `7234` |  |
| server.history.tolerations | list | `[]` |  |
| server.history.topologySpreadConstraints | list | `[]` |  |
| server.image.pullPolicy | string | `"IfNotPresent"` |  |
| server.image.repository | string | `"temporalio/server"` |  |
| server.image.tag | string | `"1.27.2"` |  |
| server.internalFrontend.additionalEnv | list | `[]` |  |
| server.internalFrontend.affinity | object | `{}` |  |
| server.internalFrontend.containerSecurityContext | object | `{}` |  |
| server.internalFrontend.deploymentAnnotations | object | `{}` |  |
| server.internalFrontend.deploymentLabels | object | `{}` |  |
| server.internalFrontend.enabled | bool | `false` |  |
| server.internalFrontend.metrics.annotations.enabled | bool | `true` |  |
| server.internalFrontend.metrics.prometheus | object | `{}` |  |
| server.internalFrontend.metrics.serviceMonitor | object | `{}` |  |
| server.internalFrontend.nodeSelector | object | `{}` |  |
| server.internalFrontend.podAnnotations | object | `{}` |  |
| server.internalFrontend.podDisruptionBudget | object | `{}` |  |
| server.internalFrontend.podLabels | object | `{}` |  |
| server.internalFrontend.resources | object | `{}` |  |
| server.internalFrontend.service.annotations | object | `{}` |  |
| server.internalFrontend.service.httpPort | int | `7246` |  |
| server.internalFrontend.service.membershipPort | int | `6936` |  |
| server.internalFrontend.service.port | int | `7236` |  |
| server.internalFrontend.service.type | string | `"ClusterIP"` |  |
| server.internalFrontend.tolerations | list | `[]` |  |
| server.internalFrontend.topologySpreadConstraints | list | `[]` |  |
| server.matching.additionalEnv | list | `[]` |  |
| server.matching.affinity | object | `{}` |  |
| server.matching.containerSecurityContext | object | `{}` |  |
| server.matching.deploymentAnnotations | object | `{}` |  |
| server.matching.deploymentLabels | object | `{}` |  |
| server.matching.metrics.annotations.enabled | bool | `false` |  |
| server.matching.metrics.prometheus | object | `{}` |  |
| server.matching.metrics.serviceMonitor | object | `{}` |  |
| server.matching.nodeSelector | object | `{}` |  |
| server.matching.podAnnotations | object | `{}` |  |
| server.matching.podDisruptionBudget | object | `{}` |  |
| server.matching.podLabels | object | `{}` |  |
| server.matching.resources | object | `{}` |  |
| server.matching.service.membershipPort | int | `6935` |  |
| server.matching.service.port | int | `7235` |  |
| server.matching.tolerations | list | `[]` |  |
| server.matching.topologySpreadConstraints | list | `[]` |  |
| server.metrics.annotations.enabled | bool | `true` |  |
| server.metrics.excludeTags | object | `{}` |  |
| server.metrics.prefix | string | `nil` |  |
| server.metrics.prometheus.timerType | string | `"histogram"` |  |
| server.metrics.serviceMonitor.additionalLabels | object | `{}` |  |
| server.metrics.serviceMonitor.enabled | bool | `false` |  |
| server.metrics.serviceMonitor.interval | string | `"30s"` |  |
| server.metrics.serviceMonitor.metricRelabelings | list | `[]` |  |
| server.metrics.tags | object | `{}` |  |
| server.nodeSelector | object | `{}` |  |
| server.podAnnotations | object | `{}` |  |
| server.podLabels | object | `{}` |  |
| server.replicaCount | int | `1` |  |
| server.resources | object | `{}` |  |
| server.secretAnnotations | object | `{}` |  |
| server.secretLabels | object | `{}` |  |
| server.securityContext.fsGroup | int | `1000` |  |
| server.securityContext.runAsUser | int | `1000` |  |
| server.tolerations | list | `[]` |  |
| server.worker.additionalEnv | list | `[]` |  |
| server.worker.affinity | object | `{}` |  |
| server.worker.containerSecurityContext | object | `{}` |  |
| server.worker.deploymentAnnotations | object | `{}` |  |
| server.worker.deploymentLabels | object | `{}` |  |
| server.worker.metrics.annotations.enabled | bool | `true` |  |
| server.worker.metrics.prometheus | object | `{}` |  |
| server.worker.metrics.serviceMonitor | object | `{}` |  |
| server.worker.nodeSelector | object | `{}` |  |
| server.worker.podAnnotations | object | `{}` |  |
| server.worker.podDisruptionBudget | object | `{}` |  |
| server.worker.podLabels | object | `{}` |  |
| server.worker.resources | object | `{}` |  |
| server.worker.service.membershipPort | int | `6939` |  |
| server.worker.service.port | int | `7239` |  |
| server.worker.tolerations | list | `[]` |  |
| server.worker.topologySpreadConstraints | list | `[]` |  |
| serviceAccount.create | bool | `false` |  |
| serviceAccount.extraAnnotations | string | `nil` |  |
| serviceAccount.name | string | `nil` |  |
| web.additionalEnv | list | `[]` |  |
| web.additionalEnvSecretName | string | `""` |  |
| web.additionalVolumeMounts | list | `[]` |  |
| web.additionalVolumes | list | `[]` |  |
| web.affinity | object | `{}` |  |
| web.containerSecurityContext | object | `{}` |  |
| web.deploymentAnnotations | object | `{}` |  |
| web.deploymentLabels | object | `{}` |  |
| web.enabled | bool | `true` |  |
| web.image.pullPolicy | string | `"IfNotPresent"` |  |
| web.image.repository | string | `"temporalio/ui"` |  |
| web.image.tag | string | `"2.36.1"` |  |
| web.ingress.annotations | object | `{}` |  |
| web.ingress.enabled | bool | `false` |  |
| web.ingress.hosts[0] | string | `"/"` |  |
| web.ingress.tls | list | `[]` |  |
| web.nodeSelector | object | `{}` |  |
| web.podAnnotations | object | `{}` |  |
| web.podDisruptionBudget | object | `{}` |  |
| web.podLabels | object | `{}` |  |
| web.replicaCount | int | `1` |  |
| web.resources | object | `{}` |  |
| web.securityContext | object | `{}` |  |
| web.service.annotations | object | `{}` |  |
| web.service.port | int | `8080` |  |
| web.service.type | string | `"ClusterIP"` |  |
| web.tolerations | list | `[]` |  |
| web.topologySpreadConstraints | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
