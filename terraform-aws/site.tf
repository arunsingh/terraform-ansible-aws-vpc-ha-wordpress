# Provider public cloud specific
provider "aws" {
    region = "${var.aws_region}"
}

# Variables for VPC module
module "vpc_subnets" {
	source = "./modules/vpc_subnets"
	name = "cleo"
	environment = "dev"
	enable_dns_support = true
	enable_dns_hostnames = true
	vpc_cidr = "172.16.0.0/16"
        public_subnets_cidr = "172.16.10.0/24,172.16.20.0/24"
        private_subnets_cidr = "172.16.30.0/24,172.16.40.0/24"
        azs    = "ap-southeast-1a,ap-southeast-1b"
}

module "ssh_sg" {
	source = "./modules/ssh_sg"
	name = "cleo"
	environment = "dev"
	vpc_id = "${module.vpc_subnets.vpc_id}"
	source_cidr_block = "0.0.0.0/0"
}

module "web_sg" {
	source = "./modules/web_sg"
	name = "cleo"
	environment = "dev"
	vpc_id = "${module.vpc_subnets.vpc_id}"
	source_cidr_block = "0.0.0.0/0"
}

module "elb_sg" {
	source = "./modules/elb_sg"
	name = "cleo"
	environment = "dev"
	vpc_id = "${module.vpc_subnets.vpc_id}"
}

module "rds_sg" {
    source = "./modules/rds_sg"
    name = "cleo"
    environment = "dev"
    vpc_id = "${module.vpc_subnets.vpc_id}"
    security_group_id = "${module.web_sg.web_sg_id}"
}

module "ec2key" {
	source = "./modules/ec2key"
	key_name = "cleo"
	public_key = "ssh-dss AAAAB3NzaC1kc3MAAACBAPSMmmBrUEiGB33P3mQNUUFJkxKO3jdmKRh3+ivJMCd4V0dUWOdT5Qixg5/+/vvz2ispxq7AsWOb3IUP/Bj0zugBBFP0HCNoV3LoSBymb78HgOpJN8qxCUYPUrI6P0i+J/LtMsqxsFWrebFr5RnzFiPDGvSnD8KRqQc9ivXHPx/BAAAAFQDK61xWL5rJyAvtFn7RuOJ0Sq5kDwAAAIEAgnPBVipA/smVOoQ/GJFRYRywFbZmiq8ECTaw8hBs0RNgPJTn4Jiq1fMeXpadMbOg3TY36LpaniqQQn/6kxh7xw8swJohAVN7u28zkXHEdMrsvwx07/weuMYQOhlj5oJ0tLN8+rDqeV9NiCrfcToQMv1XtIvuf5R/cVDjSfeNRfcAAACBAM2dmyO3grfBPlW/mKcQk3Ag97JE1hvzqtAsnhFhXWkS3LAqDuiT62QQi8+XxhxlP9gxl0fvf6Ko/9R2IIGVtih91p7kDi5ZDFzranDrYsaXxtSjm9Bz1Xv4fELyA9iJ19wkXUfc+GGn9H++RuwWFtxY4obvAYXqmusHUmp4mp+j arunsingh.in@gmail.com"
}

module "ec2" {
	source = "./modules/ec2"
	name = "cleo"
	environment = "dev"
	server_role = "web"
	ami_id = "ami-9b8c0bf8"
	key_name = "${module.ec2key.ec2key_name}"
	count = "2"
	security_group_id = "${module.ssh_sg.ssh_sg_id},${module.web_sg.web_sg_id}"
	subnet_id = "${module.vpc_subnets.public_subnets_id}"
	instance_type = "t2.nano"
	user_data = "#!/bin/bash\napt-get -y update\napt-get -y install nginx\n"
}

module "rds" {
	source = "./modules/rds"
	name = "cleo"
	environment = "dev"
	storage = "5"
	engine_version = "5.6.27"
	db_name = "wordpress"
	username = "root"
	password = "${var.rds_password}"
	security_group_id = "${module.rds_sg.rds_sg_id}"
	subnet_ids = "${module.vpc_subnets.private_subnets_id}"
}

module "elb" {
	source = "./modules/elb"
	name = "cleo"
	environment = "dev"
	security_groups = "${module.elb_sg.elb_sg_id}"
	availability_zones = "ap-southeast-1a,ap-southeast-1b"
	subnets = "${module.vpc_subnets.public_subnets_id}"
	instance_id = "${module.ec2.ec2_id}"
}

module "route53" {
	source = "./modules/route53"
	hosted_zone_id = "${var.hosted_zone_id}"
	domain_name = "${var.domain_name}"
	elb_address = "${module.elb.elb_dns_name}"
	elb_zone_id = "${module.elb.elb_zone_id}"

}
