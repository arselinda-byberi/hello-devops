{{- define "hello-devops.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hello-devops.labels" -}}
app.kubernetes.io/name: {{ include "hello-devops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "hello-devops.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hello-devops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
