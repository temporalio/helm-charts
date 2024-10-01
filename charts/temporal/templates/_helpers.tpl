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
{{ default (include "temporal.fullname" .) .Values.serviceAccount.name }}
{{- end -}}

{{/*
Define the service account as needed
*/}}
{{- define "temporal.serviceAccount" -}}
{{- if .Values.serviceAccount.name -}}
serviceAccountName: {{ include "temporal.serviceAccountName" . }}
{{- end -}}
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
{{ with $resourceType -}}
{{- $resourceTypeKey := printf "%sLabels" . -}}
{{- $resourceLabels := dict -}}
{{- if or (eq $scope "") (ne $component "server") -}}
{{- $resourceLabels = (index $global.Values $component $resourceTypeKey) -}}
{{- else -}}
{{- $resourceLabels = (index $global.Values $component $scope $resourceTypeKey) -}}
{{- end -}}
{{- range $label_name, $label_value := $resourceLabels -}}
{{ $label_name}}: {{ $label_value }}
{{- end -}}
{{- end -}}
{{ include "temporal.additionalResourceLabels" $global }}
{{- end -}}

{{/*
Additonal user specified labels for all resources
*/}}
{{- define "temporal.additionalResourceLabels" -}}
{{- range $label_name, $label_value := .Values.additionalLabels }}
{{ $label_name }}: {{ $label_value }}
{{- end -}}
{{- end -}}

{{/*
Call nested templates.
Source: https://stackoverflow.com/a/52024583/3027614
*/}}
{{- define "call-nested" }}
{{- $dot := index . 0 }}
{{- $subchart := index . 1 }}
{{- $template := index . 2 }}
{{- include $template (dict "Chart" (dict "Name" $subchart) "Values" (index $dot.Values $subchart) "Release" $dot.Release "Capabilities" $dot.Capabilities) }}
{{- end }}

{{- define "temporal.persistence.schema" -}}
{{- if eq . "default" -}}
{{- print "temporal" -}}
{{- else -}}
{{- print . -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.driver" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if and (eq $store "default") $global.Values.cassandra.enabled -}}
{{- print "cassandra" -}}
{{- else if and (eq $store "visibility") (or $global.Values.elasticsearch.enabled $global.Values.elasticsearch.external) -}}
{{- print "elasticsearch" -}}
{{- else if $storeConfig.driver -}}
{{- $storeConfig.driver -}}
{{- else if $global.Values.mysql.enabled -}}
{{- print "sql" -}}
{{- else if $global.Values.postgresql.enabled -}}
{{- print "sql" -}}
{{- else -}}
{{- required (printf "Please specify persistence driver for %s store" $store) $storeConfig.driver -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.cassandra.hosts" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.cassandra.hosts -}}
{{- $storeConfig.cassandra.hosts | join "," -}}
{{- else if and $global.Values.cassandra.enabled (eq (include "temporal.persistence.driver" (list $global $store)) "cassandra") -}}
{{- include "cassandra.hosts" $global -}}
{{- else -}}
{{- required (printf "Please specify cassandra hosts for %s store" $store) $storeConfig.cassandra.hosts -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.cassandra.port" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.cassandra.port -}}
{{- $storeConfig.cassandra.port -}}
{{- else if and $global.Values.cassandra.enabled (eq (include "temporal.persistence.driver" (list $global $store)) "cassandra") -}}
{{- $global.Values.cassandra.config.ports.cql -}}
{{- else -}}
{{- required (printf "Please specify cassandra port for %s store" $store) $storeConfig.cassandra.port -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.cassandra.secretName" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- $driverConfig := $storeConfig.cassandra -}}
{{- if $driverConfig.existingSecret -}}
{{- $driverConfig.existingSecret -}}
{{- else if $driverConfig.password -}}
{{- include "temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- else -}}
{{/* Cassandra password is optional, but we will create an empty secret for it */}}
{{- include "temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.cassandra.secretKey" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- $driverConfig := $storeConfig.cassandra -}}
{{- with $driverConfig.secretKey -}}
{{- print . -}}
{{- else -}}
{{/* Cassandra password is optional, but we will create an empty secret for it */}}
{{- print "password" -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.database" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.sql.database -}}
{{- $storeConfig.sql.database -}}
{{- else -}}
{{- required (printf "Please specify database for %s store" $store) -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.driver" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.sql.driver -}}
{{- $storeConfig.sql.driver -}}
{{- else if $global.Values.mysql.enabled -}}
{{- print "mysql" -}}
{{- else if $global.Values.postgresql.enabled -}}
{{- print "postgres" -}}
{{- else -}}
{{- required (printf "Please specify sql driver for %s store" $store) $storeConfig.sql.host -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.host" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.sql.host -}}
{{- $storeConfig.sql.host -}}
{{- else if and $global.Values.mysql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "mysql8")) -}}
{{- include "mysql.host" $global -}}
{{- else if and $global.Values.postgresql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "postgres12")) -}}
{{- include "postgresql.host" $global -}}
{{- else -}}
{{- required (printf "Please specify sql host for %s store" $store) $storeConfig.sql.host -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.port" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.sql.port -}}
{{- $storeConfig.sql.port -}}
{{- else if and $global.Values.mysql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "mysql8")) -}}
{{- $global.Values.mysql.service.port -}}
{{- else if and $global.Values.postgresql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "postgres12")) -}}
{{- $global.Values.postgresql.service.port -}}
{{- else -}}
{{- required (printf "Please specify sql port for %s store" $store) $storeConfig.sql.port -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.user" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.sql.user -}}
{{- $storeConfig.sql.user -}}
{{- else if and $global.Values.mysql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "mysql8")) -}}
{{- $global.Values.mysql.mysqlUser -}}
{{- else if and $global.Values.postgresql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "postgres12")) -}}
{{- $global.Values.postgresql.postgresqlUser -}}
{{- else -}}
{{- required (printf "Please specify sql user for %s store" $store) $storeConfig.sql.user -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.password" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- if $storeConfig.sql.password -}}
{{- $storeConfig.sql.password -}}
{{- else if and $global.Values.mysql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "mysql8")) -}}
{{- if or $global.Values.schema.setup.enabled $global.Values.schema.update.enabled -}}
{{- required "Please specify password for MySQL chart" $global.Values.mysql.mysqlPassword -}}
{{- else -}}
{{- $global.Values.mysql.mysqlPassword -}}
{{- end -}}
{{- else if and $global.Values.postgresql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "postgres12")) -}}
{{- if or $global.Values.schema.setup.enabled $global.Values.schema.update.enabled -}}
{{- required "Please specify password for PostgreSQL chart" $global.Values.postgresql.postgresqlPassword -}}
{{- else -}}
{{- $global.Values.postgresql.postgresqlPassword -}}
{{- end -}}
{{- else -}}
{{- required (printf "Please specify sql password for %s store" $store) $storeConfig.sql.password -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.secretName" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- $driverConfig := $storeConfig.sql -}}
{{- if $driverConfig.existingSecret -}}
{{- $driverConfig.existingSecret -}}
{{- else if $driverConfig.secretName -}}
{{- print $driverConfig.secretName -}}
{{- else if $storeConfig.sql.password -}}
{{- include "temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- else if and $global.Values.mysql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "mysql8")) -}}
{{- include "call-nested" (list $global "mysql" "mysql.secretName") -}}
{{- else if and $global.Values.postgresql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "postgres12")) -}}
{{- include "call-nested" (list $global "postgresql" "postgresql.secretName") -}}
{{- else -}}
{{- required (printf "Please specify sql password or existing secret for %s store" $store) $storeConfig.sql.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.sql.secretKey" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.server.config.persistence $store -}}
{{- $driverConfig := $storeConfig.sql -}}
{{- if $driverConfig.secretKey -}}
{{- print $driverConfig.secretKey -}}
{{- else if or $driverConfig.existingSecret $driverConfig.password -}}
{{- print "password" -}}
{{- else if and $global.Values.mysql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "mysql8")) -}}
{{- print "mysql-password" -}}
{{- else if and $global.Values.postgresql.enabled (and (eq (include "temporal.persistence.driver" (list $global $store)) "sql") (eq (include "temporal.persistence.sql.driver" (list $global $store)) "postgres12")) -}}
{{- print "postgresql-password" -}}
{{- else -}}
{{- fail (printf "Please specify sql password or existing secret for %s store" $store) -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.elasticsearch.secretName" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $driverConfig := $global.Values.elasticsearch -}}
{{- if $driverConfig.existingSecret -}}
{{- print $driverConfig.existingSecret -}}
{{- else if $driverConfig.secretName -}}
{{- print $driverConfig.secretName -}}
{{- else -}}
{{- include "temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.elasticsearch.secretKey" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $driverConfig := $global.Values.elasticsearch -}}
{{- if $driverConfig.secretKey -}}
{{- print $driverConfig.secretKey -}}
{{- else -}}
{{- "password" -}}
{{- end -}}
{{- end -}}

{{- define "temporal.persistence.secretName" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- include (printf "temporal.persistence.%s.secretName" (include "temporal.persistence.driver" (list $global $store))) (list $global $store) -}}
{{- end -}}

{{- define "temporal.persistence.secretKey" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- include (printf "temporal.persistence.%s.secretKey" (include "temporal.persistence.driver" (list $global $store))) (list $global $store) -}}
{{- end -}}

{{/*
All Cassandra hosts.
*/}}
{{- define "cassandra.hosts" -}}
{{- range $i := (until (int .Values.cassandra.config.cluster_size)) }}
{{- $cassandraName := include "call-nested" (list $ "cassandra" "cassandra.fullname") -}}
{{- printf "%s.%s," $cassandraName $.Release.Namespace -}}
{{- end }}
{{- end -}}

{{/*
The first Cassandra host in the stateful set.
*/}}
{{- define "cassandra.host" -}}
{{- $cassandraName := include "call-nested" (list . "cassandra" "cassandra.fullname") -}}
{{- printf "%s.%s" $cassandraName .Release.Namespace -}}
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
