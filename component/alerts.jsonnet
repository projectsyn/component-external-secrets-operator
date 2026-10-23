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
      expr: 'max by (namespace, name) (externalsecret_status_condition{condition="Ready",status="False"}) == 1',
      'for': '10m',
      labels: {
        severity: 'warning',
      },
      annotations: {
        summary: 'ExternalSecret not ready: {{ $labels.namespace }}/{{ $labels.name }}',
        description: |||
            ExternalSecret {{ $labels.namespace }}/{{ $labels.name }} has been
            Ready=False for %s. Check status conditions and provider
            connectivity.
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

local additional_group =
  local parseRuleName(rname) =
    local rparts = std.splitLimit(rname, ':', 1);
    assert
      std.length(rparts) == 2 :
      'Expected custom alert rule to be prefixed with `record:` or `alert:`.';
    assert
      std.member([ 'alert', 'record' ], rparts[0]) :
      'Expected custom alert rule to be prefixed with `record:` or `alert:`, got `%s:`.' % rparts[0];
    { [rparts[0]]: rparts[1] };
  {
    name: 'external-secrets-operator-custom.rules',
    rules: [
      params.alerts.additionalRules[rname] + parseRuleName(rname)
      for rname in std.objectFields(params.alerts.additionalRules)
    ],
  };

local additional_alerts = prom.PrometheusRule('external-secrets-operator-custom') {
  spec+: {
    groups: [
      alertpatching.filterPatchRules(
        additional_group,
        ignoreNames=ignoreNames,
        patches=params.alerts.patches,
        preserveRecordingRules=true,
        patchNames=false,
      ),
    ],
  },
};

if has_monitoring then {
  [if std.length(eso_alerts.spec.groups[0].rules) > 0 then
    '10_eso_alerts']: eso_alerts,
  [if std.length(additional_group.rules) > 0 then
    '10_custom_alerts']: additional_alerts,
} else std.trace('Component ESO compiled for cluster that does not have monitoring, skipping alert rules generation.', {})
