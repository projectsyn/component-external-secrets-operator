// main template for external-secrets-operator
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.external_secrets_operator;

// Define outputs below
{
  '00_namespace': kube.Namespace(params.namespace) {
    metadata+: {
      labels+: {
        'openshift.io/cluster-monitoring': 'true',
      },
    },
  },
}
