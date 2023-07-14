#!/bin/bash

while read -r line; do
  echo "$line"
  appli=$(echo $line | cut -d'-' -f1)
  desc=$(echo $line | cut -d'-' -f2)
  if [ -f "${SETTINGS_SOURCE}/includes/dockerapps/vars/${appli,,}.yml" ]; then
    echo "" >>"${SETTINGS_SOURCE}/includes/dockerapps/vars/${appli,,}.yml"
    echo 'description: "'${desc}'"' >>"${SETTINGS_SOURCE}/includes/dockerapps/vars/${appli,,}.yml"
  fi
  if [ -f "${SETTINGS_SOURCE}/includes/dockerapps/${appli,,}.yml" ]; then
    echo "" >>"${SETTINGS_SOURCE}/includes/dockerapps/${appli,,}.yml"
    echo 'description: "'${desc}'"' >>"${SETTINGS_SOURCE}/includes/dockerapps/${appli,,}.yml"
  fi
done <"${SETTINGS_SOURCE}/includes/config/services-available"

while read -r line; do
  echo "$line"
  appli=$(echo $line | cut -d'-' -f1)
  desc=$(echo $line | cut -d'-' -f2)
  if [ -f "${SETTINGS_SOURCE}/includes/dockerapps/vars/${appli,,}.yml" ]; then
    echo "" >>"${SETTINGS_SOURCE}/includes/dockerapps/vars/${appli,,}.yml"
    echo 'description: "'${desc}'"' >>"${SETTINGS_SOURCE}/includes/dockerapps/vars/${appli,,}.yml"
  fi
  if [ -f "${SETTINGS_SOURCE}/includes/dockerapps/${appli,,}.yml" ]; then
    echo "" >>"${SETTINGS_SOURCE}/includes/dockerapps/${appli,,}.yml"
    echo 'description: "'${desc}'"' >>"${SETTINGS_SOURCE}/includes/dockerapps/${appli,,}.yml"
  fi
done <"${SETTINGS_SOURCE}/includes/config/other-services-available"
