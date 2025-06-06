local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

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

{
  [if std.length(stores) > 0 then '20_secret_stores']: stores,
}
