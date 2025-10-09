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
