{{- define "templateApps.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "templateApps.fullname" -}}
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

{{- define "templateApps.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "templateApps.labels" -}}
helm.sh/chart: {{ include "templateApps.chart" . }}
{{ include "templateApps.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "templateApps.selectorLabels" -}}
app.kubernetes.io/name: {{ include "templateApps.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "templateApps.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "templateApps.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
<<<<<<< Updated upstream
=======

{{/*
Generate trackable app name for FluxCD image update resources.
Uses nameOverride if set, otherwise falls back to Chart name.
*/}}

{{- define "trackableappname" -}}
{{- $trackableName := printf "%s-%s" (include "appname" .) .Values.application.track -}}
{{- $trackableName | trimSuffix "-default" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

>>>>>>> Stashed changes
