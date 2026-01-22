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
{{- include "temporal.persistence.getStore" (list $root $storeName) -}}
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
