# alluxio-hybrid-cloud-demo
Spin up an Alluxio hybrid cloud demo environment on AWS

## Background

Alluxio Data Orchestration enables data consumers to access data anywhere in the enterprise. Whether the data is in an on-prem storage environment like Hadoop or S3 compatible storage, or in a cloud-based data lake, Alluxio's unified-namespace feature allows Presto, Impala, Drill, Dremio, Spark and Hive users to access remote data without knowing that the data is remote. And Alluxio's memory caching allows those users to access the data at "local data" query speeds.

This git repo contains instructions and artifacts for launching an Alluxio hybrid cloud demo environment.

## Prerequisites

To use the commands outlined in the repo, you will need the following:

- Terraform CLI installed (version 1.3.9 or greater)
- The git CLI installed (version 2.37.1 or greater)
- The AWS CLI installed (version 2.9.12 or greater)

- Your AWS credentials defined defined in the `~/.aws/credentials`, like this:

```
     [default]
     aws_access_key_id=[AWS ACCESS KEY]
     aws_secret_access_key=[AWS SECRET KEY]
```

- You also need IAM role membership and permissions to create the following objects:
     - AWS Key Pairs
     - AWS S3 Buckets
     - EMR clusters
     - EC2 instance types as specified in the terraform template

- The AWS IAM roles to attach to your user (represented by your IAM access keys) should include:

     - IAMFullAccess
     - AmazonEC2FullAccess 
     - AmazonEMRFullAccessPolicy_v2
     - AmazonEMRServicePolicy_v2
     - AmazonS3FullAccess

If you find that you get errors because you have exceeded your quotas for the EC2 instance types (r4.4xlarge and r5d.4xlarge by default), you can open a support ticket with Amazon and ask for increased quotas.

# Demo Environment Setup Instructions

## Step 1. Open a multi-tabbed terminal window

On Windows, use an SSH terminal client application that can use standard ssh keys.

On MacOS, open an iTerm2 window with create three tabs labeled:

- Launch Demo
- ON PREM - STORAGE
- CLOUD - COMPUTE

![Alt text](/images/alluxio-hybrid-cloud-demo-ssh-terminal.png?raw=true "SSH Terminal Tabs")

## Step 2. Clone this git repo

In the "Launch Demo" terminal tab, clone this git repo with the commands:

     git clone https://github.com/gregpalmr/alluxio-hybrid-cloud-demo

     cd alluxio-hybrid-cloud-demo

## Step 3. Launch the demo clusters

The Alluxio hybrid-cloud demo launches two EMR clusters, one that represents an ON-PREM data center, running Hadoop and an HDFS data store, and another EMR cluster that represents the CLOUD environment running user workloads such as Presto and Spark with Alluxio acting as the local data provider.

The following diagram illustrates the demo environment:

![Alt text](/images/alluxio-hybrid-cloud-demo-emr-env.png?raw=true "Alluxio Hybrid Cloud Demo Environment")

First, make sure your AWS CLI commands work with your AWS credentials (in ~/.aws/credentials). Make sure the following commands work:

     aws sts get-caller-identity --output json

     aws s3 ls /

If these commands work, proceed. If not, follow the AWS CLI setup steps show in:

     https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

Use the provided launch-demo.sh script to launch the demo environment. Run the command:

     scripts/launch-demo.sh

If you get any "Error" messages during the "terraform apply" command phase, check the output file to view the error messages:

     cat terraform-apply.out

or

     cat terraform/terraform-apply.out

# Demo Presentation Instructions

## Step 1. Show the Alluxio Unified Namespace feature

In the Alluxio Web UI, click on the "Browse" tab at the top of the page. 

Show the "alluxio_s3_mount" directory and the "alluxio_hdfs_mount" directory and talk about how Alluxio can mount multiple data stores at the same time. 

Then show the "alluxio_union_mount" directory and show how data sets from heterogeneous data stores can be merged into a "unified namespace", so that end-users don't have to know where the data is actually stored.

## Step 2. Show how Alluxio improves performance of Presto queries

During the demo setup procedure above, The TPC-DS Q44 Presto query was run against Alluxio three times. 

In the Presto UI, show how the first run of the query took longer because it was against a "cold" cache environment. Enable viewing of completed jobs, by clicking on the "Finished" jobs filter button. 

Then scroll down to the bottom of the listing and show the first Q44 job results and show that it took about 3 minutes and 30 seconds (3.5 mins). 

Then scroll up a little, and show the second Q44 job and show that it took about 2 minutes and 30 seconds (2.5 mins) and state that it was faster because the Presto job did not have to get all the data from the "on-prem" data center, but was able to read Alluxio's cached data in the same cloud region as the Presto servers.

To reinforce that, display the Alluxio Web UI and in the "Overview" page show that about 60 GB of data was cached after the first run of the Presto query. Also show the "Workers" page and show that each Alluxio worker node cached some of that data, about equal amounts of it. Bring up the Grafana UI (log in with admin/admin) and show the "Cache Hit Rate" dashboard panel that shows that over 50% of the data was read from cache storage.

Talk about how Alluxio also supports pre-loading data into cache storage in advance of end-user data access requests. 

Also talk about how Alluxio supports pinning data so that it remains in the cache forever or for a specified amount of time which supports popular data sets that may be used consistently.

Finally, talk about how Alluxio supports time-to-live (TTL) attributes that can cause data to be cached for a certain amount of time (1 day for instance), and then the data can be automatically purged from the cached, and even deleted from the understore as well.

## Step 3. Show how Alluxio improves performance of Spark jobs too 

TBD

## Step 4. Show how Alluxio caches metadata as well

Talk about how Alluxio cached metadata and can update metadata on a schedule (every 5 minutes by default) or in an on-demand fashion.

Show metadata caching and refreshing with these steps:

In the "CLOUD - COMPUTE" ssh session, run a Presto query against the small example "students" table:

     presto-cli --catalog onprem --schema default --execute "select * from students;"

Show the results of the query and then modify the table in the on-prem environment. In the "ON-PREM STORAGE" ssh session, update the "students" table with the command:

     hive -e "insert overwrite table students values ('fred flintstone', 32), ('barney rubble', 32);"

and show the contents of the updated table with the command:

     hive -e "select * from students;"

Now, go back to the "ON-PREM STORAGE" ssh session and re-run the Presto query with the command:

     presto-cli --catalog onprem --schema default --execute "select * from students;"

It should show the out-dated contents of the Hive table.

Now, have Alluxio update the metadata. In the "ON-PREM STORAGE" ssh session, run the command:

     alluxio fs loadMetadata -R -F /data/

Finally, re-run the Presto query to show the updated data. In the "ON-PREM STORAGE" ssh session, run the command:

     presto-cli --catalog onprem --schema default --execute "select * from students;"

## Step 5. Discuss Alluxio's policy driven data management (PDDM) capabilities

TBD

Copy data from the hdfs_mount to the s3_mount, when a file is older than 1 minute:

     alluxio fs policy add /alluxio_union_mount "migrate_from_hdfs_to_cloud:ufsMigrate(olderThan(1m), UFS[s3_mount]:STORE)"

Copy data from the hdfs_mount to the s3_mount, when a file is older than 3 days:

     alluxio fs policy add /alluxio_union_mount "migrate_from_hdfs_to_cloud:ufsMigrate(olderThan(3d), UFS[s3_mount]:STORE)"

Copy data from the hdfs_mount to the s3_mount, when a file is unused for 3 days:

     alluxio fs policy add /alluxio_union_mount "migrate_from_hdfs_to_cloud:ufsMigrate(unusedFor(3d), UFS[s3_mount]:STORE)"

Add a new file directly on the UFS (on the ONPREM STORAGE environment)

     hdfs dfs -put /etc/motd hdfs:///tmp/motd2
     hdfs dfs -ls hdfs:///tmp/

On the CLOUD COMPUTE environment, cause Alluxio to do a metadata sync

     alluxio fs loadMetadata /

## Step 6. Show how Alluxio manages the PDDM policies

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

     alluxio fs unmount /alluxio_union_mount

---

# (Optional) Manually launch demo environment

## Step 1. Create SSH keys

Generate a private and public ssh key for use by the AWS EC2 instances, using this command:

     ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y

## Step 2. Update the Terraform variables file

A Terraform template is used to launch both the on-prem storage and cloud compute portions of the demo environment. For security reasons, the Terraform template specifies which IP addresses can SSH into the various EC2 instances via port 22. You will need to modify the local_ip_as_cidr variable in the terraform.tfvars file to the public IP address for your computer. To get your public ip address use the following commands:

On MacOS:

     echo "local_ip_as_cidr = \"$(curl ifconfig.me)/32\"" >> terraform.tfvars
     
On Windows 10 or Windows 11, point your Web browser to this web page and read your public IPv4 ip address on the upper right side of the page:

     https://www.whatismyip.com
     
Then edit your terraform.tfvars file with the command:

    notepad terraform.tfvars
    
And add the line: 

     local_ip_as_cidr = "< my public ip address >"

If you are simply experimenting with this demo environment and don't need to use larger, more expensive EC2 instance types, then you can modify the EC2 instance types used by the Terraform templates. Run the following grep command to see what files must be modified to use different EC2 instances.

     grep -R xlarge
     
     ./main.tf:  on_prem_master_instance_type = "r4.4xlarge"
     ./main.tf:  on_prem_worker_instance_type = "r4.4xlarge"
     ./main.tf:  compute_master_instance_type = "r4.4xlarge"
     ./main.tf:  compute_worker_instance_type = "r5d.4xlarge"
     ./alluxio/alluxio_cloud_cluster/aws/variables_emr.tf:    instance_type   = "r4.xlarge"
     ./alluxio/alluxio_cloud_cluster/aws/variables_emr.tf:    instance_type   = "r4.xlarge"
     ./alluxio/cloud_cluster/aws/variables_emr.tf:    instance_type   = "r4.xlarge"
     ./alluxio/cloud_cluster/aws/variables_emr.tf:    instance_type   = "r4.xlarge"

Modify the following files to use smaller instance types such as r4.2xlarge, r4.xlarge, r5d.2xlarge or r5d.xlarge:

     ./main.tf
     ./alluxio/alluxio_cloud_cluster/aws/variables_emr.tf
     ./alluxio/cloud_cluster/aws/variables_emr.tf
     
## Step 3. Launch the demo environment in AWS

Use the terraform cli to launch the Alluxio demo environment in AWS. Use the command:

     terraform init
     
     terraform apply -auto-approve
     
When both the on-prem and cloud portions of the Alluxio demo environment are launched completely, you will see the public ip addresses of the main cluster nodes for each environment. It will look like this:

     Apply complete! Resources: 48 added, 0 changed, 0 destroyed.
     
     Outputs:
     
     ssh_to_CLOUD_master_node = "ssh hadoop@ec2-3-84-155-183.compute-1.amazonaws.com"
     ssh_to_ONPREM_master_node = "ssh hadoop@ec2-54-176-16-121.us-west-1.compute.amazonaws.com"

## Step 4. Load data into the on-prem HDFS storage

In the "ON PREM" ssh terminal tab, open a shell session on the master node in the on-prem demo environment. Copy the SSH command found on the "Outputs" section displayed at the end of the "terraform apply" command. Use the "ssh_to_ONPREM_master_node" command and run it in this terminal tab, like this:

     ssh hadoop@ec2-54-183-19-251.us-west-1.compute.amazonaws.com
     
Create a new directory in HDFS, using the command:

     hdfs dfs -mkdir -p /data/tpcds/
     
Load data from the tpcds dataset files into HDFS, using the commands:

     s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/store_sales/ --dest hdfs:///data/tpcds/store_sales/

and:
     
     s3-dist-cp --src s3a://autobots-tpcds-pregenerated-data/spark/unpart_sf100_10k/item/ --dest hdfs:///data/tpcds/item/

Create the Hive tables that reference the imported tpcds datasets, using the commands:

     wget https://raw.githubusercontent.com/gregpalmr/alluxio-hybrid-cloud-demo/main/resources/hive/create-hive-tables.sql     

     hive -f create-hive-tables.sql

## Step 5. Setup the Presto queries

In the "CLOUD - COMPUTE" ssh terminal tab, open a shell session on the master node in the cloud demo environment. Copy the SSH command found on the "Outputs" section displayed at the end of the "terraform apply" command. Use the "ssh_to_CLOUD_master_node" command and run it in this terminal tab, like this:

     ssh hadoop@ec2-3-84-155-183.compute-1.amazonaws.com
  
Download the TPC-DS SQL query to be run in Presto, using the command:

     wget https://raw.githubusercontent.com/gregpalmr/alluxio-hybrid-cloud-demo/main/resources/presto/tpcds-query-44.sql
     
Run the first iteration of the TPC/DS Q44 SQL query. This Presto query will run against the Alluxio file system before any data has been cached, so it will be slower. Later you will run it again when that cache has been warmed and will compare the times. Use the Presto cli command:

     presto-cli --catalog onprem --schema default < tpcds-query-44.sql

## Step 6. Mount other Alluxio UFSs

This Alluxio demo illustrates the use of Alluxio's unified namespace capability, so we will mount other under stores to use within the unified namespace. Alluxio is already configured with a "root" understore that points to the "on-prem" Hadoop environment. So we will mount an S3 under store and a union mount with both S3 and HDFS understores combined in a single mount point.  

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

## Step 7. Display the Alluxio and Presto Web UIs

Point your web browser to the "cloud compute" cluster's master node and display the Alluxio web UI:

     http://ec2-18-212-208-181.compute-1.amazonaws.com:19999
     
Point your web browser to the "cloud compute" cluster's master node and display the Presto web UI:

     http://ec2-18-212-208-181.compute-1.amazonaws.com:8889

## Step 8. Display the Grafana monitoring Web UI

Point your web browser to the "cloud compute" cluster's master node and display the Grafana web UI:

     http://ec2-18-212-208-181.compute-1.amazonaws.com:3000

## Step 9. Re-run the Presto TPD-DS Q44 Query

Run the Presto query again, so we can compare the cold cache vs warm cache performance. Use this command on the "CLOUD COMPUTE" shell session:

          presto-cli --catalog onprem --schema default < tpcds-query-44.sql


## Destroy the Demo Environment

Use these commands to destroy the demo environment:

     terraform destroy -auto-approve

---
TODO:

- Added YARN resource manager Web ui
- Get prometheus scrape rule to include Alluxio worker nodes

---

Please direct questions or comments to greg.palmer@alluxio.com
