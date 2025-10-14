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

function create_volume_if_not_exists() {
  local volume_name=$1
  if docker volume inspect "$volume_name" >/dev/null 2>&1; then
    echo "Volume '$volume_name' already exists."
  else
    docker volume create "$volume_name"
    echo "Volume '$volume_name' created."
  fi
}

set -u

# Check if docker-compose.yml is present
if [ -f "docker-compose.yml" ]; then
  echo "docker-compose.yml is already present in the current directory. Skipping download."
else
  echo "docker-compose.yml is absent in the current directory. Downloading the file..."
  wget https://raw.githubusercontent.com/thingsboard/tbmq-pe-docker-compose/release-2.2.0/basic/docker-compose.yml
fi

COMPOSE_VERSION=$(compose_version) || exit $?
echo "Docker Compose version is: $COMPOSE_VERSION"

# Define the string to search for
search_string="thingsboard/tbmq-pe"
# Check if the Docker Compose file contains the search_string
if grep -q "$search_string" docker-compose.yml; then
  echo "The Docker Compose file is ok, checking volumes..."
else
  echo "The Docker Compose file missing tbmq. Seems the file is invalid for tbmq configuration."
  exit 1
fi

create_volume_if_not_exists tbmq-postgres-data
create_volume_if_not_exists tbmq-kafka-data
create_volume_if_not_exists tbmq-kafka-secrets
create_volume_if_not_exists tbmq-kafka-config
create_volume_if_not_exists tbmq-valkey-data
create_volume_if_not_exists tbmq-logs
create_volume_if_not_exists tbmq-data
create_volume_if_not_exists tbmq-ie-logs

echo "Starting TBMQ!"
case $COMPOSE_VERSION in
V2)
  docker compose up -d
  docker compose logs -f
  ;;
V1)
  docker-compose up -d
  docker-compose logs -f
  ;;
*)
  # unknown option
  ;;
esac
