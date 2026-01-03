{{/*
Expand the name of the chart.
*/}}
{{- define "petclinic.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "petclinic.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "petclinic.labels" -}}
helm.sh/chart: {{ include "petclinic.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: petclinic
{{- end }}

{{/*
Selector labels for a specific service
*/}}
{{- define "petclinic.selectorLabels" -}}
app: {{ .name }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .release }}
{{- end }}

{{/*
Pod annotations for Istio
*/}}
{{- define "petclinic.istioAnnotations" -}}
{{- if .Values.global.istio.enabled }}
sidecar.istio.io/inject: "true"
# Exclude Eureka and Config Server ports from sidecar to fix Apache HttpClient 5.4+ issue
# Reference: https://github.com/istio/istio/issues/53239
traffic.sidecar.istio.io/excludeOutboundPorts: "8761,8888"
{{- end }}
{{- end }}

{{/*
Config Server URL
*/}}
{{- define "petclinic.configServerUrl" -}}
http://{{ .Values.configServer.name }}:{{ .Values.configServer.service.port }}
{{- end }}

{{/*
Discovery Server URL
*/}}
{{- define "petclinic.discoveryServerUrl" -}}
http://{{ .Values.discoveryServer.name }}:{{ .Values.discoveryServer.service.port }}/eureka
{{- end }}

