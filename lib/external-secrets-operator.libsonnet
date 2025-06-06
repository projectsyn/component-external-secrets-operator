/**
 * \file Library with public methods provided by component external-secrets-operator.
 */

local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local SecretStore(name) =
  kube._Object('external-secrets.io/v1', 'SecretStore', name) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
      },
    },
  };

// Export library functions here
{
  SecretStore: SecretStore,
}
