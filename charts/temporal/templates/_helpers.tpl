{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "temporal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "temporal.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "temporal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account
*/}}
{{- define "temporal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "temporal.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Define the service account as needed
*/}}
{{- define "temporal.serviceAccount" -}}
serviceAccountName: {{ include "temporal.serviceAccountName" . }}
{{- end -}}

{{/*
Create a default fully qualified component name from the full app name and a component name.
We truncate the full name at 63 - 1 (last dash) - len(component name) chars because some Kubernetes name fields are limited to this (by the DNS naming spec)
and we want to make sure that the component is included in the name.
*/}}
{{- define "temporal.componentname" -}}
{{- $global := index . 0 -}}
{{- $component := index . 1 | trimPrefix "-" -}}
{{- printf "%s-%s" (include "temporal.fullname" $global | trunc (sub 62 (len $component) | int) | trimSuffix "-" ) $component | trimSuffix "-" -}}
{{- end -}}

{{/*
Frontend service address as a short in-cluster name (host:port).
*/}}
{{- define "temporal.frontendAddress" -}}
{{- printf "%s-frontend:%d" (include "temporal.fullname" .) (.Values.server.frontend.service.port | int) -}}
{{- end -}}

{{/*
Frontend service address as a fully-qualified cluster DNS name (host.namespace.svc:port).
*/}}
{{- define "temporal.frontendAddress.fqdn" -}}
{{- printf "%s-frontend.%s.svc:%d" (include "temporal.fullname" .) .Release.Namespace (.Values.server.frontend.service.port | int) -}}
{{- end -}}

{{/*
Internal-frontend service address as a short in-cluster name (host:port).
*/}}
{{- define "temporal.internalFrontendAddress" -}}
{{- $internalFrontend := index .Values.server "internal-frontend" -}}
{{- printf "%s-internal-frontend:%d" (include "temporal.fullname" .) ($internalFrontend.service.port | int) -}}
{{- end -}}

{{/*
Internal-frontend service address as a fully-qualified cluster DNS name (host.namespace.svc:port).
*/}}
{{- define "temporal.internalFrontendAddress.fqdn" -}}
{{- $internalFrontend := index .Values.server "internal-frontend" -}}
{{- printf "%s-internal-frontend.%s.svc:%d" (include "temporal.fullname" .) .Release.Namespace ($internalFrontend.service.port | int) -}}
{{- end -}}

{{/*
Define the AppVersion
*/}}
{{- define "temporal.appVersion" -}}
{{- if .Chart.AppVersion -}}
{{ .Chart.AppVersion | replace "+" "_" | quote }}
{{- else -}}
{{ include "temporal.chart" $ }}
{{- end -}}
{{- end -}}

{{/*
Create the annotations for all resources
*/}}
{{- define "temporal.resourceAnnotations" -}}
{{- $global := index . 0 -}}
{{- $scope := index . 1 -}}
{{- $resourceType := index . 2 -}}
{{- $component := "server" -}}
{{- if (or (eq $scope "admintools") (eq $scope "web")) -}}
{{- $component = $scope -}}
{{- end -}}
{{- with $resourceType -}}
{{- $resourceTypeKey := printf "%sAnnotations" . -}}
{{- $componentAnnotations := (index $global.Values $component $resourceTypeKey) -}}
{{- $scopeAnnotations := dict -}}
{{- if hasKey (index $global.Values $component) $scope -}}
{{- $scopeAnnotations = (index $global.Values $component $scope $resourceTypeKey) -}}
{{- end -}}
{{- $resourceAnnotations := merge $scopeAnnotations $componentAnnotations -}}
{{- range $annotation_name, $annotation_value := $resourceAnnotations }}
{{ $annotation_name }}: {{ $annotation_value | quote }}
{{- end -}}
{{- end -}}
{{- range $annotation_name, $annotation_value := $global.Values.additionalAnnotations }}
{{ $annotation_name }}: {{ $annotation_value | quote }}
{{- end -}}
{{- end -}}

{{/*
Create the labels for all resources
*/}}
{{- define "temporal.resourceLabels" -}}
{{- $global := index . 0 -}}
{{- $scope := index . 1 -}}
{{- $resourceType := index . 2 -}}
{{- $component := "server" -}}
{{- if (or (eq $scope "admintools") (eq $scope "web")) -}}
{{- $component = $scope -}}
{{- end -}}
{{- with $scope -}}
app.kubernetes.io/component: {{ . }}
{{ end -}}
app.kubernetes.io/name: {{ include "temporal.name" $global }}
helm.sh/chart: {{ include "temporal.chart" $global }}
app.kubernetes.io/managed-by: {{ index $global "Release" "Service" }}
app.kubernetes.io/instance: {{ index $global "Release" "Name" }}
app.kubernetes.io/version: {{ include "temporal.appVersion" $global }}
app.kubernetes.io/part-of: {{ $global.Chart.Name }}
{{- with $resourceType -}}
{{- $resourceTypeKey := printf "%sLabels" . -}}
{{- $componentLabels := (index $global.Values $component $resourceTypeKey) -}}
{{- $scopeLabels := dict -}}
{{- if hasKey (index $global.Values $component) $scope -}}
{{- $scopeLabels = (index $global.Values $component $scope $resourceTypeKey) -}}
{{- end -}}
{{- $resourceLabels := merge $scopeLabels $componentLabels -}}
{{- range $label_name, $label_value := $resourceLabels }}
{{ $label_name}}: {{ $label_value | quote }}
{{- end -}}
{{- end -}}
{{- range $label_name, $label_value := $global.Values.additionalLabels }}
{{ $label_name }}: {{ $label_value | quote }}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.filterConfig" -}}
{{- $config := deepCopy . -}}
{{- $defaultStore := $config.defaultStore -}}
{{- $visibilityStore := $config.visibilityStore -}}
{{- $secondaryVisibilityStore := $config.secondaryVisibilityStore | default "" -}}
{{- $patchedDatastores := dict -}}
{{- range $name, $ds := $config.datastores -}}
  {{- $dsCopy := deepCopy $ds -}}
  {{- range $storeType := list "sql" "cassandra" "elasticsearch" -}}
    {{- if hasKey $dsCopy $storeType -}}
      {{- $storeConfig := get $dsCopy $storeType -}}
      {{- if or (hasKey $storeConfig "password") (hasKey $storeConfig "existingSecret") -}}
        {{- if eq $name $defaultStore -}}
          {{- $_ := set $storeConfig "password" "__ENV_TEMPORAL_DEFAULT_STORE_PASSWORD__" -}}
        {{- else if eq $name $visibilityStore -}}
          {{- $_ := set $storeConfig "password" "__ENV_TEMPORAL_VISIBILITY_STORE_PASSWORD__" -}}
        {{- else if eq $name $secondaryVisibilityStore -}}
          {{- $_ := set $storeConfig "password" "__ENV_TEMPORAL_SECONDARY_VISIBILITY_STORE_PASSWORD__" -}}
        {{- else -}}
          {{- $_ := unset $storeConfig "password" -}}
        {{- end -}}
      {{- end -}}
      {{- $_ := set $dsCopy $storeType (omit $storeConfig "existingSecret" "secretKey" "createDatabase" "manageSchema") -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set $patchedDatastores $name $dsCopy -}}
{{- end -}}
{{- $_ := set $config "datastores" $patchedDatastores -}}
{{- regexReplaceAll "__ENV_(TEMPORAL_.+)__" ($config | toYaml) "{{ env \"$1\" | quote }}" -}}
{{- end -}}

{{- define "temporal.persistence.eachStore" -}}
{{- $stores := dict -}}
{{- $_ := set $stores "default" (include "temporal.persistence.getStoreByType" (list $ "default") | fromYaml) -}}
{{- $_ := set $stores "visibility" (include "temporal.persistence.getStoreByType" (list $ "visibility") | fromYaml) -}}
{{- $secondaryVisibility := include "temporal.persistence.getStoreByType" (list $ "secondaryVisibility") | fromYaml -}}
{{- if $secondaryVisibility -}}
{{- $_ := set $stores "secondaryVisibility" $secondaryVisibility -}}
{{- end -}}
{{- $stores | toYaml -}}
{{- end -}}

{{- define "temporal.persistence.getStore" -}}
{{- $root := index . 0 -}}
{{- $storeName := index . 1 -}}
{{- $datastores := $root.Values.server.config.persistence.datastores }}
{{- $store := dict "name" $storeName -}}
{{- $config := get $datastores $storeName -}}
{{- if hasKey $config "sql" -}}
    {{- $_ := set $store "driver" "sql" -}}
    {{- $storeConfig := get $config "sql" -}}
    {{- if not (hasKey $storeConfig "createDatabase") -}}
        {{- $_ := set $storeConfig "createDatabase" true -}}
    {{- end -}}
    {{- if not (hasKey $storeConfig "manageSchema") -}}
        {{- $_ := set $storeConfig "manageSchema" true -}}
    {{- end -}}
    {{- $_ := set $store "config" $storeConfig -}}
{{- else if hasKey $config "cassandra" -}}
    {{- $_ := set $store "driver" "cassandra" -}}
    {{- $storeConfig := get $config "cassandra" -}}
    {{- if not (hasKey $storeConfig "createDatabase") -}}
        {{- $_ := set $storeConfig "createDatabase" true -}}
    {{- end -}}
    {{- if not (hasKey $storeConfig "manageSchema") -}}
        {{- $_ := set $storeConfig "manageSchema" true -}}
    {{- end -}}
    {{- $_ := set $store "config" $storeConfig -}}
{{- else if hasKey $config "elasticsearch" -}}
    {{- $_ := set $store "driver" "elasticsearch" -}}
    {{- $storeConfig := get $config "elasticsearch" -}}
    {{- if not (hasKey $storeConfig "manageSchema") -}}
        {{- $_ := set $storeConfig "manageSchema" true -}}
    {{- end -}}
    {{- $_ := set $store "config" $storeConfig -}}
{{- else -}}
    {{- fail (printf "No valid driver configured for %s store" $store.name) -}}
{{- end -}}
{{- $store | toYaml -}}
{{- end -}}

{{- define "temporal.persistence.getStoreByType" -}}
{{- $root := index . 0 -}}
{{- $type := index . 1 -}}
{{- $storeName := get $root.Values.server.config.persistence (printf "%sStore" $type) -}}
{{- if $storeName -}}
{{- include "temporal.persistence.getStore" (list $root $storeName) -}}
{{- else -}}
{{- dict | toYaml -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.schema" -}}
{{- $store := . -}}
{{- if eq $store.name "default" -}}
{{- print "temporal" -}}
{{- else -}}
{{- print $store.name -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.secretName" -}}
{{- $root := index . 0 -}}
{{- $store := index . 1 -}}
{{- if $store.config.existingSecret -}}
{{- $store.config.existingSecret -}}
{{- else -}}
{{- include "temporal.componentname" (list $root (printf "%s-store" $store.name)) -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.connectAttributes" -}}
{{- $result := list -}}
{{- range $key, $value := . -}}
  {{- $result = append $result (printf "%s=%v" $key $value) -}}
{{- end -}}
{{- join "&" $result -}}
{{- end -}}

{{/*
Based on Bitnami charts method
Renders a value that contains template.
Usage:
{{ include "common.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "common.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{/*
TLS wiring helpers.

These turn the concise `server.tls`/`web.tls` stanzas into the volumes,
volume mounts, server `config.tls` and Web UI environment variables that
Temporal expects. The cert/key/ca paths, volume names and config shape are all
determined by Temporal, so users only supply an existing kubernetes.io/tls
secret (tls.crt, tls.key and ca.crt) and a handful of real choices.

The volume names are fixed constants so that each volume and its mount always
agree; only the mount path is user-configurable.
*/}}

{{/* Server: volumes for the internode/frontend TLS secrets. Renders "[]" when
disabled, so callers should gate on the enabled flags. */}}
{{- define "temporal.server.tls.volumes" -}}
{{- $tls := .Values.server.tls -}}
{{- $volumes := list -}}
{{- if $tls.internode.enabled -}}
{{- $volumes = append $volumes (dict "name" "internode-tls" "secret" (dict "secretName" (required "server.tls.internode.secretName is required when server.tls.internode.enabled is true" $tls.internode.secretName))) -}}
{{- end -}}
{{- if $tls.frontend.enabled -}}
{{- $volumes = append $volumes (dict "name" "frontend-tls" "secret" (dict "secretName" (required "server.tls.frontend.secretName is required when server.tls.frontend.enabled is true" $tls.frontend.secretName))) -}}
{{- end -}}
{{- toYaml $volumes -}}
{{- end -}}

{{/* Server: volume mounts matching temporal.server.tls.volumes. */}}
{{- define "temporal.server.tls.volumeMounts" -}}
{{- $tls := .Values.server.tls -}}
{{- $mounts := list -}}
{{- if $tls.internode.enabled -}}
{{- $mounts = append $mounts (dict "name" "internode-tls" "mountPath" $tls.internode.mountPath "readOnly" true) -}}
{{- end -}}
{{- if $tls.frontend.enabled -}}
{{- $mounts = append $mounts (dict "name" "frontend-tls" "mountPath" $tls.frontend.mountPath "readOnly" true) -}}
{{- end -}}
{{- toYaml $mounts -}}
{{- end -}}

{{/* Server: the config.tls block derived from server.tls. Renders "{}" when
disabled. server.config.tls is deep-merged on top of this by the configmap. */}}
{{- define "temporal.server.tls.config" -}}
{{- $tls := .Values.server.tls -}}
{{- $config := dict -}}
{{- range $section := list "internode" "frontend" -}}
{{- $s := index $tls $section -}}
{{- if $s.enabled -}}
{{- $server := dict "certFile" (printf "%s/tls.crt" $s.mountPath) "keyFile" (printf "%s/tls.key" $s.mountPath) "requireClientAuth" $s.requireClientAuth -}}
{{- if $s.requireClientAuth -}}
{{- $_ := set $server "clientCaFiles" (list (printf "%s/ca.crt" $s.mountPath)) -}}
{{- end -}}
{{- $client := dict "serverName" $s.serverName "rootCaFiles" (list (printf "%s/ca.crt" $s.mountPath)) -}}
{{- $_ := set $config $section (dict "server" $server "client" $client) -}}
{{- end -}}
{{- end -}}
{{- toYaml $config -}}
{{- end -}}

{{/* Web: volume for the TLS secret. Renders "[]" when disabled. */}}
{{- define "temporal.web.tls.volumes" -}}
{{- $tls := .Values.web.tls -}}
{{- $volumes := list -}}
{{- if $tls.enabled -}}
{{- $volumes = append $volumes (dict "name" "web-tls" "secret" (dict "secretName" (required "web.tls.secretName is required when web.tls.enabled is true" $tls.secretName))) -}}
{{- end -}}
{{- toYaml $volumes -}}
{{- end -}}

{{/* Web: volume mount matching temporal.web.tls.volumes. */}}
{{- define "temporal.web.tls.volumeMounts" -}}
{{- $tls := .Values.web.tls -}}
{{- $mounts := list -}}
{{- if $tls.enabled -}}
{{- $mounts = append $mounts (dict "name" "web-tls" "mountPath" $tls.mountPath "readOnly" true) -}}
{{- end -}}
{{- toYaml $mounts -}}
{{- end -}}

{{/* Web: TEMPORAL_TLS_* env for the Web UI -> frontend connection. Renders "[]"
when disabled. See https://docs.temporal.io/references/web-ui-environment-variables */}}
{{- define "temporal.web.tls.env" -}}
{{- $tls := .Values.web.tls -}}
{{- $env := list -}}
{{- if $tls.enabled -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_CA" "value" (printf "%s/ca.crt" $tls.mountPath)) -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_CERT" "value" (printf "%s/tls.crt" $tls.mountPath)) -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_KEY" "value" (printf "%s/tls.key" $tls.mountPath)) -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_SERVER_NAME" "value" $tls.serverName) -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_ENABLE_HOST_VERIFICATION" "value" (printf "%t" $tls.enableHostVerification)) -}}
{{- end -}}
{{- toYaml $env -}}
{{- end -}}

{{/*
Frontend-client TLS: shared wiring for the chart's own `temporal` CLI pods that
connect to the frontend (the namespace-setup job and the cluster-health test).
When server.tls.frontend is enabled these mount the frontend secret and set the
CLI's TEMPORAL_TLS_* env (note the CLI env var names differ from the Web UI's).
All render empty when frontend TLS is off, so callers gate on frontend.enabled.
The secret is mounted at a fixed path, /etc/temporal/tls/frontend.
*/}}
{{- define "temporal.frontendClient.tls.env" -}}
{{- $tls := .Values.server.tls.frontend -}}
{{- $env := list -}}
{{- if $tls.enabled -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS" "value" "true") -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_SERVER_CA_CERT_PATH" "value" "/etc/temporal/tls/frontend/ca.crt") -}}
{{- if $tls.serverName -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_SERVER_NAME" "value" $tls.serverName) -}}
{{- else -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_DISABLE_HOST_VERIFICATION" "value" "true") -}}
{{- end -}}
{{- if $tls.requireClientAuth -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_CLIENT_CERT_PATH" "value" "/etc/temporal/tls/frontend/tls.crt") -}}
{{- $env = append $env (dict "name" "TEMPORAL_TLS_CLIENT_KEY_PATH" "value" "/etc/temporal/tls/frontend/tls.key") -}}
{{- end -}}
{{- end -}}
{{- toYaml $env -}}
{{- end -}}

{{- define "temporal.frontendClient.tls.volumes" -}}
{{- $tls := .Values.server.tls.frontend -}}
{{- $volumes := list -}}
{{- if $tls.enabled -}}
{{- $volumes = append $volumes (dict "name" "frontend-tls" "secret" (dict "secretName" (required "server.tls.frontend.secretName is required when server.tls.frontend.enabled is true" $tls.secretName))) -}}
{{- end -}}
{{- toYaml $volumes -}}
{{- end -}}

{{- define "temporal.frontendClient.tls.volumeMounts" -}}
{{- $tls := .Values.server.tls.frontend -}}
{{- $mounts := list -}}
{{- if $tls.enabled -}}
{{- $mounts = append $mounts (dict "name" "frontend-tls" "mountPath" "/etc/temporal/tls/frontend" "readOnly" true) -}}
{{- end -}}
{{- toYaml $mounts -}}
{{- end -}}
