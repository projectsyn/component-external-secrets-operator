/**
 * \file Library with public methods provided by component external-secrets-operator.
 */

local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local argo_meta = {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
    },
  },
};

local SecretStore(name) =
  kube._Object('external-secrets.io/v1', 'SecretStore', name) +
  argo_meta;

local ClusterSecretStore(name) =
  kube._Object('external-secrets.io/v1', 'ClusterSecretStore', name) +
  argo_meta;

local ExternalSecret(name) =
  kube._Object('external-secrets.io/v1', 'ExternalSecret', name) +
  argo_meta;

local ECRAuthorizationToken(name) =
  kube._Object('generators.external-secrets.io/v1alpha1', 'ECRAuthorizationToken', name) +
  argo_meta;

{
  SecretStore: SecretStore,
  ClusterSecretStore: ClusterSecretStore,
  ExternalSecret: ExternalSecret,
  ECRAuthorizationToken: ECRAuthorizationToken,

}
