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

restart-container-app revision container-app="" resource-group="":
    #!/usr/bin/env bash
    echo "Restarting: container app revision..."

    # if container-app is empty, use env variable: AZURE_CONTAINER_APP_NAME
    if [ -z "{{container-app}}" ]; then
      container_app="$AZURE_CONTAINER_APP_NAME";
    else
      container_app="{{container-app}}";
    fi;

    # if resource-group is empty, use env variable: AZURE_RESOURCE_GROUP
    if [ -z "{{resource-group}}" ]; then
      resource_group="$AZURE_RESOURCE_GROUP";
    else
      resource_group="{{resource-group}}";
    fi;

    az containerapp revision restart --revision "{{revision}}" \
      --name "$container_app" \
      --resource-group "$resource_group"

update-container-app-revision container-app revision-target image-tag resource-group revision-suffix="":
    #!/usr/bin/env bash
    set -euo pipefail

    container_app="{{container-app}}"
    revision_target="{{revision-target}}"
    image_tag="{{image-tag}}"
    resource_group="{{resource-group}}"
    revision_suffix="{{revision-suffix}}"
    env_lines="${AZURE_CONTAINER_APP_ENV_VARS:-}"

    if [ -z "$container_app" ]; then
      echo "container-app argument is required" >&2
      exit 1
    fi

    if [ -z "$revision_target" ]; then
      echo "revision-target argument is required" >&2
      exit 1
    fi

    if [ -z "$image_tag" ]; then
      echo "image-tag argument is required" >&2
      exit 1
    fi

    if [ -z "$resource_group" ]; then
      echo "resource-group argument is required" >&2
      exit 1
    fi

    echo "Updating container app revision '$revision_target' with image '$image_tag'..."

    mapfile -t env_args < <(printf '%s' "$env_lines" | sed '/^\s*$/d')

    cmd=(
      az containerapp revision copy
      --name "$container_app"
      --resource-group "$resource_group"
      --from-revision "$revision_target"
      --image "$image_tag"
      --output json
    )

    if [ -n "$revision_suffix" ]; then
      cmd+=(--revision-suffix "$revision_suffix")
    fi

    if [ ${#env_args[@]} -gt 0 ]; then
      cmd+=(--set-env-vars "${env_args[@]}")
    fi

    revision_json="$(${cmd[@]})"
    new_revision="$(printf '%s' "$revision_json" | jq -r '.name')"

    if [ -z "$new_revision" ] || [ "$new_revision" = "null" ]; then
      echo "Failed to determine new revision name" >&2
      exit 1
    fi

    echo "Created revision: $new_revision"

    if [ -n "${GITHUB_OUTPUT:-}" ]; then
      printf 'revision_name=%s\n' "$new_revision" >> "$GITHUB_OUTPUT"
    fi

exec-container-app revision command container-app="" resource-group="":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -z "{{container-app}}" ]; then
      container_app="$AZURE_CONTAINER_APP_NAME";
    else
      container_app="{{container-app}}";
    fi;

    # if resource-group is empty, use env variable: AZURE_RESOURCE_GROUP or AZURE_RESOURCE_GROUP_NAME
    if [ -z "{{resource-group}}" ]; then
      if [ -n "$AZURE_RESOURCE_GROUP_NAME" ]; then
        resource_group="$AZURE_RESOURCE_GROUP_NAME";
      else
        resource_group="$AZURE_RESOURCE_GROUP";
      fi;
    else
      resource_group="{{resource-group}}";
    fi;

    az containerapp exec \
      --revision "{{revision}}" \
      --name "$container_app" \
      --resource-group "$resource_group" \
      --command "{{command}}"

create-azure-ci-service-principal app-name resource-groups:
    #!/usr/bin/env bash
    set -euo pipefail

    app_name="{{app-name}}"
    resource_groups_input="{{resource-groups}}"

    if [ -z "$app_name" ]; then
      echo "app-name argument is required" >&2
      exit 1
    fi

    if [ -z "$resource_groups_input" ]; then
      echo "resource-groups argument is required (comma-delimited)" >&2
      exit 1
    fi

    echo "Resolving app registration '$app_name'..."
    app_id="$(az ad app list --display-name "$app_name" --query "[0].appId" -o tsv)"

    if [ -z "$app_id" ]; then
      echo "Creating app registration '$app_name'..."
      app_id="$(az ad app create --display-name "$app_name" --query appId -o tsv)"
    else
      echo "App registration '$app_name' already exists (appId: $app_id)."
    fi

    if az ad sp show --id "$app_id" >/dev/null 2>&1; then
      echo "Service principal already exists for appId $app_id."
    else
      echo "Creating service principal for appId $app_id..."
      az ad sp create --id "$app_id" >/dev/null
    fi

    secret_name="ci-sp-$(date +%s)"
    echo "Creating client secret '$secret_name'..."
    password="$(az ad app credential reset --id "$app_id" --display-name "$secret_name" --query password -o tsv)"

    if [ -z "$password" ]; then
      echo "Failed to create a client secret for appId $app_id" >&2
      exit 1
    fi

    subscription_id="$(az account show --query id -o tsv)"
    tenant_id="$(az account show --query tenantId -o tsv)"
    display_name="$(az ad sp show --id "$app_id" --query displayName -o tsv)"

    IFS=',' read -r -a rg_array <<< "$resource_groups_input"

    for rg in "${rg_array[@]}"; do
      trimmed="$(echo "$rg" | xargs)"
      if [ -z "$trimmed" ]; then
        continue
      fi

      scope="/subscriptions/$subscription_id/resourceGroups/$trimmed"
      echo "Ensuring Owner role on resource group '$trimmed' (scope: $scope)..."

      existing_json="$(az role assignment list \
        --assignee "$app_id" \
        --scope "$scope" \
        --query "[?roleDefinitionName=='Owner']" \
        -o json)"

      existing_compact="$(printf '%s' "$existing_json" | tr -d '[:space:]')"

      if [ -z "$existing_compact" ] || [ "$existing_compact" = "[]" ]; then
        az role assignment create \
          --assignee "$app_id" \
          --role Owner \
          --scope "$scope" \
          >/dev/null
        echo "Assigned Owner role on '$trimmed'."
      else
        echo "Owner role already assigned on '$trimmed'; skipping."
      fi
    done

    printf '{\n'
    printf '  "appId": "%s",\n' "$app_id"
    printf '  "displayName": "%s",\n' "$display_name"
    printf '  "password": "%s",\n' "$password"
    printf '  "tenant": "%s"\n' "$tenant_id"
    printf '}\n'

assign-owner-to-resource-group object-id resource-group="":
    #!/usr/bin/env bash
    set -euo pipefail

    assignee_object_id="{{object-id}}"
    resource_group_input="{{resource-group}}"
    subscription_id="${AZURE_SUBSCRIPTION_ID:-}"

    if [ -z "$assignee_object_id" ]; then
      echo "object-id argument is required" >&2
      exit 1
    fi

    if [ -z "$resource_group_input" ]; then
      if [ -n "${AZURE_RESOURCE_GROUP:-}" ]; then
        resource_group_input="$AZURE_RESOURCE_GROUP"
      else
        echo "resource-group argument is required when AZURE_RESOURCE_GROUP is not set" >&2
        exit 1
      fi
    fi

    if [ -z "$subscription_id" ]; then
      echo "AZURE_SUBSCRIPTION_ID environment variable is required" >&2
      exit 1
    fi

    scope="/subscriptions/$subscription_id/resourceGroups/$resource_group_input"
    echo "Ensuring Owner role for object '$assignee_object_id' on resource group '$resource_group_input'..."

    existing_json="$(az role assignment list \
      --assignee-object-id "$assignee_object_id" \
      --scope "$scope" \
      --query "[?roleDefinitionName=='Owner']" \
      -o json)"

    existing_compact="$(printf '%s' "$existing_json" | tr -d '[:space:]')"

    if [ -z "$existing_compact" ] || [ "$existing_compact" = "[]" ]; then
      az role assignment create \
        --assignee-object-id "$assignee_object_id" \
        --role Owner \
        --scope "$scope" \
        >/dev/null
      echo "Assigned Owner role on resource group '$resource_group_input'."
    else
      echo "Owner role already assigned; nothing to do."
    fi

test-azure-ci-service-principal app-id client-secret tenant:
    #!/usr/bin/env bash
    set -euo pipefail

    app_id="{{app-id}}"
    client_secret="{{client-secret}}"
    tenant="{{tenant}}"

    if [ -z "$app_id" ]; then
      echo "app-id argument is required" >&2
      exit 1
    fi

    if [ -z "$client_secret" ]; then
      echo "client-secret argument is required" >&2
      exit 1
    fi

    if [ -z "$tenant" ]; then
      echo "tenant argument is required" >&2
      exit 1
    fi

    logout() {
      az logout --username "$app_id" >/dev/null 2>&1 || true
    }
    trap logout EXIT

    echo "Attempting service principal login..."
    az login \
      --service-principal \
      --username "$app_id" \
      --password "$client_secret" \
      --tenant "$tenant" \
      >/dev/null

    echo "Login succeeded. Active context:"
    az account show \
      --query '{subscriptionId:id, name:name, tenantId:tenantId, user:user.name}' \
      -o json
