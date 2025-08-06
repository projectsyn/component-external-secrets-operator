local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local eso = import 'lib/external-secrets-operator.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.external_secrets_operator;

local namespacedName(name) =
  local parts = std.splitLimit(name, '/', 1);
  if std.length(parts) == 1 then {
    namespace: params.namespace,
    name: parts[0],
  } else {
    namespace: parts[0],
    name: parts[1],
  };

local stores = com.generateResources(
  params.secret_stores,
  function(name)
    local nsName = namespacedName(name);
    eso.SecretStore(nsName.name) {
      metadata+: {
        namespace: nsName.namespace,
      },
    }
);

local clusterstores = com.generateResources(
  params.cluster_secret_stores,
  eso.ClusterSecretStore
);

local external_secrets = com.generateResources(
  params.external_secrets,
  function(name)
    local nsName = namespacedName(name);
    eso.ExternalSecret(nsName.name) {
      metadata+: {
        namespace: nsName.namespace,
      },
    }
);

local ecr_authorization_tokens = com.generateResources(
  params.ecr_authorization_tokens,
  function(name)
    local nsName = namespacedName(name);
    eso.ECRAuthorizationToken(nsName.name) {
      metadata+: {
        namespace: nsName.namespace,
      },
    }
);

local secrets = com.generateResources(params.secrets, kube.Secret);

{
  [if std.length(stores) > 0 then '20_secret_stores']: stores,
  [if std.length(clusterstores) > 0 then '20_cluster_secret_stores']: clusterstores,
  [if std.length(external_secrets) > 0 then '20_external_secrets']: external_secrets,
  [if std.length(ecr_authorization_tokens) > 0 then '20_ecr_authorization_tokens']: ecr_authorization_tokens,
  [if std.length(params.secrets) > 0 then '99_secrets']: secrets,
}
