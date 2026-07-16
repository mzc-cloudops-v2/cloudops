{{/*
Generic plugin helpers — dict 컨텍스트 (dict "name" $name "plugin" $p "root" $).
개별 플러그인 차트의 <chart>.* helper 를 name 파라미터화한 것. 렌더 결과가 기존
per-plugin subchart 와 기능적으로 동일하도록 로직을 그대로 옮김.
*/}}

{{- define "plugins.fullname" -}}
{{- printf "plugin-%s" .name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "plugins.namespace" -}}
{{- $p := .plugin -}}{{- $root := .root -}}
{{- if $p.namespace -}}
{{- $p.namespace -}}
{{- else if (and $root.Values.global $root.Values.global.namespace) -}}
{{- printf "%s-plugin" $root.Values.global.namespace -}}
{{- else -}}
{{- $root.Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/* SA 이름: global.serviceAccount.name(공유) > serviceAccount.name > fullname */}}
{{- define "plugins.serviceAccountName" -}}
{{- $p := .plugin -}}{{- $root := .root -}}
{{- if and $root.Values.global $root.Values.global.serviceAccount $root.Values.global.serviceAccount.name -}}
{{- $root.Values.global.serviceAccount.name -}}
{{- else if dig "serviceAccount" "name" "" $p -}}
{{- dig "serviceAccount" "name" "" $p -}}
{{- else -}}
{{- include "plugins.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "plugins.labels" -}}
helm.sh/chart: {{ .root.Chart.Name }}-{{ .root.Chart.Version }}
app.kubernetes.io/name: {{ include "plugins.fullname" . }}
app.kubernetes.io/version: {{ dig "image" "tag" "latest" .plugin | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}

{{- define "plugins.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugins.fullname" . }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}

{{/* NATS host:port — global.namespace 기반, 없으면 release namespace */}}
{{- define "plugins.natsHost" -}}
{{- $root := .root -}}{{- $ns := $root.Release.Namespace -}}
{{- if (and $root.Values.global $root.Values.global.namespace) -}}{{- $ns = $root.Values.global.namespace -}}{{- end -}}
{{- printf "nats.%s.svc.cluster.local:4222" $ns -}}
{{- end -}}

{{/* Temporal frontend — plugin.temporalAddress > global.namespace 유도 > dev fallback */}}
{{- define "plugins.temporalAddress" -}}
{{- $addr := dig "temporalAddress" "" .plugin -}}{{- $root := .root -}}
{{- if $addr -}}
{{- $addr -}}
{{- else if (and $root.Values.global $root.Values.global.namespace) -}}
{{- printf "%s-temporal-frontend.%s-temporal.svc.cluster.local:7233" $root.Values.global.namespace $root.Values.global.namespace -}}
{{- else -}}
{{- "cloudops-temporal-frontend.cloudops-temporal.svc.cluster.local:7233" -}}
{{- end -}}
{{- end -}}

{{/* envFrom — env ConfigMap 있을 때만 */}}
{{- define "plugins.envFrom" -}}
{{- if .plugin.env }}
- configMapRef:
    name: {{ include "plugins.fullname" . }}-env
{{- end }}
{{- end -}}
