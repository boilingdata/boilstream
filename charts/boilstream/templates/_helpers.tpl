{{/*
Common name templates and label helpers. Following the conventional Helm chart
patterns (https://helm.sh/docs/chart_best_practices/labels/) so resources play
nicely with Kustomize, ArgoCD, kube-prometheus, and anything else that filters
on the standard app.kubernetes.io/* labels.
*/}}

{{- define "boilstream.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "boilstream.fullname" -}}
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

{{- define "boilstream.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels go on every resource. Avoid version churn in selectors by
     keeping app.kubernetes.io/version OUT of selectors (only labels). */}}
{{- define "boilstream.labels" -}}
helm.sh/chart: {{ include "boilstream.chart" . }}
{{ include "boilstream.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: boilstream
{{- end -}}

{{/* Selector labels — the immutable subset. */}}
{{- define "boilstream.selectorLabels" -}}
app.kubernetes.io/name: {{ include "boilstream.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
