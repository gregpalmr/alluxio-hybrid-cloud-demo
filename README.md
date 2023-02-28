# alluxio-hybrid-cloud-demo
Spin up an Alluxio hybrid cloud demo environment on AWS

## Background

Alluxio Data Orchestration enables data consumers to access data anyware in the enterprise. Whether the data is in an on-prem storage environment like Hadoop or S3 compatible storage, or in a cloud-based datalake, Alluxio's unified-namespace feature allows Presto, Impala, Drill, Dremio, Spark and Hive users to access remote data without knowing that the data is remote. And Alluxio's memory caching allows those users to access the data at "local data" query speeds.

This git repo contains instructions and artifacts for launching an Alluxio hybrid cloud demo environment.

## Pre-requesites

To use the commands outlined in the repo, you will need the following:

- Terraform CLI installed (version 1.3.9 or greater)
- The git CLI installed (version 2.37.1 or greater)
- The AWS CLI installed (version 2.9.12 or greater)

- Your AWS credentials defined defined in the `~/.aws/credentials`, like this:

     - [default]
     - aws_access_key_id=[AWS ACCESS KEY]
     - aws_secret_access_key=[AWS SECRET KEY]

- You also need IAM role membership and permissions to create the following objects:
     - AWS Key Pairs
     - AWS S3 Buckets
     - EMR clusters
     - EC2 instance types as specfied in the create-cluster command

# Demo Environment Setup Instructions

## Step 1. Open a multi-tabbed terminal window

On Windows, use an SSH terminal client application that can use standard ssh keys.

On MacOS, open an iTerm2 window with create three tabs labled:

- Launch Demo
- ON PREM - STORAGE
- CLOUD - COMPUTE

![Alt text](/images/alluxio-hybrid-cloud-demo-ssh-terminal.png?raw=true "SSH Terminal Tabs")

## Step 2. Clone this git repo

In the "Launch Demo" terminal tab, clone this git repo with the commands:

     git clone https://github.com/gregpalmr/alluxio-hybrid-cloud-demo

     cd alluxio-hybrid-cloud-demo

## Step 3. Create SSH keys

Generate a private and public ssh key for use by the AWS EC2 instances, using this command:

     ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y

## Step 4. Update the Terraform variables file

A Terraform template is used to launch both the on-prem storage and cloud compute portions of the demo environment. For security reasons, the Terraform template specifies which IP addresses can SSH into the various EC2 instances via port 22. You will need to modify the local_ip_as_cidr variable in the terraform.tfvars file to the public IP address for your computer. To get your public ip address use the following commands:

On MacOS:

     echo "local_ip_as_cidr = \"$(curl ifconfig.me)/32\"" >> terraform.tfvars
     
On Windows 10 or Windows 11, point your Web browser to this web page and read your public IPv4 ip address on the upper right side of the page:

     https://www.whatismyip.com
     
Then edit your terraform.tfvars file with the command:

    notepad terraform.tfvars
    
And add the line: 

     local_ip_as_cidr = "< my public ip address >"

## Step 5. Launch the demo environment in AWS

Use the terraform cli to launch the Alluxio demo environment in AWS. Use the command:

     terraform init
     
     terraform apply
     
When both the on-prem and cloud portions of the Alluxio demo environment are launched completely, you will see the public ip addresses of the main cluster nodes for each environment. It will look like this:

     Apply complete! Resources: 46 added, 0 changed, 0 destroyed.

     Outputs:

     alluxio_compute_master_public_dns = "ec2-18-212-208-181.compute-1.amazonaws.com"
     on_prem_master_public_dns = "ec2-54-183-19-251.us-west-1.compute.amazonaws.com"

## Step 6. Load data into the on-prem HDFS storage

NOTE: This step is already executed by the terraform template.

In the "ON PREM" ssh terminal tab, open a shell session on the master node in the on-prem demo environment. Copy the SSH command found on the "Outputs" section displayed at the end of the "terraform apply" command. Use the "ssh_to_ONPREM_master_node" command and run it in this terminal tab, like this:

     ssh hadoop@ec2-54-183-19-251.us-west-1.compute.amazonaws.com
     
Create a new directory in HDFS, using the command:

     hdfs dfs -mkdir -p /data/tpcds/
     
Load data from the tpcds dataset files into HDFS, using the commands:

     s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/store_sales/ --dest hdfs:///data/tpcds/store_sales/
     
     s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/item/ --dest hdfs:///data/tpcds/item/

Create some Hive tables that reference the imported tpcds datasets, using the commands:

     wget https://alluxio-public.s3.amazonaws.com/hybrid-quickstart/create-table.sql
     
     sed -i 's~/tmp/~/data/~g' create-table.sql
     
     hive -f create-table.sql

## Step 7. Setup the Presto queries

In the "CLOUD - COMPUTE" ssh terminal tab, open a shell session on the master node in the cloud demo environment. Copy the SSH command found on the "Outputs" section displayed at the end of the "terraform apply" command. Use the "ssh_to_CLOUD_master_node" command and run it in this terminal tab, like this:

     ssh hadoop@ec2-54-183-19-251.us-east-1.compute.amazonaws.com
  
Download the TPC-DS SQL query to be run in Presto, using the command:

     wget https://alluxio-public.s3.amazonaws.com/hybrid-quickstart/q44.sql
     
Also, create a sorter version of the Q44 query, using the command:

     cat <<EOF > query44-1.sql
     select avg(ss_net_profit) rank_col
       from store_sales
       where ss_store_sk = 4
         and ss_addr_sk is null
       group by ss_store_sk
     limit 10;
     EOF

Run the first iteration of the Q44 SQL query. This Presto query will run against the Alluxio file system before any data has been cached, so it will be slower. Later you will run it again when that cache has been warmed and will compare the times. Use the Presto cli command:

     presto-cli --catalog onprem --schema default < q44.sql

## Step 8. Mount other Alluxio UFSs

This Alluxio demo illustrates the use of Alluxio's unified namespace capability, so we will mount other under stores to use within the unified namespace. Alluxio is already configured with a "root" understore that points to the "on-prem" Hadoop enviornment. So we will mount an S3 under store and a union mount with both S3 and HDFS understores combined in a single mount point.  

Mount the NYC taxi ride public data set as an S3 bucket using the command:

     /opt/alluxio/bin/alluxio fs mount \
          /alluxio_s3_mount/ \
          s3://nyc-tlc/trip\ data/

Mount the "on-prem" HDFS storage environment as an understore. To get the URL to the "on-prem" HDFS Namenode, look at the Alluxio properties file and see how it was used as the root "/" ufs. Use this command:

     grep root.ufs /opt/alluxio/conf/alluxio-site.properties
     alluxio.master.mount.table.root.ufs=hdfs://ip-79-109-9-240.us-west-1.compute.internal:8020/

Mount the "on-prem" HDFS as a separate mount point using the command:

     alluxio fs mount \
	      --option alluxio.underfs.version=hadoop-2.8 \
        /alluxio_hdfs_mount hdfs://hdfs://ip-79-109-9-240.us-west-1.compute.internal:8020/data
        
Finally, create a UNION mount in Alluxio that includes both the S3 and the HDFS under stores. Use this command:

     /opt/alluxio/bin/alluxio fs mount \
	--option alluxio-union.hdfs_mount.uri=hdfs://ip-79-109-9-240.us-west-1.compute.internal:8020/data \
	--option alluxio-union.hdfs_mount.option.alluxio.underfs.version=hadoop-3.2 \
		\
	--option alluxio-union.s3_mount.uri=s3://nyc-tlc/trip\ data/ \
                \
	--option alluxio-union.priority.read=hdfs_mount,s3_mount \
	--option alluxio-union.collection.create=hdfs_mount \
	/alluxio_union_mount union://union_mount_ufs/

## Step 9. Display the Alluxio and Presto Web UIs

Point your web browser to the "cloud compute" cluster's master node and display the Alluxio web UI:

     http://ec2-18-212-208-181.compute-1.amazonaws.com:19999
     
Point your web browser to the "cloud compute" cluster's master node and display the Presto web UI:

     http://ec2-18-212-208-181.compute-1.amazonaws.com:8889

## Step 9. Re-run the Presto TPD-DS Q44 Query

Run the Presto query again, so we can compare the cold cache vs warm cache performance. Use this command on the "CLOUD COMPUTE" shell session:

          presto-cli --catalog onprem --schema default < q44.sql

# Demo Presentation Instructions

## Step 1. Show Alluxio Unified Namespace

TBD

## Step 2. TBD

## Step 3. Setup an Alluxio policy driven data management rule (PDDM)

Copy data from the hdfs_mount to the s3_mount, when a file is older than 1 minute:

     alluxio fs policy add /alluxio_union_mount "migrate_from_hdfs_to_cloud:ufsMigrate(olderThan(1m), UFS[s3_mount]:STORE)"

Copy data from the hdfs_mount to the s3_mount, when a file is older than 3 days:

     alluxio fs policy add /union_mount "migrate_from_hdfs_to_cloud:ufsMigrate(olderThan(3d), UFS[s3_mount]:STORE)"

Copy data from the hdfs_mount to the s3_mount, when a file is unused for 3 days:

     alluxio fs policy add /alluxio_union_mount "migrate_from_hdfs_to_cloud:ufsMigrate(unusedFor(3d), UFS[s3_mount]:STORE)"

Add a new file directly on the UFS (on the ONPREM STORAGE environment)

     hdfs dfs -put /etc/motd hdfs:///tmp/motd2
     hdfs dfs -ls hdfs:///tmp/

On the CLOUD COMPUTE environment, cause Alluxio to do a metadata sync

     alluxio fs loadMetadata /

# Step 4. Manage the policy

See what the initial delay is for new policies (defaults to 5m), 

     alluxio getConf alluxio.policy.scan.initial.delay
     alluxio getConf alluxio.policy.scan.interval

List all policies:

     alluxio fs policy list

Check the status of the s3 policy:

     alluxio fs policy status migrate_from_hdfs_to_cloud

Remove the policy

     alluxio fs policy remove migrate_from_hdfs_to_cloud

Remove the union filesystem mount

     alluxio fs unmount /union_mount

# Destroy the Demo Environment

Use these commands to destroy the demo environment:

     terraform destroy

---

Please direct questions or comments to greg.palmer@alluxio.com
