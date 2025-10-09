#/!/usr/bin/env just

login-azure:
    #!/usr/bin/env bash
    echo "Logging in to Azure..."
    az login \
      --service-principal \
      --username "$AZURE_CLIENT_ID" \
      --password "$AZURE_CLIENT_SECRET" \
      --tenant "$AZURE_TENANT_ID"

deactivate-container-app revision container-app="" resource-group="":
    #!/usr/bin/env bash
    echo "Deactivating: container app revision..."

    # if container-app is empty, use env variable: AZURE_CONTAINER_APP_NAME
    if [ -z "{{container-app}}" ]; then
      container_app="$AZURE_CONTAINER_APP_NAME";
    else
      container_app="{{container-app}}";
    fi;

    # if resourge-group is empty, use env variable: AZURE_RESOURCE_GROUP
    if [ -z "{{resource-group}}" ]; then
      resource_group="$AZURE_RESOURCE_GROUP";
    else
      resource_group="{{resource-group}}";
    fi;

    az containerapp revision deactivate --revision "{{revision}}" \
      --name "$container_app" \
      --resource-group "$resource_group"

restart-container-app revision container-app resource-group:
    #!/usr/bin/env bash
    @echo "Restarting: container app revision..."

    # if container-app is empty, use env variable: AZURE_CONTAINER_APP_NAME
    if [ -z "{{container-app}}" ]; then
      container_app="$AZURE_CONTAINER_APP_NAME";
    else
      container_app="{{container-app}}";
    fi;

    # if resourge-group is empty, use env variable: AZURE_RESOURCE_GROUP
    if [ -z "{{resource-group}}" ]; then
      resource_group="$AZURE_RESOURCE_GROUP";
    else
      resource_group="{{resource-group}}";
    fi;

    az containerapp revision restart --revision "{{revision}}" \
      --name "$container_app" \
      --resource-group "$resource_group"