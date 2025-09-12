#!/bin/bash
# This script is used to configure the environment of the react native
# application in order to pull the correct values from config.js
#
# See config.js for more information
if [ "$1" == "dev" ]
then
  echo "Configuring app for development"
  FLAVOR="development"
elif [ "$1" == "qa" ]
then
  echo "Configuring app for qa"
  FLAVOR="qa"
elif [ "$1" == "prod" ]
then
  echo "Configuring app for production"
  FLAVOR="production"
else
  echo "Environment argument of \"dev\", \"qa\", or \"prod\" must be provided"
  exit 1
fi
printf "// THIS FILE IS AUTO GENERATED. DO NOT MANUALLY MODIFY. SEE EXECUTABLE 'configure'\nconst env = '$FLAVOR';\nexport default env;\n" > env.js
