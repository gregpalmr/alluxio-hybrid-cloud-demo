#!/bin/bash
#
# SCRIPT: launch-demo.sh
#
# DESCR:  Launch the Alluxio hybrid cloud demo environment in EMR
#

  function show_msg {
    echo " `date +"%D %T"` - ${1} "
  }

  # Automatically destroy the demo environment after certain 
  # number of hours - 2 hours default
  TERMINATE_DEMO_HOURS="2"

  show_msg "Running launch-demo.sh script"

  # Make sure script is running on MacOS or Linux only
  unameOut="$(uname -s)"
  case "${unameOut}" in
    Linux*)     this_os=Linux;;
    Darwin*)    this_os=MacOS;;
    CYGWIN*)    this_os=Cygwin;;
    MINGW*)     this_os=MinGw;;
    *)          this_os="UNKNOWN:${unameOut}"
      show_msg "Error: Running on unknown OS type: \"${this_os}\". Run this script on MacOS or Linux only. Exiting"
      exit -1
  esac
  show_msg "Running on ${this_os}"

  # Check if terraform is installed and correct version
  which terraform &>/dev/null
  if [ "$?" != 0 ]; then
    show_msg "Error: Terraform command is not installed. Please install Terraform v1.3.9 or greater. Exiting."
    exit -1
  fi

  # Check if AWS credentials are configured
  if [ ! -f ~/.aws/credentials ]; then
    show_msg "Error: AWS credentials file not found at \"~/.aws/credentials\".  Please configure AWS credentials. Exiting."
    exit -1
  fi

  # Check if required commands are available
  required_commands="curl nohup ssh-keygen"
  for c in $(echo "$required_commands"); do
    which ${c} &>/dev/null
    if [ "$?" != 0 ]; then
      show_msg "Error: Required \"${c}\" command is not installed. Please install curl command."
      exit_script=true
    fi
  done
  if [ "$exit_script" == "true" ]; then
    show_msg "Exiting."
    exit -1
  fi

  # Make sure current dir is the github repo dir
  original_dir=$(pwd)
  if [[ "$original_dir" == *"alluxio-hybrid-cloud-demo" ]]; then
    show_msg "Running script in correct directory \"alluxio-hybrid-cloud-demo\"."
  else
    show_msg "Error: Current directory is not the correct directory. Must be \"alluxio-hybrid-cloud-demo\". Exiting."
    exit -1
  fi

  # Make sure that the terraform directory is in this current directory
  if [ ! -d ./terraform ]; then
    show_msg "Error: The \"terraform\" sub-directory is not in this current directory. Exiting."
    exit -1
  fi

  # Create an SSH key, if one doesn't already exist
  if [ ! -d ~/.ssh ]; then
       mkdir -p ~/.ssh
  fi
  if [ ! -f ~/.ssh/id_rsa ] || [ ! -f ~/.ssh/id_rsa.pub ];then
    show_msg "Creating public and private SSH key in \"~/.ssh/id_rsa\" and \"~/.ssh/id_rsa.pub\". "
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y &>/dev/null
    if [ "$?" != 0 ]; then
      show_msg "Error: Creating public and private SSH key in \"~/.ssh/id_rsa\" and \"~/.ssh/id_rsa.pub\" failed. Exiting. "
      exit -1
    fi
  else
    show_msg "Public and private SSH keys already exist in \"~/.ssh/id_rsa\" and \"~/.ssh/id_rsa.pub\". Skipping. "
  fi

  # Set the terraform.tfvars variables
  if [ ! -f terraform/terraform.tfvars ]; then
    touch terraform/terraform.tfvars
  fi
  if [ "$this_os" == "MacOS" ]; then
    # delete old cidr
    sed -i '' "/local_ip_as_cidr/d" terraform/terraform.tfvars
    # Add new cidr
    echo "local_ip_as_cidr = \"$(curl --silent ifconfig.me)/32\"" >> terraform/terraform.tfvars
  else
    # delete old cidr
    sed -i "/local_ip_as_cidr/d" terraform/terraform.tfvars
    # Add new cidr
    my_public_ip=$(curl --silent api.ipify.org)
    echo "local_ip_as_cidr = \"${my_public_ip}/32\"" >> terraform/terraform.tfvars
  fi

  # Run the terraform commands
  cd terraform

  show_msg "Running command: \"terraform init\". See terraform/terraform-init.out for results."
  terraform init > terraform-init.out 2>&1
  if [ "$?" != 0 ]; then
    show_msg "Error: Command \"terraform init\" failed to run successfully. Exiting."
    exit -1
  fi

  show_msg "Running command: \"terraform apply\". See terraform/terraform-apply.out for results."
  terraform apply -auto-approve > terraform-apply.out 2>&1
  if [ "$?" != 0 ]; then
    show_msg "Error: Command \"terraform apply\" failed to run successfully. Exiting."
    exit -1
  fi
  show_msg "Command \"terraform apply\" completed."

  # Get the EMR master node IP addresses for the ONPREM and CLOUD clusters
  #
  grep 'Apply complete!' terraform-apply.out &> /dev/null
  if [ "$?" != 0 ]; then
    show_msg "Error: Command \"terraform apply\" failed to run successfully. Exiting."
    exit -1
  fi

  cloud_ip_address_line=$(grep 'ssh_to_CLOUD_master_node = "ssh ' terraform-apply.out)
  cloud_ip_address=$(echo ${cloud_ip_address_line} | cut -d'@' -f 2 | sed 's/"//g')

  onprem_ip_address_line=$(grep '^ssh_to_ONPREM_master_node = "ssh ' terraform-apply.out)
  onprem_ip_address=$(echo ${onprem_ip_address_line} | cut -d'@' -f 2 | sed 's/"//g')
  
  # Check if we can successfully SSH into the master nodes
  response=$(ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address} "echo sshtrue" &>/tmp/ssh-response.out)
  grep sshtrue /tmp/ssh-response.out &> /dev/null
  if [ "$?" != "0" ]; then
    echo
    show_msg "Error: Unable to ssh into ONPREM master node with the command:"
    echo
    show_msg "       ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address}"
    echo
    show_msg "Fix the issue or destroy the demo cluster with the command \"terraform destroy\". "
    show_msg "Exiting."
    exit -1
  fi

  response=$(ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} "echo sshtrue" &>/tmp/ssh-response.out)
  grep sshtrue /tmp/ssh-response.out &> /dev/null
  if [ "$?" != "0" ]; then
    echo
    show_msg "Error: Unable to ssh into CLOUD master node with the command:"
    echo
    show_msg "       ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address}"
    echo
    show_msg "Fix the issue or destroy the demo cluster with the command \"terraform destroy\". "
    show_msg "Exiting."
    exit -1
  fi

  show_msg "The demo EMR master node IP addresses are:"
  show_msg "    ONPREM: ${onprem_ip_address}"
  show_msg "    CLOUD:  ${cloud_ip_address}"
  show_msg "You can SSH into the master nodes with the following commands:"
  show_msg "    ONPREM: ssh hadoop@${onprem_ip_address}"
  show_msg "    CLOUD:  ssh hadoop@${cloud_ip_address}"

  # Load the TPC-DS data sets into the ONPREM Hadoop cluster
  show_msg "Loading the TPC-DS data sets in the ONPREM Hadoop cluster"

  cmd="hdfs dfs -mkdir -p /data/tpcds/"
  ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address} ${cmd} &>/dev/null

  show_msg "Loading store_sales data set"
  cmd="s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/store_sales/ --dest hdfs:///data/tpcds/store_sales/"
  ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address} ${cmd} &>/dev/null

  show_msg "Loading item data set"
  cmd=" s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/item/ --dest hdfs:///data/tpcds/item/"
  ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address} ${cmd} &>/dev/null

  show_msg "Creating hive tables"
  cmd="wget https://raw.githubusercontent.com/gregpalmr/alluxio-hybrid-cloud-demo/main/resources/hive/create-hive-tables.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address} ${cmd} &>/dev/null

  cmd="hive -f create-hive-tables.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address} ${cmd} &>/dev/null
  
  # Check if Hive tables were created successfully and have data
  cmd="hive -e \"SHOW TABLES;\""
  response=$(ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address} ${cmd} 2>/dev/null )

  found1=$(echo "$response" | grep store_sales)
  found2=$(echo "$response" | grep item)
  if [[ "$found1" == *"store_sales"* ]] && [[ "$found2" == *"item"* ]]; then
    show_msg "Hive tables created successfully"
  else
    show_msg "Error: Hive table \"store_sales\" or \"item\" was not created successfully."
    show_msg "Fix the issue or destroy the demo cluster with the command \"terraform destroy\". "
    show_msg "Exiting."
    exit -1
  fi

  echo 
  show_msg "The following URLs will be launched in your web browser."
  show_msg "If you don't see them, open the URLs in your browser:"
  show_msg "     Alluxio UI:      http://${cloud_ip_address}:19999"
  show_msg "     Presto  UI:      http://${cloud_ip_address}:8889"
  show_msg "     Prometheus UI:   http://${cloud_ip_address}:9090"
  show_msg "     Grafana UI:      http://${cloud_ip_address}:3000 - Use admin/admin"
  show_msg "     Spark Master UI: http://${cloud_ip_address}:8080"

  if [ "$this_os" == "MacOS" ]; then
    open http://${cloud_ip_address}:19999
    open http://${cloud_ip_address}:8889
    open http://${cloud_ip_address}:9090
    open http://${cloud_ip_address}:3000
    open http://${cloud_ip_address}:8080
  fi

  # Setup and run the Presto TPC-DS queries
  show_msg "Running the TPC-DS Q44 Presto query in the CLOUD Presto/Alluxio cluster."
  show_msg "This first run will be slow becuase the Alluxio cache is not warmed up yet."

  cmd="wget https://raw.githubusercontent.com/gregpalmr/alluxio-hybrid-cloud-demo/main/resources/presto/tpcds-query-44.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  cmd="presto-cli --catalog onprem --schema default < tpcds-query-44.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  # Mount the S3 bucket in Alluxio in the CLOUD cluster
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null
  cmd="alluxio fs mount /alluxio_s3_mount s3://nyc-tlc"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  # Mount the on-prem HDFS mount in Alluxio in the CLOUD cluster
  cmd="alluxio fs mount --option alluxio.underfs.version=hadoop-2.8 /alluxio_hdfs_mount hdfs://${onprem_ip_address}:8020/data"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} "${cmd} &>/dev/null

  # Mount the Alluxio UNION mount in the CLOUD cluster
  cmd="alluxio fs mount \
			  --option alluxio-union.hdfs_mount.uri=hdfs://${onprem_ip_address}:8020/data \
			  --option alluxio-union.hdfs_mount.option.alluxio.underfs.version=hadoop-2.8 \
			  \
			  --option alluxio-union.s3_mount.uri=s3://nyc-tlc \
                        \
			  --option alluxio-union.priority.read=hdfs_mount,s3_mount \
			  --option alluxio-union.collection.create=hdfs_mount \
			  /alluxio_union_mount union://union_mount_ufs/"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} "${cmd} &>/dev/null"

  # Run the TPC-DS Q44 presto query two more times - to get the Alluxio cache hit rate above 50%
  show_msg "Running the TPC-DS Q44 Presto query two more times, in the CLOUD Presto/Alluxio cluster."
  cmd="presto-cli --catalog onprem --schema default < tpcds-query-44.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null
  sleep 10
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  echo
  #show_msg "The demo cluster will remain up for ${TERMINATE_DEMO_HOURS} hours."
  #echo
  #show_msg "To destroy the cluster manually, press Ctrl-C to exit this script"
  show_msg "To destroy the cluster, and run the command:"
  echo
  show_msg "    terraform destroy -auto-approve "
  echo

  # Wait for 2 hours and then destroy the cluster
  #num_seconds=$((${TERMINATE_DEMO_HOURS}*60))
  #sleep ${num_seconds}

  # finish up the script
  #echo
  #show_msg "Running command: terraform destroy -auto-approve"
  #echo
  #show_msg "See terraform/terraform-destroy.out for results."

  #terraform destroy -auto-approve > terraform-destroy.out 2>&1

  cd ${original_dir}

# end of script
