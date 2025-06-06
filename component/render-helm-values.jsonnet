local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.external_secrets_operator;

local onOpenshift =
  std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);

{
  rendered_values: params.helm_values {
    [if onOpenshift then 'global']: {
      compatibility: {
        openshift: {
          adaptSecurityContext: 'force',
        },
      },
    },
  },
}
