{{/*
Expand the name of the chart.
*/}}
{{- define "temporal-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "temporal-proxy.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Render chart namespace, falling back to release namespace when not defined.
*/}}
{{- define "temporal-proxy.namespace" -}}
{{- if .Values.namespace }}
{{- .Values.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "temporal-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "temporal-proxy.labels" -}}
helm.sh/chart: {{ include "temporal-proxy.chart" . }}
{{ include "temporal-proxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "temporal-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "temporal-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "temporal-proxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "temporal-proxy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Rewrite a secret-bearing config field into a ${VAR} reference.

If holder[field] is a { secretKeyRef: {...} } map, replace it with "${var}"
and append a container env var (name=var, valueFrom.secretKeyRef=ref) to
acc.env. A plain string value is left untouched. Any other map fails the
render, since a near-miss key such as secretRef would otherwise land in the
ConfigMap verbatim and only surface as an unmarshalling error at proxy
startup. Mutates holder and acc in place and emits no output.

Args (dict): holder, field, var, acc, path (config path, for error messages).
*/}}
{{- define "temporal-proxy.secretRef" -}}
{{- $val := index .holder .field -}}
{{- if kindIs "map" $val -}}
{{- if not (hasKey $val "secretKeyRef") -}}
{{- fail (printf "%s must be a string or a secretKeyRef" .path) -}}
{{- end -}}
{{- $_ := set .holder .field (printf "${%s}" .var) -}}
{{- $_ := set .acc "env" (append .acc.env (dict "name" .var "valueFrom" (dict "secretKeyRef" $val.secretKeyRef))) -}}
{{- end -}}
{{- end -}}

{{/*
Turn a tls block that references a Secret into mounted file paths.

Sets cert/key (and ca, only when caKey is given) to files under
/etc/temporal-proxy/certs/<slot>, appends the matching volume and volumeMount
to acc, and removes the chart-only keys (secretName, certKey, keyKey, caKey).
Key names default to the cert-manager layout (tls.crt / tls.key). An explicit
cert or key alongside secretName fails the render rather than being silently
overwritten with the mount path. Mutates tls and acc in place and emits no
output.

Args (dict): tls, slot, acc.
*/}}
{{- define "temporal-proxy.tlsMount" -}}
{{- $tls := .tls -}}
{{- if or (hasKey $tls "cert") (hasKey $tls "key") -}}
{{- fail (printf "tls for %s sets both secretName and cert/key; use certKey/keyKey to point at other keys in the Secret, or drop secretName and mount the files yourself" .slot) -}}
{{- end -}}
{{- if and (hasKey $tls "ca") (hasKey $tls "caKey") -}}
{{- fail (printf "tls for %s sets both ca and caKey; use either ca or caKey" .slot) -}}
{{- end -}}
{{- $mount := printf "/etc/temporal-proxy/certs/%s" .slot -}}
{{- $name := printf "certs-%s" .slot -}}
{{- $_ := set $tls "cert" (printf "%s/%s" $mount (default "tls.crt" $tls.certKey)) -}}
{{- $_ := set $tls "key" (printf "%s/%s" $mount (default "tls.key" $tls.keyKey)) -}}
{{- if $tls.caKey -}}
{{- $_ := set $tls "ca" (printf "%s/%s" $mount $tls.caKey) -}}
{{- end -}}
{{- $_ := set .acc "volumes" (append .acc.volumes (dict "name" $name "secret" (dict "secretName" $tls.secretName))) -}}
{{- $_ := set .acc "volumeMounts" (append .acc.volumeMounts (dict "name" $name "mountPath" $mount "readOnly" true)) -}}
{{- $_ := unset $tls "secretName" -}}
{{- $_ := unset $tls "certKey" -}}
{{- $_ := unset $tls "keyKey" -}}
{{- $_ := unset $tls "caKey" -}}
{{- end -}}

{{/*
Render the proxy config plus its Kubernetes wiring.
Returns a YAML dict: { config, env, volumes, volumeMounts }.
Consumers parse with `include "temporal-proxy.rendered" . | fromYaml`.

Secret-bearing fields (upstream apiKey, static token) become ${VAR} env
references, and tls blocks with a secretName become mounted files, via the
temporal-proxy.secretRef and temporal-proxy.tlsMount helpers.
*/}}
{{- define "temporal-proxy.rendered" -}}
{{- $cfg := deepCopy .Values.config -}}
{{- $acc := dict "env" (list) "volumes" (list) "volumeMounts" (list) -}}
{{- if not $cfg.hostPort -}}
{{- $_ := set $cfg "hostPort" (printf ":%v" .Values.service.port) -}}
{{- end -}}
{{- /* Gateway tls runs before the upstream loop so its volume/mount sort first. */ -}}
{{- if and $cfg.tls (hasKey $cfg.tls "secretName") -}}
{{- $_ := include "temporal-proxy.tlsMount" (dict "tls" $cfg.tls "slot" "gateway" "acc" $acc) -}}
{{- end -}}
{{- range $i, $up := (default (list) $cfg.upstreams) -}}
{{- /* Wiring derives an env var name, a volume name and a mount path from the
upstream name, so an unnamed upstream cannot be wired. Identify it by index,
since there is no name to quote. */ -}}
{{- $wired := or (and $up.credentials $up.credentials.static) (and $up.tls (hasKey $up.tls "secretName")) -}}
{{- if and $wired (not $up.name) -}}
{{- fail (printf "upstreams[%d] must have a name to wire its credentials or tls secret" $i) -}}
{{- end -}}
{{- if and $up.credentials $up.credentials.static -}}
{{- $var := printf "TP_UPSTREAM_%s_API_KEY" (upper (regexReplaceAll "[^A-Za-z0-9]" $up.name "_")) -}}
{{- $path := printf "upstreams[%s].credentials.static.apiKey" $up.name -}}
{{- $_ := include "temporal-proxy.secretRef" (dict "holder" $up.credentials.static "field" "apiKey" "var" $var "acc" $acc "path" $path) -}}
{{- end -}}
{{- if and $up.tls (hasKey $up.tls "secretName") -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $up.name) -}}
{{- fail (printf "upstream name %q must be DNS-1123 safe (lowercase alphanumeric and '-') to mount a tls secret" $up.name) -}}
{{- end -}}
{{- $_ := include "temporal-proxy.tlsMount" (dict "tls" $up.tls "slot" (printf "upstream-%s" $up.name) "acc" $acc) -}}
{{- end -}}
{{- end -}}
{{- if and $cfg.auth $cfg.auth.staticToken -}}
{{- $_ := include "temporal-proxy.secretRef" (dict "holder" $cfg.auth.staticToken "field" "token" "var" "TP_AUTH_STATIC_TOKEN" "acc" $acc "path" "auth.staticToken.token") -}}
{{- end -}}
{{- $result := dict "config" $cfg "env" $acc.env "volumes" $acc.volumes "volumeMounts" $acc.volumeMounts -}}
{{- $result | toYaml -}}
{{- end -}}
