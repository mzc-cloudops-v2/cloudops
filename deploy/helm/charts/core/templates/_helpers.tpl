{{/*
Fully-qualified resource name. nameOverride / fullnameOverride 지원.
*/}}
{{- define "core.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "core.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "core.fullname" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "core.selectorLabels" -}}
app.kubernetes.io/name: {{ include "core.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount 이름 — serviceAccount.name 이 비었으면 fullname 사용.
*/}}
{{- define "core.serviceAccountName" -}}
{{- if and .Values.global .Values.global.serviceAccount .Values.global.serviceAccount.name -}}
{{- .Values.global.serviceAccount.name -}}
{{- else if .Values.serviceAccount.create -}}
{{- default (include "core.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Secret 리소스 이름.
existingSecret 이 지정된 경우 그 값을 그대로 사용 (chart 가 만들지 않음).
*/}}
{{- define "core.secretName" -}}
{{- if .Values.secret.existingSecret -}}
{{- .Values.secret.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" (include "core.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
chart 가 자체 Secret 을 만들어야 하는지 여부.
- existingSecret 이 비어 있고
- secret.data 에 값이 하나라도 비어있지 않으면 만든다.
값이 모두 비어 있으면 Secret 자체를 생략 (envFrom 도 같이 생략).
*/}}
{{- define "core.shouldCreateSecret" -}}
{{- if and (not .Values.secret.existingSecret) .Values.secret.data -}}
{{- $hasValue := false -}}
{{- range $k, $v := .Values.secret.data -}}
{{- if $v -}}{{- $hasValue = true -}}{{- end -}}
{{- end -}}
{{- if $hasValue -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common envFrom block — non-sensitive ConfigMap + sensitive Secret 을 주입.
Secret 은 chart 가 만든 것이든 existingSecret 이든 동일 이름으로 참조.
*/}}
{{- define "core.envFrom" -}}
{{- if .Values.env }}
- configMapRef:
    name: {{ include "core.fullname" . }}-env
{{- end }}
{{- if or .Values.secret.existingSecret (include "core.shouldCreateSecret" .) }}
- secretRef:
    name: {{ include "core.secretName" . }}
{{- end }}
{{- end -}}

{{/*
Shared conf volume mount (/opt/cloudops/shared.yaml).
Only rendered when .Values.conf is non-empty.
*/}}
{{- define "core.confVolumeMount" -}}
{{- if .Values.conf }}
- name: shared-conf
  mountPath: /opt/cloudops/shared.yaml
  subPath: shared.yaml
{{- end }}
{{- end -}}

{{- define "core.confVolume" -}}
{{- if .Values.conf }}
- name: shared-conf
  configMap:
    name: {{ include "core.fullname" . }}-conf
{{- end }}
{{- end -}}

{{/*
Cron scheduler deployment 의 식별자/라벨. main core (REST/NATS) deployment 와
selector 가 충돌하지 않도록 ``-scheduler`` suffix 가 붙은 별도 name 을 쓴다.
``component=scheduler`` 라벨로 두 deployment 의 pod 를 구분한다.
*/}}
{{- define "core.schedulerName" -}}
{{- printf "%s-scheduler" (include "core.fullname" .) -}}
{{- end -}}

{{- define "core.schedulerLabels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "core.schedulerName" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: scheduler
{{- end -}}

{{- define "core.schedulerSelectorLabels" -}}
app.kubernetes.io/name: {{ include "core.schedulerName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: scheduler
{{- end -}}

{{/*
Temporal collect worker deployment 의 식별자/라벨. main/scheduler deployment 와
selector 가 충돌하지 않도록 ``-temporal-worker`` suffix + ``component=temporal-worker``
라벨을 쓴다 (scheduler 패턴과 동일).
*/}}
{{- define "core.temporalWorkerName" -}}
{{- printf "%s-temporal-worker" (include "core.fullname" .) -}}
{{- end -}}

{{- define "core.temporalWorkerLabels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "core.temporalWorkerName" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: temporal-worker
{{- end -}}

{{- define "core.temporalWorkerSelectorLabels" -}}
app.kubernetes.io/name: {{ include "core.temporalWorkerName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: temporal-worker
{{- end -}}

{{/*
Temporal frontend gRPC 주소 (NATS_URL 패턴과 동일하게 env ConfigMap 에서 자동 주입).
우선순위: .Values.temporalAddress override > global.namespace 파생
(``<ns>-temporal-frontend.<ns>-temporal``) > dev 기본값.
Temporal 서버는 별도 App(release/ns = ``<global.namespace>-temporal``)로 배포된다.
values.env 에 TEMPORAL_ADDRESS 키를 두지 않는다 — env.yaml range 가 중복 방출한다.
*/}}
{{- define "core.temporalAddress" -}}
{{- if .Values.temporalAddress -}}
{{- .Values.temporalAddress -}}
{{- else if (and .Values.global .Values.global.namespace) -}}
{{- printf "%s-temporal-frontend.%s-temporal.svc.cluster.local:7233" .Values.global.namespace .Values.global.namespace -}}
{{- else -}}
cloudops-temporal-frontend.cloudops-temporal.svc.cluster.local:7233
{{- end -}}
{{- end -}}
