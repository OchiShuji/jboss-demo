variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "availability_zone_1" {
  description = "AZ for the first VPC"
  type        = string
  default     = "ap-northeast-1a"
}

variable "availability_zone_2" {
  description = "AZ for the second VPC"
  type        = string
  default     = "ap-northeast-1c"
}

variable "ami_id" {
  description = "Existing EC2 Key Pair name to attach to the bastion host"
  type        = string
  default = "ami-03598bf9d15814511"
}

locals {
  vpc_cidr         = "10.25.0.0/16"
  public_subnet_1_cidr  = "10.25.1.0/24"
  public_subnet_2_cidr  = "10.25.2.0/24"
  private_subnet_1_cidr  = "10.25.101.0/24"
  private_subnet_2_cidr  = "10.25.102.0/24"
  tags = {
    Service = "jboss_eap_demo"
  }
}
