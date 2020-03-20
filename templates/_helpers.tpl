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
Call nested templates.
Source: https://stackoverflow.com/a/52024583/3027614
*/}}
{{- define "call-nested" }}
{{- $dot := index . 0 }}
{{- $subchart := index . 1 }}
{{- $template := index . 2 }}
{{- include $template (dict "Chart" (dict "Name" $subchart) "Values" (index $dot.Values $subchart) "Release" $dot.Release "Capabilities" $dot.Capabilities) }}
{{- end }}

{{- define "temporal.frontend.grpcPort" -}}
7233
{{- end -}}

{{- define "temporal.frontend.membershipPort" -}}
6933
{{- end -}}


{{- define "temporal.history.grpcPort" -}}
7234
{{- end -}}

{{- define "temporal.history.membershipPort" -}}
6934
{{- end -}}

{{- define "temporal.matching.grpcPort" -}}
7235
{{- end -}}

{{- define "temporal.matching.membershipPort" -}}
6935
{{- end -}}

{{- define "temporal.worker.grpcPort" -}}
7239
{{- end -}}

{{- define "temporal.worker.membershipPort" -}}
6939
{{- end -}}

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
{{- if $storeConfig.driver -}}
{{- $storeConfig.driver -}}
{{- else if $global.Values.cassandra.enabled -}}
{{- print "cassandra" -}}
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
{{- if $storeConfig.cassandra.existingSecret -}}
{{- $storeConfig.cassandra.existingSecret -}}
{{- else if $storeConfig.cassandra.password -}}
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
{{/* Cassandra password is optional, but we will create an empty secret for it */}}
{{- print "password" -}}
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
{{- printf "%s.%s.svc.cluster.local," $cassandraName $.Release.Namespace -}}
{{- end }}
{{- end -}}

{{/*
The first Cassandra host in the stateful set.
*/}}
{{- define "cassandra.host" -}}
{{- $cassandraName := include "call-nested" (list . "cassandra" "cassandra.fullname") -}}
{{- printf "%s.%s.svc.cluster.local" $cassandraName .Release.Namespace -}}
{{- end -}}
