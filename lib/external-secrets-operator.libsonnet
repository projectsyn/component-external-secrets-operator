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

local generator(kind, name) =
  kube._Object('generators.external-secrets.io/v1alpha1', kind, name) +
  argo_meta;

local SecretStore(name) =
  kube._Object('external-secrets.io/v1', 'SecretStore', name) +
  argo_meta;

local ClusterSecretStore(name) =
  kube._Object('external-secrets.io/v1', 'ClusterSecretStore', name) +
  argo_meta;

local ExternalSecret(name) =
  kube._Object('external-secrets.io/v1', 'ExternalSecret', name) +
  argo_meta;

local ECRAuthorizationToken(name) = generator('ECRAuthorizationToken', name);

{
  SecretStore: SecretStore,
  ClusterSecretStore: ClusterSecretStore,
  ExternalSecret: ExternalSecret,
  ECRAuthorizationToken: ECRAuthorizationToken,
  _Generator: generator,
}
