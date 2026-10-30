local alertpatching = import 'lib/alert-patching.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local prom = import 'lib/prom.libsonnet';


local inv = kap.inventory();
local params = inv.parameters.external_secrets_operator;

local ignoreNames = com.renderArray(params.alerts.ignoreNames);

local isOpenshift = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);
local has_monitoring = isOpenshift || std.member(inv.applications, 'prometheus');

local eso_group = {
  name: 'external-secrets-operator.rules',
  rules: [
    {
      local this = self,
      alert: 'ExternalSecretNotReady',
      expr: |||
        max by (namespace, name) (externalsecret_status_condition{condition="Ready",status="False"}) == 1
      |||,
      'for': '10m',
      labels: {
        severity: 'warning',
      },
      annotations: {
        summary: 'ExternalSecret not ready: {{ $labels.namespace }}/{{ $labels.name }}',
        description: |||
          ExternalSecret {{ $labels.namespace }}/{{ $labels.name }} has been Ready=False for %s.
          Check status conditions and provider connectivity.
        ||| % this['for'],
      },
    },
    {
      local this = self,
      alert: 'ExternalSecretsWebhookErrors',
      expr: |||
        sum(increase(controller_runtime_webhook_requests_total{service=~".*external-secrets.*",code="500"}[5m])) > 0
      |||,
      'for': '5m',
      labels: {
        severity: 'critical',
      },
      annotations: {
        summary: 'external-secrets admission webhook returning HTTP 500',
        description: |||
          Webhook has returned {{ $value }} HTTP 500s in %s.
          If failurePolicy=Fail, creating/updating ExternalSecrets and SecretStores is blocked cluster-wide.
        ||| % this['for'],
      },
    },
    {
      local this = self,
      alert: 'ExternalSecretsReconcileErrorRateHigh',
      expr: |||
        (
          sum by (controller) (increase(controller_runtime_reconcile_total{service=~".*external-secrets.*",result="error"}[15m]))
          /
          sum by (controller) (increase(controller_runtime_reconcile_total{service=~".*external-secrets.*"}[15m]))
        ) > 0.05
        and
        sum by (controller) (increase(controller_runtime_reconcile_total{service=~".*external-secrets.*"}[15m])) > 1
      |||,
      'for': '15m',
      labels: {
        severity: 'warning',
      },
      annotations: {
        summary: 'High reconcile error rate: {{ $labels.controller }}',
        description: |||
          Controller {{ $labels.controller }} error rate is {{ $value | humanizePercentage }} over %s.
        ||| % this['for'],
      },
    },
    {
      local this = self,
      alert: 'ExternalSecretsProviderAPIErrorRateHigh',
      expr: |||
        sum by (provider) (increase(externalsecret_provider_api_calls_count{service=~".*external-secrets.*",status="error"}[15m]))
        /
        sum by (provider) (increase(externalsecret_provider_api_calls_count{service=~".*external-secrets.*"}[15m])) > 0.10
      |||,
      'for': '15m',
      labels: {
        severity: 'warning',
      },
      annotations: {
        summary: 'High provider API error rate: {{ $labels.provider }}',
        description: |||
          More than 10 percent of calls to {{ $labels.provider }} failing for %s. Check provider availability, credentials and rate limits.
        ||| % this['for'],
      },
    },
  ],
};

local eso_alerts = prom.PrometheusRule('external-secrets-operator') {
  spec+: {
    groups: [
      alertpatching.filterPatchRules(
        eso_group,
        ignoreNames=ignoreNames,
        patches=params.alerts.patches,
        preserveRecordingRules=true,
        patchNames=false,
      ),
    ],
  },
};

local additional_groups = alertpatching.renderGroups({
  'external-secrets-operator-custom.rules': params.alerts.additionalRules,
});

local additional_alerts = prom.PrometheusRule('external-secrets-operator-custom') {
  spec+: {
    groups: std.map(
      function(g) alertpatching.filterPatchRules(
        g,
        ignoreNames=ignoreNames,
        patches=params.alerts.patches,
        preserveRecordingRules=true,
        patchNames=false,
      ),
      additional_groups,
    ),
  },
};

if has_monitoring then {
  [if std.length(eso_alerts.spec.groups[0].rules) > 0 then
    '10_eso_alerts']: eso_alerts,
  [if std.length(additional_groups[0].rules) > 0 then
    '10_custom_alerts']: additional_alerts,
} else std.trace('Component ESO compiled for cluster that does not have monitoring, skipping alert rules generation.', {})
