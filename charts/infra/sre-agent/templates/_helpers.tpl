{{- define "sreagent.labels" -}}
app.kubernetes.io/part-of: sre-agent
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* Same prefix as the subchart's fullnameOverride, so every resource reads worthit-*. */}}
{{- define "sreagent.name" -}}
{{- index .Values "langgraph-cloud" "fullnameOverride" -}}
{{- end -}}

{{/* The subchart's API server Service: <name>-api-server, http port 80. */}}
{{- define "sreagent.agentServerUrl" -}}
http://{{ include "sreagent.name" . }}-api-server:80
{{- end -}}
