# emr module

The emr module creates EMR cluster

## Variables

### Required variables

`aws_security_group_id` is the ID of the security group to assign to the instances created by EMR.

`aws_subnet_id` is the ID of the subnet to create instances in.

### Optional variables

`aws_key_pair_name` is the name of an existing key pair to assign to instances in order to SSH.

`applications` is a list of application names to install and deploy on the cluster.

`bootstrap_actions` is a list of bootstrap actions to execute after installation.
A bootstrap action consists of a path, name, and optionally a list of arguments.

`kerberos_enabled` is a boolean to determine if kerberos should be enabled for the cluster.
This must be set to true for the subsequent 2 kerberos/security variables to take effect.

`emr_security_configuration_string` is the string to set for the configuration field of the
`aws_emr_security_configuration` resource. This is an output of the `kerberos_config` module.

`kerberos_configuration` is a map(string) representing the configuration values for kerberos.
This is an output of the `kerberos_config` module.

## Outputs

`hadoop_master_public_dns` is the master instance's public DNS.
This can be used to SSH into the master instance, in the format of:
`ssh -i /path/to/private/key hadoop@hadoop_master_public_dns`
where the private key could be your own private key if the EC2 key pair was created from your public key,
or a key pair pem file if using an existing key pair.

`hadoop_master_private_dns` is the master instance's private DNS.

## Tests

Each of these are smoke tested by running terraform in corresponding directory under alluxio_test/
No user input variables are needed but resources will be created.
