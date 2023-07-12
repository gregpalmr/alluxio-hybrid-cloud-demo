#!/bin/bash
#
# SCRIPT: launch-demo.sh
#
# DESCR:  Launch the Alluxio hybrid cloud demo environment in EMR
#
# USAGE: bash scripts/launch-demo.sh <this computer's public ip address>
#

  # Colors to use with terminal output
  GREEN=$'\e[0;32m'
  RED=$'\e[0;31m'
  NC=$'\e[0m'

  function show_msg {
    echo " `date +"%D %T"` - ${1} "
  }

  function show_msg_green {
    show_msg "${GREEN}${1}${NC}"
  }

  function show_err {
    show_msg "${RED}*** ${1}${NC} "
  }

  function exit_script {
    show_err
    show_err "Exiting."
    cd ..
    show_err ""
    show_err "  To destroy the cluster, and run the command:"
    show_err ""
    show_err "    cd terraform; terraform destroy -auto-approve; cd .."
    show_err ""
    exit -1
  }

  # Get the user supply public IP address to use with the AWS security group ingres rules
  if [ "$1" != "" ]; then
    user_supplied_public_ip_address=$1
    if [[ ! $user_supplied_public_ip_address =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      show_err "Error: Argument 1 was supplied as: $user_supplied_public_ip_address."
      show_err "       It should be a valid 4 part IP address like: 210.46.59.123"
      exit_script
    fi
  fi

  show_msg "Running launch-demo.sh script"

  # Make sure script is running on MacOS or Linux only
  unameOut="$(uname -s)"
  case "${unameOut}" in
    Linux*)     this_os=Linux;;
    Darwin*)    this_os=MacOS;;
    CYGWIN*)    this_os=Cygwin;;
    MINGW*)     this_os=MinGw;;
    *)          this_os="UNKNOWN:${unameOut}"
      show_err "Error: Running on unknown OS type: \"${this_os}\". Run this script on MacOS or Linux only. "
      exit_script
  esac
  show_msg "Running on ${this_os}"

  # Check if terraform is installed and correct version
  which terraform &>/dev/null
  if [ "$?" != 0 ]; then
    show_err "Error: Terraform command is not installed. Please install Terraform v1.3.9 or greater. "
    exit_script
  fi

  # Check if AWS credentials are configured
  if [ ! -f ~/.aws/credentials ]; then
    show_err "Error: AWS credentials file not found at \"~/.aws/credentials\".  Please configure AWS credentials. "
    exit_script
  fi

  # Check if required commands are available
  required_commands="curl nohup ssh-keygen"
  for c in $(echo "$required_commands"); do
    which ${c} &>/dev/null
    if [ "$?" != 0 ]; then
      show_err "Error: Required \"${c}\" command is not installed. Please install curl command."
      exit_script=true
    fi
  done
  if [ "$exit_script" == "true" ]; then
    exit_script
  fi

  # Make sure current dir is the github repo dir
  original_dir=$(pwd)
  if [[ "$original_dir" == *"alluxio-hybrid-cloud-demo" ]]; then
    show_msg "Running script in correct directory \"alluxio-hybrid-cloud-demo\"."
  else
    show_err "Error: Current directory is not the correct directory. Must be \"alluxio-hybrid-cloud-demo\". "
    exit_script
  fi

  # Make sure that the terraform directory is in this current directory
  if [ ! -d ./terraform ]; then
    show_err "Error: The \"terraform\" sub-directory is not in this current directory. "
    exit_script
  fi

  # Create an SSH key, if one doesn't already exist
  if [ ! -d ~/.ssh ]; then
       mkdir -p ~/.ssh
  fi
  if [ ! -f ~/.ssh/id_rsa ] || [ ! -f ~/.ssh/id_rsa.pub ];then
    show_msg "Creating public and private SSH key in \"~/.ssh/id_rsa\" "
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y &>/dev/null
    if [ "$?" != 0 ]; then
      show_err "Error: Creating public and private SSH key in \"~/.ssh/id_rsa\" failed.  "
      exit_script
    fi
  else
    show_msg "Public and private SSH keys already exist in \"~/.ssh/id_rsa\". Skipping. "
  fi

  # Set the terraform.tfvars variables
  if [ ! -f terraform/terraform.tfvars ]; then
    touch terraform/terraform.tfvars
  fi


  # If the user supplied an argument to this script with the public ip address, use it.
  if [ "$user_supplied_public_ip_address" != "" ]; then
    this_public_ip=$user_supplied_public_ip_address
  else
    # Check if we can get this computer's public IP address
    if [ "$this_os" == "MacOS" ]; then
      this_public_ip=$(curl --silent ifconfig.me)
    else
      this_public_ip=$(curl --silent api.ipify.org)
    fi
    # If the ip address is not valid, exit with message
    if [[ ! $this_public_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        show_err "Error: Could not get a valid public IP address for this computer."
        show_err "Got: $this_public_ip"
        show_err ""
        show_err "Please supply your PUBLIC IP address as an argument to this script and try again."
        exit_script
    fi
  fi

  # Remove the old local_ip_as_cidr setting in the file
  if [ "$this_os" == "MacOS" ]; then
    sed -i '' '/local_ip_as_cidr/d' terraform/terraform.tfvars
  else
    sed -i '/local_ip_as_cidr/d' terraform/terraform.tfvars
  fi

  # Add the new entry
  echo "local_ip_as_cidr = \"$this_public_ip/32\"" >> terraform/terraform.tfvars

  # Run the terraform commands
  cd terraform

  show_msg "Running command: \"terraform init\". See terraform/terraform-init.out for results."
  terraform init > terraform-init.out 2>&1
  if [ "$?" != 0 ]; then
    show_err "Error: Command \"terraform init\" failed to run successfully."
    show_err "       Showing tail end of terraform/terraform-init.out:"
    tail -n 10 terraform-init.out
    exit_script
  fi

  show_msg "Running command: \"terraform apply\". See terraform/terraform-apply.out for results."
  terraform apply -auto-approve > terraform-apply.out 2>&1
  if [ "$?" != 0 ]; then
    show_err "Error: Command \"terraform apply\" failed to run successfully."
    show_err "       Showing tail end of terraform/terraform-apply.out:"
    tail -n 10 terraform-apply.out
    exit_script
  fi
  show_msg "Command \"terraform apply\" completed."

  # Get the EMR master node IP addresses for the ONPREM and CLOUD clusters
  #
  grep 'Apply complete!' terraform-apply.out &> /dev/null
  if [ "$?" != 0 ]; then
    show_err "Error: Command \"terraform apply\" failed to run successfully."
    show_err "       Showing tail end of terraform/terraform-apply.out:"
    tail -n 10 terraform-apply.out
    exit_script
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
    show_err "Error: Unable to ssh into ONPREM master node with the command:"
    show_err "       ssh -o StrictHostKeyChecking=no hadoop@${onprem_ip_address}"
    show_err "Fix the issue or destroy the demo cluster with the command \"terraform destroy\". "
    exit_script
  fi

  response=$(ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} "echo sshtrue" &>/tmp/ssh-response.out)
  grep sshtrue /tmp/ssh-response.out &> /dev/null
  if [ "$?" != "0" ]; then
    show_err "Error: Unable to ssh into CLOUD master node with the command:"
    show_err "       ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address}"
    show_err "Fix the issue or destroy the demo cluster with the command \"terraform destroy\". "
    exit_script
  fi

  show_msg "The demo EMR master node IP addresses are:"
  show_msg "    ONPREM: ${onprem_ip_address}"
  show_msg "    CLOUD:  ${cloud_ip_address}"
  show_msg_green "You can SSH into the master nodes with the following commands:"
  show_msg_green "    ONPREM: ssh hadoop@${onprem_ip_address}"
  show_msg_green "    CLOUD:  ssh hadoop@${cloud_ip_address}"

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
    show_err "Error: Hive table \"store_sales\" or \"item\" was not created successfully."
    show_err "Fix the issue or destroy the demo cluster with the command \"terraform destroy\". "
    exit_script
  fi

  show_msg "The following URLs will be launched in your web browser."
  show_msg "If you don't see them, open the URLs in your browser:"
  show_msg "     Alluxio UI:       http://${cloud_ip_address}:19999"
  show_msg "     Presto  UI:       http://${cloud_ip_address}:8889"
  show_msg "     Grafana UI:       http://${cloud_ip_address}:3000 - Use admin/admin"
  show_msg "     Zeppelin UI:      http://${cloud_ip_address}:8890"
  show_msg "     Spark History UI: http://${cloud_ip_address}:18080"
  show_msg "     Yarn RM UI:       http://${cloud_ip_address}:8088"

  if [ "$this_os" == "MacOS" ]; then
    open http://${cloud_ip_address}:19999
    open http://${cloud_ip_address}:8889
    open http://${cloud_ip_address}:3000
    open http://${cloud_ip_address}:8890
    open http://${cloud_ip_address}:18080
    open http://${cloud_ip_address}:8088
  fi

  # Setup and run the Presto TPC-DS queries
  show_msg "Running the TPC-DS Q44 Presto query in the CLOUD Presto/Alluxio cluster."
  show_msg "This first run will be slow because the Alluxio cache is not warmed up yet."

  cmd="wget https://raw.githubusercontent.com/gregpalmr/alluxio-hybrid-cloud-demo/main/resources/presto/tpcds-query-44.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  cmd="presto-cli --catalog onprem --schema default < tpcds-query-44.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  # Create an S3 bucket to use with the demo S3 mount
  this_user=$(echo $USER)
  if [ "$this_user" != "" ]; then
    s3_demo_bucket=${this_user}-alluxio-demo-bucket
  else
    s3_demo_bucket=unknown_user-alluxio-demo-bucket
  fi
  response1=$(aws s3api create-bucket --acl private --region us-east-1 --bucket "${s3_demo_bucket}")

  # Check to make sure the bucket was created
  aws s3 ls / | grep "${s3_demo_bucket}" &>/dev/null
  if [ "$?" -eq "1" ]; then
    if [[ "$response1" != *"BucketAlreadyExists"* ]]; then
         show_msg "S3 Bucket \"${s3_demo_bucket}\" already exists. Using existing bucket"
    else
      show_err "Error: Unable to create the demo S3 bucket: ${s3_demo_bucket}."
      show_err "       Message: $response1"
      exit_script
    fi
  fi

  # Mount the S3 bucket in Alluxio in the CLOUD cluster
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null
  cmd="alluxio fs mount /alluxio_s3_mount s3://${s3_demo_bucket}"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  # Load NYC taxi ride data into demo S3 bucket
  show_msg "Loading NYC taxi ride data set into demo S3 bucket"
  cmd="s3-dist-cp --src s3a://nyc-tlc/trip\ data/ --dest s3a://${s3_demo_bucket}/nyc_taxi/ "
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  # Mount the on-prem HDFS mount in Alluxio in the CLOUD cluster
  cmd="alluxio fs mount --option alluxio.underfs.version=hadoop-2.8 /alluxio_hdfs_mount hdfs://${onprem_ip_address}:8020/data"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} "${cmd}" &>/dev/null

  # Mount the Alluxio UNION mount in the CLOUD cluster
  cmd="alluxio fs mount \
			  --option alluxio-union.hdfs_mount.uri=hdfs://${onprem_ip_address}:8020/data \
			  --option alluxio-union.hdfs_mount.option.alluxio.underfs.version=hadoop-2.8 \
			  \
			  --option alluxio-union.s3_mount.uri=s3://${s3_demo_bucket} \
                        \
			  --option alluxio-union.priority.read=hdfs_mount,s3_mount \
			  --option alluxio-union.collection.create=hdfs_mount \
			  /alluxio_union_mount union://union_mount_ufs/"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} "${cmd} &>/dev/null"

  # Run the TPC-DS Q44 presto query two more times - to get the Alluxio cache hit rate above 50%
  show_msg "Running the TPC-DS Q44 Presto query two more times, in the CLOUD Presto/Alluxio cluster."
  sleep 20
  cmd="presto-cli --catalog onprem --schema default < tpcds-query-44.sql"
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null
  sleep 50
  ssh -o StrictHostKeyChecking=no hadoop@${cloud_ip_address} ${cmd} &>/dev/null

  show_msg ""

  # finish up the script

  cd ${original_dir}

  show_msg_green "launch-demo.sh script completed"
  show_msg_green ""
  show_msg_green "DON'T FORGET TO DESTROY YOUR CLUSTERS WHEN DONE!"
  show_msg_green ""
  show_msg_green "  To destroy the cluster, and run the command:"
  show_msg_green ""
  show_msg_green "    cd terraform; terraform destroy -auto-approve; cd .. "
  show_msg_green ""

# end of script
