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
# Global constants #
####################
readonly HADOOP_CONF="/etc/hadoop/conf"
readonly PRESTO_CONF="/etc/presto/conf"
readonly PRESTO_CONFIG_FILE="${PRESTO_CONF}/config.properties"
readonly PRESTO_HIVE_CATALOG="${PRESTO_CONF}/catalog/hive.properties"
readonly PRESTO_ONPREM_CATALOG="${PRESTO_CONF}/catalog/onprem.properties"
readonly PRESTO_KEYTAB_PATH="${PRESTO_CONF}/presto.keytab"

####################
# Helper functions #
####################

# Run a command as a specific user
# Assumes the provided user already exists on the system and user running script has sudo access
#
# Args:
#   $1: user
#   $2: cmd
doas() {
  if [[ "$#" -ne "2" ]]; then
    echo "Incorrect number of arguments passed into function doas, expecting 2"
    exit 2
  fi
  local user="$1"
  local cmd="$2"

  sudo runuser -l "${user}" -c "${cmd}"
}

# Downloads a file to the local machine into the cwd
# For the given scheme, uses the corresponding tool to download:
# s3://   -> aws s3 cp
# gs://   -> gsutil cp
# default -> wget
#
# Args:
#   $1: uri - S3, GS, or HTTP(S) URI to download from
download_file() {
  if [[ "$#" -ne "1" ]]; then
    echo "Incorrect number of arguments passed into function download_file, expecting 1"
    exit 2
  fi
  local uri="$1"

  if [[ "${uri}" == s3://* ]]; then
    aws s3 cp "${uri}" ./
  elif [[ "${uri}" == gs://* ]]; then
    gsutil cp "${uri}" ./
  else
    wget -nv "${uri}"
  fi
}

# Appends or replaces a property KV pair to the presto config.properties
#
# Args:
#   $1: property
#   $2: value
set_presto_config_properties() {
  if [[ "$#" -ne "2" ]]; then
    echo "Incorrect number of arguments passed into function set_alluxio_property, expecting 2"
    exit 2
  fi
  local property="$1"
  local value="$2"

  if grep -qe "^\s*${property}" ${PRESTO_CONFIG_FILE} 2> /dev/null; then
    sudo sed -i "s;${property}.*;${property}=${value};g" "${PRESTO_CONFIG_FILE}"
    echo "Property ${property} already exists in ${PRESTO_CONFIG_FILE} and is replaced with value ${value}" >&2
  else
    echo "${property}=${value}" | sudo tee -a "${PRESTO_CONFIG_FILE}"
  fi
}

# Appends or replaces a property KV pair to the alluxio-site.properties file
#
# Args:
#   $1: property
#   $2: value
set_presto_onprem_property() {
  if [[ "$#" -ne "2" ]]; then
    echo "Incorrect number of arguments passed into function set_alluxio_property, expecting 2"
    exit 2
  fi
  local property="$1"
  local value="$2"

  if grep -qe "^\s*${property}" ${PRESTO_ONPREM_CATALOG} 2> /dev/null; then
    sudo sed -i "s;${property}.*;${property}=${value};g" "${PRESTO_ONPREM_CATALOG}"
    echo "Property ${property} already exists in ${PRESTO_ONPREM_CATALOG} and is replaced with value ${value}" >&2
  else
    echo "${property}=${value}" | sudo tee -a "${PRESTO_ONPREM_CATALOG}"
  fi
}

# Waits for PrestoServer process to be running for up to 5 minutes
wait_for_presto() {
  local -r presto_process_name="PrestoServer"
  count=0
  presto_pid="-1"
  while ! sudo jps | grep "${presto_pid} ${presto_process_name}"; do
    sleep 5
    # each java process, grouped by user, stores their pids in /tmp/hsperfdata_<user>
    set +e
    pid=$(sudo ls /tmp/hsperfdata_presto)
    set -e
    # only set presto_pid if pid exists
    if [[ "${pid}" != "" ]]; then
      presto_pid="${pid}"
    fi
    echo "Found pid for ${presto_process_name}: ${presto_pid}"
    if [[ "${count}" -eq 60 ]]; then
      echo "Waited for presto to be up for 5 minutes. Continuing assuming it will not be running"
      return
    fi
    ((count=count+1))
  done
}

#################
# Main function #
#################
main() {
    print_help() {
    local -r USAGE=$(cat <<USAGE_END

Usage: presto-emr.sh
                      [-c <configure_alluxio_shim>]
                      [-f <file_uri>]
                      [-k <kerberos_type>]
                      [-r <kerberos_configuration_map>]
                      [-u <hms_uri>]

presto-emr.sh is a script which can be used to configure Presto in an AWS EMR
cluster with Alluxio.

This script is able to configure Presto with Kerberos. This option is enabled
by the values for [-k <kerberos_type>] and [-r <kerberos_configuration_map>]
are provided.

  -c                Flag to configure Presto to use Alluxio's transparent URI

  -f                An s3:// or http(s):// URI to any remote file. This property
                    can be specified multiple times. Any file specified through
                    this property will be downloaded and stored with the same
                    name to ${PRESTO_CONF}/alluxioConf/

  -k                The type of Kerberos authentication to configure for

  -m                A JSON encoded mapping of Kerberos configuration entries

  -u                Hive metastore URI. If unset, defaults to
                    "thrift://{EMR_MASTER_HOSTNAME}:9083"

For any value of -k, the following configuration entries are expected:

  default_realm             Kerberos default realm, needed for defining the full
                            Kerberos principal value in various properties files.

  kdc_admin_password        KDC admin password string, needed for creating Kerberos
                            principals.

USAGE_END
)
    echo -e "${USAGE}" >&2
    exit 1
  }

  # ordered alphabetically by flag character
  local configure_alluxio_shim="false"
  local execute_synchronous="false"
  local files_list=""
  local hms_uri=""

  # kerberos arguments
  local kerberos_type=""
  local kerberos_configuration_map="{}"

  # c, e, and h are boolean flags, the others expect arguments
  while getopts "ehcf:k:m:u:" option; do
    OPTARG=$(echo -e "${OPTARG}" | tr -d '[:space:]')
    case "${option}" in
      e)
        # reserved flag for launching the script asynchronously
        execute_synchronous="true"
        ;;
      h)
        print_help 0
        ;;

      c)
        configure_alluxio_shim="true"
        ;;
      f)
        # URIs to http(s)/s3 URIs should be URL encoded, so a space delimiter
        # works without issue.
        files_list+=" ${OPTARG}"
        ;;
      k)
        kerberos_type="${OPTARG}"
        ;;
      m)
        kerberos_configuration_map="${OPTARG}"
        ;;
      u)
        hms_uri="${OPTARG}"
        ;;
      *)
        print_help 1
        ;;
    esac
  done

  # extract kerberos configuration values from map, returning an empty string if key does not exist
  local -r kdc_admin_password=$(echo "${kerberos_configuration_map}" | jq -r '.kdc_admin_password // empty')
  local -r default_realm=$(echo "${kerberos_configuration_map}" | jq -r '.default_realm // empty')

  # self-invoke script as background task
  # this allows EMR to continue installing and launching applications
  # the script will wait until Presto processes are running before continuing
  if [[ ${execute_synchronous} == "false" ]]; then
    echo "Launching background process"
    launch_args="$0 -e"
    # iterate through each provided argument and replace characters that need escaping
    # this is necessary to properly wrap the json value of a flag
    # otherwise the json content will not be passed correctly into the background process
    input_args=( "$@" )
    for i in "${input_args[@]}"; do
      # forcibly escape the three characters " { }
      esc_i=$(echo "${i}" | sed 's/"/\\"/g' | sed 's/{/\\{/g' | sed 's/}/\\}/g')
      launch_args="${launch_args} ${esc_i}"
    done
    bash -c "$launch_args" &
    exit 0
  fi
  echo "Executing synchronous"

  # collect instance information
  local -r local_hostname=$(hostname -f)
  local -r is_master=$(jq '.isMaster' /mnt/var/lib/info/instance.json)

  # determine master hostname, different if on master vs worker
  local master
  if [[ "${is_master}" == "true" ]]; then
    master="${local_hostname}"
  else
    master=$(jq '.masterHost' /mnt/var/lib/info/extraInstanceData.json | sed -e 's/^"//' -e 's/"$//' | nslookup | awk '/name/{print substr($NF,1,length($NF)-1)}')
  fi

  # if hms_uri is unset, assume Hive resides in EMR cluster master
  if [[ -z "${hms_uri}" ]]; then
    hms_uri="thrift://${master}:9083"
  fi

  # wait until presto process is running
  echo "Waiting for processes to start before starting script"
  wait_for_presto

  # download files provided by "-f" to ${PRESTO_CONF}/alluxioConf/
  sudo mkdir -p "${PRESTO_CONF}/alluxioConf"
  IFS=" " read -ra files_to_be_downloaded <<< "${files_list}"
  if [ "${#files_to_be_downloaded[@]}" -gt "0" ]; then
    echo "Downloading files into ${PRESTO_CONF}/alluxioConf/}"
    local filename
    for file in "${files_to_be_downloaded[@]}"; do
      filename="$(basename "${file}")"
      download_file "${file}"
      sudo mv "${filename}" "${PRESTO_CONF}/alluxioConf/${filename}"
    done
    sudo chown -R presto:presto "${PRESTO_CONF}/alluxioConf/"
  fi

  echo "Starting Presto configuration"
  # onprem catalog is created for hybrid use cases
  # onprem catalog may be configured with onprem hdfs/hive, kerberos, alluxio shim based on user inputs
  # the original hive catalog is left untouch
  echo "Copying ${PRESTO_HIVE_CATALOG} to ${PRESTO_ONPREM_CATALOG}"
  sleep 10
  if [ -f xxx]; then
    sudo cp "${PRESTO_HIVE_CATALOG}" "${PRESTO_ONPREM_CATALOG}"
  else
    echo "Error: Presto hive catalog file \"${PRESTO_HIVE_CATALOG}\" does not exist. Creating file \"${PRESTO_ONPREM_CATALOG}\" manually."
    cat <<EOF | sudo tee ${PRESTO_ONPREM_CATALOG}
hive.metastore-refresh-interval=1m
connector.name=hive-hadoop2
hive.metastore-cache-ttl=20m
hive.config.resources=/etc/hadoop/conf/core-site.xml,/etc/hadoop/conf/hdfs-site.xml
hive.non-managed-table-writes-enabled = true
hive.s3-file-system-type = EMRFS
hive.hdfs.impersonation.enabled = true
hive.metastore.uri = thrift://ip-XX-XXX-X-XXX.ec2.internal:9083
EOF
  fi

  set_presto_onprem_property hive.hdfs.impersonation.enabled "true"
  set_presto_onprem_property hive.metastore.uri "${hms_uri}"
  set_presto_onprem_property hive.split-loader-concurrency "100"

  # core-site.xml and hdfs-site.xml downloaded from the file list will override the default one
  core_site_path="${PRESTO_CONF}/alluxioConf/core-site.xml"
  hdfs_site_path="${PRESTO_CONF}/alluxioConf/hdfs-site.xml"
  if [[ ! -f "${core_site_path}" ]]; then
    sudo cp "${HADOOP_CONF}/core-site.xml" "${core_site_path}"
  fi
  if [[ ! -f "${hdfs_site_path}" ]]; then
    sudo cp "${HADOOP_CONF}/hdfs-site.xml" "${hdfs_site_path}"
  fi
  set_presto_onprem_property hive.config.resources "${core_site_path},${hdfs_site_path}"

  if [[ "${configure_alluxio_shim}" == "true" ]]; then
    sudo sed -i 's=<configuration>=<configuration>\n  <property>\n    <name>fs.hdfs.impl</name>\n    <value>alluxio.hadoop.ShimFileSystem</value>\n  </property>\n  <property>\n    <name>fs.AbstractFileSystem.hdfs.impl</name>\n    <value>alluxio.hadoop.AlluxioShimFileSystem</value>\n  </property>\n=g' ${core_site_path}
  fi

  if [[ "${kerberos_type}" != "" ]]; then
    # Connect Presto to secure HMS and HDFS
    sudo /usr/bin/kadmin -p kadmin/admin -w "${kdc_admin_password}" -q "addprinc -randkey presto/${local_hostname}"
    sudo /usr/bin/kadmin -p kadmin/admin -w "${kdc_admin_password}" -q "ktadd -k ${PRESTO_KEYTAB_PATH} presto/${local_hostname}"
    sudo chown presto:presto "${PRESTO_KEYTAB_PATH}"
    sudo chmod 600 "${PRESTO_KEYTAB_PATH}"

    set_presto_onprem_property hive.metastore.authentication.type "KERBEROS"
    hms_address="${hms_uri#thrift://}"
    hms_dns=${hms_address%%:*}
    set_presto_onprem_property hive.metastore.service.principal "hive/${hms_dns}@${default_realm}"
    set_presto_onprem_property hive.metastore.client.principal "presto/_HOST@${default_realm}"
    set_presto_onprem_property hive.metastore.client.keytab "${PRESTO_KEYTAB_PATH}"

    set_presto_onprem_property hive.hdfs.authentication.type "KERBEROS"
    set_presto_onprem_property hive.hdfs.presto.principal "presto/_HOST@${default_realm}"
    set_presto_onprem_property hive.hdfs.presto.keytab "${PRESTO_KEYTAB_PATH}"

    # Enable Kerberos for Presto
    set_presto_config_properties http-server.http.enabled "false"
    set_presto_config_properties internal-communication.kerberos.enabled "true"
    set_presto_config_properties http-server.authentication.type "KERBEROS"
    set_presto_config_properties http.server.authentication.krb5.service-name "presto"
    set_presto_config_properties http.server.authentication.krb5.keytab "${PRESTO_KEYTAB_PATH}"
    set_presto_config_properties http.authentication.krb5.config "/etc/krb5.conf"

    # connect Presto to secure Alluxio
    sudo sed -i "s=</configuration>=  <property>\n    <name>alluxio.security.kerberos.client.principal</name>\n    <value>presto/${local_hostname}@${default_realm}</value>\n  </property>\n  <property>\n    <name>alluxio.security.kerberos.client.keytab.file</name>\n    <value>${PRESTO_KEYTAB_PATH}</value>\n  </property>\n</configuration>=g" ${core_site_path}
  fi

  # Restart Presto cluster
  if command -v systemctl > /dev/null; then
    sudo systemctl stop presto-server || true  # would fail if presto was not already running
    sudo systemctl start presto-server
  else
    sudo initctl stop presto-server || true  # would fail if presto was not already running
    sudo initctl start presto-server
  fi

  echo "Presto bootstrap complete!"
}

main "$@"
