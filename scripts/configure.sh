#!/bin/bash
# This script is used to configure the environment of the react native
# application in order to pull the correct values from config.js
#
# See config.js for more information

ARG="$1"

case "$ARG" in
  dev|development|develop)
    echo "Configuring app for development"
    FLAVOR="development"
    ;;
  qa|staging|stage)
    echo "Configuring app for qa"
    FLAVOR="qa"
    ;;
  prod|production|prd)
    echo "Configuring app for production"
    FLAVOR="production"
    ;;
  *)
    echo "Environment argument of \"dev\", \"qa\", or \"prod\" must be provided"
    echo "Aliases accepted: development, develop, staging, stage, production, prd"
    exit 1
    ;;
esac
printf "// THIS FILE IS AUTO GENERATED. DO NOT MANUALLY MODIFY. SEE EXECUTABLE 'configure'\nconst env = '$FLAVOR';\nexport default env;\n" > env.js
