{{/*
Fail with a descriptive error if any deprecated or removed values are set.
Call this from a top-level template so it is always evaluated during rendering.
*/}}
{{- define "temporal.validateDeprecations" -}}

{{/* ------------------------------------------------------------------ */}}
{{/* Removed sub-chart top-level keys                                    */}}
{{/* ------------------------------------------------------------------ */}}
{{- if .Values.cassandra -}}
  {{- fail "'cassandra' is no longer a supported top-level key. The Cassandra sub-chart was removed in v1.0.0-rc.2. Configure Cassandra under server.config.persistence.datastores. See UPGRADING.md." -}}
{{- end -}}

{{- if .Values.elasticsearch -}}
  {{- fail "'elasticsearch' is no longer a supported top-level key. The Elasticsearch sub-chart was removed in v1.0.0-rc.2. Configure Elasticsearch under server.config.persistence.datastores. See UPGRADING.md." -}}
{{- end -}}

{{- if .Values.prometheus -}}
  {{- fail "'prometheus' is no longer a supported top-level key. The Prometheus sub-chart was removed in v1.0.0-rc.2. Configure scraping via server.metrics.annotations or server.metrics.serviceMonitor. See UPGRADING.md." -}}
{{- end -}}

{{- if .Values.grafana -}}
  {{- fail "'grafana' is no longer a supported top-level key. The Grafana sub-chart was removed in v1.0.0-rc.2. Import dashboards from https://github.com/temporalio/dashboards instead. See UPGRADING.md." -}}
{{- end -}}

{{- if .Values.mysql -}}
  {{- fail "'mysql' is no longer a supported top-level key. The MySQL sub-chart was removed in v1.0.0-rc.2. Configure MySQL under server.config.persistence.datastores. See UPGRADING.md." -}}
{{- end -}}

{{- if .Values.postgresql -}}
  {{- fail "'postgresql' is no longer a supported top-level key. The PostgreSQL sub-chart was removed in v1.0.0-rc.2. Configure PostgreSQL under server.config.persistence.datastores. See UPGRADING.md." -}}
{{- end -}}

{{/* ------------------------------------------------------------------ */}}
{{/* Legacy persistence configuration format (pre-v1.0.0-rc.2)          */}}
{{/* Previously stores were configured directly under                    */}}
{{/* server.config.persistence.{default,visibility}; they now live under */}}
{{/* server.config.persistence.datastores.{name}.                        */}}
{{/* ------------------------------------------------------------------ */}}
{{- $legacyDefault := .Values.server.config.persistence.default -}}
{{- if and $legacyDefault (kindIs "map" $legacyDefault) -}}
  {{- fail "'server.config.persistence.default' is no longer supported. Migrate to 'server.config.persistence.datastores.<name>'. See UPGRADING.md." -}}
{{- end -}}

{{- $legacyVisibility := .Values.server.config.persistence.visibility -}}
{{- if and $legacyVisibility (kindIs "map" $legacyVisibility) -}}
  {{- fail "'server.config.persistence.visibility' is no longer supported. Migrate to 'server.config.persistence.datastores.<name>'. See UPGRADING.md." -}}
{{- end -}}

{{/* ------------------------------------------------------------------ */}}
{{/* Cassandra as visibility store is no longer supported                */}}
{{/* ------------------------------------------------------------------ */}}
{{- $visibilityStoreName := .Values.server.config.persistence.visibilityStore | default "" -}}
{{- if $visibilityStoreName -}}
  {{- $datastores := .Values.server.config.persistence.datastores | default dict -}}
  {{- $visibilityDatastore := index $datastores $visibilityStoreName | default dict -}}
  {{- if hasKey $visibilityDatastore "cassandra" -}}
    {{- fail (printf "Cassandra cannot be used as the visibility store (store: %q). Use SQL (MySQL/PostgreSQL) or Elasticsearch instead." $visibilityStoreName) -}}
  {{- end -}}
{{- end -}}

{{/* ------------------------------------------------------------------ */}}
{{/* Legacy schema job top-level toggles                                 */}}
{{/* createDatabase, setup, and update are now controlled per-store via  */}}
{{/* server.config.persistence.datastores.<name>.{sql,cassandra}.        */}}
{{/* createDatabase and manageSchema respectively.                        */}}
{{/* ------------------------------------------------------------------ */}}
{{- if .Values.schema.createDatabase -}}
  {{- fail "'schema.createDatabase' is no longer supported. Set 'createDatabase' on each datastore under server.config.persistence.datastores.<name>.{sql,cassandra}. See UPGRADING.md." -}}
{{- end -}}

{{- if .Values.schema.setup -}}
  {{- fail "'schema.setup' is no longer supported. Set 'manageSchema: true' on each datastore under server.config.persistence.datastores.<name>.{sql,cassandra,elasticsearch}. See UPGRADING.md." -}}
{{- end -}}

{{- if .Values.schema.update -}}
  {{- fail "'schema.update' is no longer supported. Set 'manageSchema: true' on each datastore under server.config.persistence.datastores.<name>.{sql,cassandra,elasticsearch}. See UPGRADING.md." -}}
{{- end -}}

{{/* ------------------------------------------------------------------ */}}
{{/* imagePullSecrets format changed from map to array in v1.0.0-rc.2   */}}
{{/* ------------------------------------------------------------------ */}}
{{- if kindIs "map" .Values.imagePullSecrets -}}
  {{- fail "'imagePullSecrets' must be a list, not a map. Change 'imagePullSecrets: {}' to 'imagePullSecrets: []'. See UPGRADING.md." -}}
{{- end -}}

{{- end -}}
