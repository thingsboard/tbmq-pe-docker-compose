#!/bin/bash
#
# ThingsBoard, Inc. ("COMPANY") CONFIDENTIAL
#
# Copyright © 2016-2025 ThingsBoard, Inc. All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains
# the property of ThingsBoard, Inc. and its suppliers,
# if any.  The intellectual and technical concepts contained
# herein are proprietary to ThingsBoard, Inc.
# and its suppliers and may be covered by U.S. and Foreign Patents,
# patents in process, and are protected by trade secret or copyright law.
#
# Dissemination of this information or reproduction of this material is strictly forbidden
# unless prior written permission is obtained from COMPANY.
#
# Access to the source code contained herein is hereby forbidden to anyone except current COMPANY employees,
# managers or contractors who have executed Confidentiality and Non-disclosure agreements
# explicitly covering such access.
#
# The copyright notice above does not evidence any actual or intended publication
# or disclosure  of  this source code, which includes
# information that is confidential and/or proprietary, and is a trade secret, of  COMPANY.
# ANY REPRODUCTION, MODIFICATION, DISTRIBUTION, PUBLIC  PERFORMANCE,
# OR PUBLIC DISPLAY OF OR THROUGH USE  OF THIS  SOURCE CODE  WITHOUT
# THE EXPRESS WRITTEN CONSENT OF COMPANY IS STRICTLY PROHIBITED,
# AND IN VIOLATION OF APPLICABLE LAWS AND INTERNATIONAL TREATIES.
# THE RECEIPT OR POSSESSION OF THIS SOURCE CODE AND/OR RELATED INFORMATION
# DOES NOT CONVEY OR IMPLY ANY RIGHTS TO REPRODUCE, DISCLOSE OR DISTRIBUTE ITS CONTENTS,
# OR TO MANUFACTURE, USE, OR SELL ANYTHING THAT IT  MAY DESCRIBE, IN WHOLE OR IN PART.
#

function compose_version() {
  #Checking whether "set -e" shell option should be restored after Compose version check
  flag_set=false
  if [[ $SHELLOPTS =~ errexit ]]; then
    set +e
    flag_set=true
  fi

  #Checking Compose V1 availability
  docker-compose version >/dev/null 2>&1
  if [ $? -eq 0 ]; then status_v1=true; else status_v1=false; fi

  #Checking Compose V2 availability
  docker compose version >/dev/null 2>&1
  if [ $? -eq 0 ]; then status_v2=true; else status_v2=false; fi

  COMPOSE_VERSION=""

  if $status_v2; then
    COMPOSE_VERSION="V2"
  elif $status_v1; then
    COMPOSE_VERSION="V1"
  else
    echo "Docker Compose plugin is not detected. Please check your environment." >&2
    exit 1
  fi

  echo $COMPOSE_VERSION

  if $flag_set; then set -e; fi
}

set -u

# Define TBMQ versions
old_version="2.2.0"
new_version="2.2.0PE-SNAPSHOT"

# Define TBMQ images
old_image="image: \"thingsboard/tbmq:$old_version\""
new_image="image: \"thingsboard/tbmq-pe:$new_version\""

# Define DB variables
db_url="jdbc:postgresql://postgres:5432/thingsboard_mqtt_broker"
db_username="postgres"
db_password="postgres"
valkey_url="valkey"

COMPOSE_VERSION=$(compose_version) || exit $?
echo "Docker Compose version is: $COMPOSE_VERSION"

docker pull thingsboard/tbmq-pe:$new_version

# Backup the original Docker Compose file
cp docker-compose.yml docker-compose.yml.bak
echo "Docker Compose file backup created: docker-compose.yml.bak"

# Replace the TBMQ image version using sed
echo "Trying to replace the TBMQ image version from [$old_version] to [$new_version]..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sed -i "s#$old_image#$new_image#g" docker-compose.yml
else
  sed -i '' "s#$old_image#$new_image#g" docker-compose.yml
fi

if grep -q "$new_image" docker-compose.yml; then
  echo "TBMQ image line updated in docker-compose.yml with the new version"
else
  echo "Failed to replace the image version. Please, update the version manually and re-run the script"
  exit 1
fi

# Check if .tbmq-upgrade.env is present
# Should contain the following line for the upgrade from CE to PE
# JAVA_TOOL_OPTIONS=-Dinstall.upgrade.from_version=ce
if [ -f ".tbmq-upgrade.env" ]; then
  echo "Found .tbmq-upgrade.env. Proceeding with upgrade..."
else
  echo ".tbmq-upgrade.env not found in current directory. Please create it before running upgrade."
  exit 1
fi

case $COMPOSE_VERSION in
V2)
  docker compose stop tbmq

  postgresContainerName=$(docker compose ps | grep "postgres" | awk '{ print $1 }')

  composeNetworkId=$(docker inspect -f '{{ range .NetworkSettings.Networks }}{{ .NetworkID }}{{ end }}' $postgresContainerName)

  docker run -it --network=$composeNetworkId \
    --env-file .tbmq-upgrade.env \
    -e SPRING_DATASOURCE_URL=$db_url \
    -e SPRING_DATASOURCE_USERNAME=$db_username \
    -e SPRING_DATASOURCE_PASSWORD=$db_password \
    -e REDIS_HOST=$valkey_url \
    -v tbmq-data:/data \
    --rm \
    thingsboard/tbmq-pe:$new_version upgrade-tbmq.sh

  docker compose rm tbmq

  docker compose up -d tbmq --no-deps
  ;;
V1)
  docker-compose stop tbmq

  postgresContainerName=$(docker-compose ps | grep "postgres" | awk '{ print $1 }')

  composeNetworkId=$(docker inspect -f '{{ range .NetworkSettings.Networks }}{{ .NetworkID }}{{ end }}' $postgresContainerName)

  docker run -it --network=$composeNetworkId \
    --env-file .tbmq-upgrade.env \
    -e SPRING_DATASOURCE_URL=$db_url \
    -e SPRING_DATASOURCE_USERNAME=$db_username \
    -e SPRING_DATASOURCE_PASSWORD=$db_password \
    -e REDIS_HOST=$valkey_url \
    -v tbmq-data:/data \
    --rm \
    thingsboard/tbmq-pe:$new_version upgrade-tbmq.sh

  docker-compose rm tbmq

  docker-compose up -d tbmq --no-deps
  ;;
*)
  # unknown option
  ;;
esac
