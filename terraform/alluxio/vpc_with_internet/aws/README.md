# vpc_with_internet module

The vpc_with_internet module creates a VPC that can access the public internet

## Variables

No variables are required by default.

`aws_vpc_cidr` is the CIDR block to create the VPC with.
This needs to be updated if the module is called multiple times to create more than one VPC.

`aws_vpc_subnet` is the CIDR block to create a VPC subnet with.
Since this subnet is created within the created VPC, it must be compatible with the VPC CIDR.

`aws_subnet_zone` is an optional variable to define which availability zone to create resources in.
If not set, a random availability zone within the region will be used.

## Outputs

`vpc_id` is the ID of the created VPC.

`subnet_id` is the ID of the created subnet.

## Tests

Each of these are smoke tested by running terraform in corresponding directory under alluxio_test/
No user input variables are needed but resources will be created.
