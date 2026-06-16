{{/*
Expand the name of the chart.
*/}}
{{- define "k8s-export.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "k8s-export.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "k8s-export.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k8s-export.labels" -}}
helm.sh/chart: {{ include "k8s-export.chart" . }}
{{ include "k8s-export.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k8s-export.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-export.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Target namespace helper
*/}}
{{- define "k8s-export.namespace" -}}
{{- default .Release.Namespace .Values.namespace -}}
{{- end }}

{{/*
Per-app labels to keep selectors stable for services and deployments
*/}}
{{- define "k8s-export.appLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ default "application" .component }}
{{- end }}

{{/*
PostgreSQL secret name helper
*/}}
{{- define "k8s-export.postgresSecretName" -}}
{{- if .Values.postgres.auth.existingSecret -}}
{{- .Values.postgres.auth.existingSecret -}}
{{- else -}}
{{- .Values.postgres.auth.secretName | default (printf "%s-secret" .Values.postgres.name) -}}
{{- end -}}
{{- end }}

{{/*
PostgreSQL namespace helper
*/}}
{{- define "k8s-export.postgresNamespace" -}}
{{- default (include "k8s-export.namespace" .) .Values.postgres.namespace -}}
{{- end }}
