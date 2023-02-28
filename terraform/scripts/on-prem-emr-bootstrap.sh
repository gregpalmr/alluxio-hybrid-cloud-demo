#!/usr/bin/env bash
#
# The Alluxio Open Foundation licenses this work under the Apache License, version 2.0
# (the "License"). You may not use this work except in compliance with the License, which is
# available at www.apache.org/licenses/LICENSE-2.0
#
# This software is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied, as more fully set forth in the License.
#
# See the NOTICE file distributed with this work for information regarding copyright ownership.
#

set -eux

####################
# Helper functions #
####################
# Waits for the corresponding hadoop process to be running
wait_for_hadoop_master() {
  hadoop_process_name="NameNode"
  hdfs_pid="-1"
  while ! sudo jps | grep "${hdfs_pid} ${hadoop_process_name}"; do
    sleep 5
    # each java process, grouped by user, stores their pids in /tmp/hsperfdata_<user>
    set +e
    pid=$(sudo ls /tmp/hsperfdata_hdfs)
    set -e
    # only set hdfs_pid if pid exists
    if [[ "${pid}" != "" ]]; then
      hdfs_pid="${pid}"
    fi
    echo "Found pid for ${hadoop_process_name}: ${hdfs_pid}"
  done
}

#################
# Main function #
#################
main() {
    print_help() {
    local -r USAGE=$(cat <<USAGE_END

Usage: on-prem-emr-bootstrap.sh <s3_uri_upload_path>

on-prem-emr-bootstrap.sh is the bootstrap script of the on-prem emr cluster.

  <s3_uri_upload_path>    (Required) A s3:// URI to upload on-prem configuration files to

USAGE_END
)
    echo -e "${USAGE}" >&2
    exit 1
  }

  if [[ "$#" -lt "1" ]]; then
    echo -e "No S3 URI upload path provided"
    print_help 1
  fi

  local upload_path="${1}"
  shift

  local execute_synchronous="false"
    # e and h are boolean flags, the others expect arguments
  while getopts "b:d:ef:hi:k:n:p:r:s:u:v:" option; do
    OPTARG=$(echo -e "${OPTARG}" | tr -d '[:space:]')
    case "${option}" in
      e)
        # reserved flag for launching the script asynchronously
        execute_synchronous="true"
        ;;
      *)
        print_help 1
        ;;
    esac
  done

  # add alluxio and hdfs users to hdfs supergroup hadoop
  id -u alluxio &>/dev/null || sudo useradd alluxio
  sudo usermod -a -G hadoop alluxio
  id -u hdfs &>/dev/null || sudo useradd hdfs
  sudo usermod -a -G hadoop hdfs

  local -r is_master=$(jq '.isMaster' /mnt/var/lib/info/instance.json)
  if [[ "${is_master}" != "true" ]];then
    exit 0
  fi

  # self-invoke script as background task
  # this allows EMR to continue installing and launching applications
  # the script will wait until HDFS processes are running before continuing
  if [[ ${execute_synchronous} == "false" ]]; then
    echo "Launching background process"
    # note the root_ufs_uri needs to be manually added
    # because shift removes it from the arguments array
    bash -c "$0 ${upload_path} $* -e" &
    exit 0
  fi
  echo "Executing synchronous"

  wait_for_hadoop_master
  sudo cp /etc/hadoop/conf/core-site.xml /home/hadoop/core-site.xml
  sudo cp /etc/hadoop/conf/hdfs-site.xml /home/hadoop/hdfs-site.xml
  aws s3 cp /home/hadoop/core-site.xml ${upload_path}/core-site.xml
  aws s3 cp /home/hadoop/hdfs-site.xml ${upload_path}/hdfs-site.xml

  if [[ "${is_master}" == "true" ]];then
    echo "Loading tpcds data into hdfs"
    sleep 5
    hdfs dfs -mkdir -p /data/tpcds/
    sleep 2
    nohup s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/store_sales/ --dest hdfs:///data/tpcds/store_sales/ > /tmp/s3-dist-cp-store-sales.log 2>&1 &
    
    nohup s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/item/ --dest hdfs:///data/tpcds/item/ > /tmp/s3-dist-cp-item.log 2>&1 &

    echo "Creating Hive tables"
    sleep 30
    wget https://alluxio-public.s3.amazonaws.com/hybrid-quickstart/create-table.sql
    sed -i 's~/tmp/~/data/~g' create-table.sql
    hive -f create-table.sql
  fi

}

main "$@"
