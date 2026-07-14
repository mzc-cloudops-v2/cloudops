{{- define "cloudops.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cloudops.fullname" -}}
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

{{- define "cloudops.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cloudops.labels" -}}
helm.sh/chart: {{ include "cloudops.chart" . }}
app.kubernetes.io/name: {{ include "cloudops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "cloudops.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
S3 config Secret 이름 — existingSecret 지정 시 그대로, 아니면 chart 생성 Secret.
*/}}
{{- define "seaweedfs.s3SecretName" -}}
{{- if .Values.s3.auth.existingSecret -}}
{{- .Values.s3.auth.existingSecret -}}
{{- else -}}
seaweedfs-s3-config
{{- end -}}
{{- end -}}
