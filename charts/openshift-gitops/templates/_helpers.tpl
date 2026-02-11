{{/*
Expand the name of the chart.
*/}}
{{- define "openshift-gitops.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "openshift-gitops.fullname" -}}
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
{{- define "openshift-gitops.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openshift-gitops.labels" -}}
helm.sh/chart: {{ include "openshift-gitops.chart" . }}
{{ include "openshift-gitops.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openshift-gitops.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openshift-gitops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openshift-gitops.serviceAccountName" -}}
{{- if .Values.rbac.serviceAccount.create }}
{{- default (include "openshift-gitops.fullname" .) .Values.rbac.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.rbac.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the operator namespace
*/}}
{{- define "openshift-gitops.operatorNamespace" -}}
{{- .Values.operator.namespace }}
{{- end }}

{{/*
Create the ArgoCD namespace
*/}}
{{- define "openshift-gitops.argocdNamespace" -}}
{{- .Values.argocd.namespace }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "openshift-gitops.annotations" -}}
{{- with .Values.annotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for RBAC APIs
*/}}
{{- define "rbac.apiVersion" -}}
rbac.authorization.k8s.io/v1
{{- end }}

{{/*
Return the appropriate apiVersion for Subscription
*/}}
{{- define "subscription.apiVersion" -}}
operators.coreos.com/v1alpha1
{{- end }}

{{/*
Return the appropriate apiVersion for OperatorGroup
*/}}
{{- define "operatorgroup.apiVersion" -}}
operators.coreos.com/v1
{{- end }}

{{/*
Return the appropriate apiVersion for ArgoCD
*/}}
{{- define "argocd.apiVersion" -}}
argoproj.io/v1beta1
{{- end }}

{{/*
Return the appropriate apiVersion for AppProject
*/}}
{{- define "appproject.apiVersion" -}}
argoproj.io/v1alpha1
{{- end }}

{{/*
Return the appropriate apiVersion for ApplicationSet
*/}}
{{- define "applicationset.apiVersion" -}}
argoproj.io/v1alpha1
{{- end }}

{{/*
Validate required values - Enhanced with comprehensive checks
*/}}
{{- define "openshift-gitops.validateValues" -}}
{{- /* Basic required fields */ -}}
{{- if not .Values.operator.namespace }}
  {{- fail "operator.namespace is required" }}
{{- end }}
{{- if not .Values.argocd.namespace }}
  {{- fail "argocd.namespace is required" }}
{{- end }}
{{- if not .Values.operator.channel }}
  {{- fail "operator.channel is required" }}
{{- end }}

{{- /* Namespace validation */ -}}
{{- if eq .Values.argocd.namespace .Values.operator.namespace }}
  {{- fail "ArgoCD namespace must be different from operator namespace" }}
{{- end }}

{{- /* High availability validation */ -}}
{{- if .Values.argocd.ha.enabled }}
  {{- if lt (int .Values.argocd.server.replicas) 2 }}
    {{- fail "HA mode requires at least 2 server replicas" }}
  {{- end }}
  {{- if lt (int .Values.argocd.repo.replicas) 2 }}
    {{- fail "HA mode requires at least 2 repo server replicas" }}
  {{- end }}
  {{- if lt (int .Values.argocd.controller.replicas) 1 }}
    {{- fail "HA mode requires at least 1 controller replica" }}
  {{- end }}
  {{- if not .Values.argocd.ha.redisProxyReplicas }}
    {{- fail "HA mode requires redisProxyReplicas to be set" }}
  {{- end }}
  {{- if lt (int .Values.argocd.ha.redisProxyReplicas) 2 }}
    {{- fail "HA mode requires at least 2 redis proxy replicas" }}
  {{- end }}
{{- end }}

{{- /* Autoscaling validation */ -}}
{{- if .Values.argocd.server.autoscaling.enabled }}
  {{- if not .Values.argocd.server.autoscaling.maxReplicas }}
    {{- fail "server.autoscaling.maxReplicas is required when autoscaling is enabled" }}
  {{- end }}
  {{- if not .Values.argocd.server.autoscaling.minReplicas }}
    {{- fail "server.autoscaling.minReplicas is required when autoscaling is enabled" }}
  {{- end }}
  {{- if ge (int .Values.argocd.server.autoscaling.minReplicas) (int .Values.argocd.server.autoscaling.maxReplicas) }}
    {{- fail "server.autoscaling.minReplicas must be less than maxReplicas" }}
  {{- end }}
{{- end }}

{{- /* Resource validation */ -}}
{{- if .Values.argocd.server.resources }}
  {{- if not .Values.argocd.server.resources.requests }}
    {{- fail "server.resources.requests is required" }}
  {{- end }}
  {{- if not .Values.argocd.server.resources.limits }}
    {{- fail "server.resources.limits is required" }}
  {{- end }}
{{- end }}

{{- /* Channel validation */ -}}
{{- $validChannels := list "latest" "stable" "gitops-1.11" "gitops-1.12" "gitops-1.13" }}
{{- if not (has .Values.operator.channel $validChannels) }}
  {{- fail (printf "operator.channel must be one of: %s" (join ", " $validChannels)) }}
{{- end }}

{{- /* InstallPlanApproval validation */ -}}
{{- $validApprovals := list "Automatic" "Manual" }}
{{- if not (has .Values.operator.installPlanApproval $validApprovals) }}
  {{- fail (printf "operator.installPlanApproval must be one of: %s" (join ", " $validApprovals)) }}
{{- end }}

{{- /* RBAC validation */ -}}
{{- $validPolicies := list "role:readonly" "role:admin" "" }}
{{- if not (has .Values.argocd.rbac.defaultPolicy $validPolicies) }}
  {{- fail (printf "argocd.rbac.defaultPolicy must be one of: %s" (join ", " $validPolicies)) }}
{{- end }}

{{- /* Production environment validation */ -}}
{{- if or (contains "prod" .Values.argocd.namespace) (contains "production" .Values.argocd.namespace) }}
  {{- if eq .Values.operator.installPlanApproval "Automatic" }}
    {{- fail "Production environments should use Manual installPlanApproval for safety" }}
  {{- end }}
  {{- if not .Values.argocd.ha.enabled }}
    {{- printf "WARNING: Production environment without HA enabled. Consider enabling HA for resilience." }}
  {{- end }}
  {{- if eq .Values.argocd.rbac.defaultPolicy "role:admin" }}
    {{- fail "Production environments should not use 'role:admin' as defaultPolicy" }}
  {{- end }}
{{- end }}

{{- /* Repository validation */ -}}
{{- range .Values.argocd.repositories }}
  {{- if not .url }}
    {{- fail "Repository URL is required for all repositories" }}
  {{- end }}
  {{- if not .name }}
    {{- fail "Repository name is required for all repositories" }}
  {{- end }}
  {{- if not .type }}
    {{- fail "Repository type (git or helm) is required for all repositories" }}
  {{- end }}
  {{- $validTypes := list "git" "helm" }}
  {{- if not (has .type $validTypes) }}
    {{- fail (printf "Repository type must be 'git' or 'helm', got: %s" .type) }}
  {{- end }}
{{- end }}

{{- /* Project validation */ -}}
{{- range .Values.argocd.projects }}
  {{- if not .name }}
    {{- fail "Project name is required for all projects" }}
  {{- end }}
  {{- if not .sourceRepos }}
    {{- fail (printf "Project %s must have sourceRepos defined" .name) }}
  {{- end }}
  {{- if not .destinations }}
    {{- fail (printf "Project %s must have destinations defined" .name) }}
  {{- end }}
{{- end }}

{{- end }}

{{/*
Generate RBAC policy for ArgoCD
*/}}
{{- define "openshift-gitops.rbacPolicy" -}}
{{- if .Values.argocd.rbac.policy }}
{{ .Values.argocd.rbac.policy }}
{{- else }}
p, role:admin, *, *, *, allow
g, system:cluster-admins, role:admin
{{- end }}
{{- end }}

{{/*
Check if namespace exists using lookup
*/}}
{{- define "openshift-gitops.namespaceExists" -}}
{{- $namespace := .namespace }}
{{- $existing := lookup "v1" "Namespace" "" $namespace }}
{{- if $existing }}
true
{{- else }}
false
{{- end }}
{{- end }}
