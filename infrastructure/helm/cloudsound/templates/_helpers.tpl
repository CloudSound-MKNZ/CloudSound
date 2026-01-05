{{/*
Expand the name of the chart.
*/}}
{{- define "cloudsound.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cloudsound.fullname" -}}
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
{{- define "cloudsound.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cloudsound.labels" -}}
helm.sh/chart: {{ include "cloudsound.chart" . }}
{{ include "cloudsound.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cloudsound.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudsound.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cloudsound.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cloudsound.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate image name with registry
*/}}
{{- define "cloudsound.image" -}}
{{- $registry := .global.imageRegistry | default "" -}}
{{- $repository := .service.image.repository -}}
{{- $tag := .service.image.tag | default "latest" -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end }}

{{/*
Common environment variables for all services
*/}}
{{- define "cloudsound.commonEnv" -}}
- name: ENVIRONMENT
  value: {{ .Values.global.environment | quote }}
- name: POSTGRES_HOST
  value: {{ .Release.Name }}-postgresql
- name: POSTGRES_PORT
  value: "5432"
- name: POSTGRES_USER
  value: {{ .Values.postgresql.auth.username | quote }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secrets
      key: postgres-password
- name: POSTGRES_DB
  value: {{ .Values.postgresql.auth.database | quote }}
- name: KAFKA_BOOTSTRAP_SERVERS
  value: {{ .Release.Name }}-kafka:9092
- name: RABBITMQ_HOST
  value: {{ .Release.Name }}-rabbitmq
- name: RABBITMQ_PORT
  value: "5672"
- name: RABBITMQ_USER
  value: {{ .Values.rabbitmq.auth.username | quote }}
- name: RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secrets
      key: rabbitmq-password
- name: MINIO_ENDPOINT
  value: {{ .Release.Name }}-minio:9000
- name: MINIO_ACCESS_KEY
  value: {{ .Values.minio.auth.rootUser | quote }}
- name: MINIO_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secrets
      key: minio-secret-key
- name: MINIO_BUCKET
  value: cloudsound-music
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secrets
      key: secret-key
- name: LOG_LEVEL
  value: {{ .Values.apiGateway.env.LOG_LEVEL | default "INFO" | quote }}
- name: LOG_FORMAT
  value: {{ .Values.apiGateway.env.LOG_FORMAT | default "json" | quote }}
{{- end }}

{{/*
Service URLs for inter-service communication
*/}}
{{- define "cloudsound.serviceUrls" -}}
- name: API_GATEWAY_URL
  value: http://{{ .Release.Name }}-api-gateway:80
- name: RADIO_STREAMING_URL
  value: http://{{ .Release.Name }}-radio-streaming:8004
- name: CONCERT_MANAGEMENT_URL
  value: http://{{ .Release.Name }}-concert-management:8005
- name: AUTHENTICATION_URL
  value: http://{{ .Release.Name }}-authentication:8006
- name: ANALYTICS_URL
  value: http://{{ .Release.Name }}-analytics:8007
- name: MUSIC_DISCOVERY_URL
  value: http://{{ .Release.Name }}-music-discovery:8003
- name: EVENT_MANAGER_URL
  value: http://{{ .Release.Name }}-event-manager:8002
{{- end }}

