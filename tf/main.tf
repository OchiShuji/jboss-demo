terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.67.0"
    }
  }

  required_version = ">= 1.4.2"
}

provider "aws" {
  default_tags {
    tags = local.tags
  }
}

data "aws_ec2_managed_prefix_list" "allow_list_ingress" {
    filter {
        name = "prefix-list-name"
        values = ["allow_list_ingress"]
    }
}

### S3 Bucket ############################################################

resource "random_pet" "suffix" {}

resource "aws_s3_bucket" "data" {
  bucket        = "jboss-eap-demo-${random_pet.suffix.id}"
  force_destroy = true
}


### VPC  #######################################################

resource "aws_vpc" "vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "jboss_eap_demo_vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jboss_eap_demo_igw"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.public_subnet_1_cidr
  availability_zone       = var.availability_zone_1
  tags = {
    Name = "jboss_eap_demo_public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.public_subnet_2_cidr
  availability_zone       = var.availability_zone_2
  tags = {
    Name = "jboss_eap_demo_public_subnet_2"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jboss_eap_demo_public_rt"
  }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_1_assoc" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnet_1.id
}

resource "aws_route_table_association" "public_2_assoc" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnet_2.id
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.private_subnet_1_cidr
  availability_zone       = var.availability_zone_1
  tags = {
    Name = "jboss_eap_demo_private_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.private_subnet_2_cidr
  availability_zone       = var.availability_zone_2
  tags = {
    Name = "jboss_eap_demo_private_subnet_2"
  }
}

resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.vpc.id
    tags = {
    Name = "jboss_eap_demo_private_rt"
  }
}

resource "aws_route_table_association" "private_1_assoc" {
  route_table_id = aws_route_table.private_rt.id
  subnet_id      = aws_subnet.private_subnet_1.id
}

resource "aws_route_table_association" "private_2_assoc" {
  route_table_id = aws_route_table.private_rt.id
  subnet_id      = aws_subnet.private_subnet_2.id
}

### Security Group  ################################################
resource "aws_security_group" "sg_alb" {
  name = "sg_alb"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jboss_eap_demo_sg_alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_alb_ingress" {
  security_group_id = aws_security_group.sg_alb.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  prefix_list_id = data.aws_ec2_managed_prefix_list.allow_list_ingress.id
}

resource "aws_vpc_security_group_egress_rule" "sg_alb_egress" {
  security_group_id = aws_security_group.sg_alb.id
  from_port = 0
  to_port = 65335
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_security_group" "sg_ec2_public" {
  name = "sg_ec2_public_ec2"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "sg_ec2_public_ingress_1" {
  security_group_id = aws_security_group.sg_ec2_public.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  referenced_security_group_id = aws_security_group.sg_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "sg_ec2_public_ingress_2" {
  security_group_id = aws_security_group.sg_ec2_public.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  prefix_list_id = data.aws_ec2_managed_prefix_list.allow_list_ingress.id
}

resource "aws_vpc_security_group_ingress_rule" "sg_ec2_public_ingress_3" {
  security_group_id = aws_security_group.sg_ec2_public.id
  from_port = 0
  to_port = 65335
  ip_protocol = "tcp"
  referenced_security_group_id = aws_security_group.sg_vpc_endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "sg_ec2_public_egress" {
  security_group_id = aws_security_group.sg_ec2_public.id
  from_port = 0
  to_port = 65335
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_security_group" "sg_alb_internal" {
  name = "sg_alb_internal"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jboss_eap_demo_sg_alb_internal"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_alb_internal_ingress_1" {
  security_group_id = aws_security_group.sg_alb_internal.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  referenced_security_group_id = aws_security_group.sg_ec2_public.id
}

resource "aws_vpc_security_group_egress_rule" "sg_alb_internal_egress" {
  security_group_id = aws_security_group.sg_alb_internal.id
  from_port = 0
  to_port = 65335
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_security_group" "sg_ec2_private" {
  name = "sg_ec2_private"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jboss_eap_demo_sg_ec2_private"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_ec2_private_ingress_1" {
  security_group_id = aws_security_group.sg_ec2_private.id
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
  referenced_security_group_id = aws_security_group.sg_alb_internal.id
}


resource "aws_vpc_security_group_ingress_rule" "sg_ec2_private_ingress_2" {
  security_group_id = aws_security_group.sg_ec2_private.id
  from_port         = 8443
  ip_protocol       = "tcp"
  to_port           = 8443
  referenced_security_group_id = aws_security_group.sg_alb_internal.id
}

resource "aws_vpc_security_group_ingress_rule" "sg_ec2_private_ingress_3" {
  security_group_id = aws_security_group.sg_ec2_private.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  referenced_security_group_id = aws_security_group.sg_vpc_endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "sg_ec2_private_egress_1" {
  security_group_id = aws_security_group.sg_ec2_private.id
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432
  referenced_security_group_id = aws_security_group.sg_aurora.id
}

resource "aws_vpc_security_group_egress_rule" "sg_ec2_private_egress_2" {
  security_group_id = aws_security_group.sg_ec2_private.id
  from_port = 0
  to_port = 65335
  ip_protocol = "tcp"
  referenced_security_group_id = aws_security_group.sg_vpc_endpoint.id
}

resource "aws_vpc_security_group_egress_rule" "sg_ec2_private_egress_3" {
  security_group_id = aws_security_group.sg_ec2_private.id
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
  prefix_list_id = "pl-61a54008"
}

resource "aws_security_group" "sg_aurora" {
  name = "sg_aurora"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jboss_eap_demo_sg_aurora"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_aurora_ingress" {
  security_group_id = aws_security_group.sg_aurora.id
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432
  referenced_security_group_id = aws_security_group.sg_ec2_private.id
}

resource "aws_vpc_security_group_egress_rule" "sg_aurora_egress" {
  security_group_id = aws_security_group.sg_aurora.id
  from_port = 0
  to_port = 65335
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_security_group" "sg_vpc_endpoint" {
  name = "sg_vpc_endpoint"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jboss_eap_demo_sg_vpc_endpoint"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sg_vpc_endpoint_ingress_1" {
  security_group_id = aws_security_group.sg_vpc_endpoint.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  referenced_security_group_id = aws_security_group.sg_ec2_private.id
}

resource "aws_vpc_security_group_ingress_rule" "sg_vpc_endpoint_ingress_2" {
  security_group_id = aws_security_group.sg_vpc_endpoint.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  referenced_security_group_id = aws_security_group.sg_ec2_public.id
}

resource "aws_vpc_security_group_egress_rule" "sg_vpc_endpoint_egress" {
  security_group_id = aws_security_group.sg_vpc_endpoint.id
  from_port = 0
  to_port = 65335
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

### VPC Endpoint  #######################################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.private_rt.id,aws_route_table.public_rt.id]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  security_group_ids = [aws_security_group.sg_vpc_endpoint.id]
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  security_group_ids = [aws_security_group.sg_vpc_endpoint.id]
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  security_group_ids = [aws_security_group.sg_vpc_endpoint.id]
}


### IAM  #######################################################
resource "aws_iam_policy" "jboss_eap_demo_s3_access_policy" {
  name = "jboss_eap_demo_s3_access_policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowAllForS3",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "${aws_s3_bucket.data.arn}/*",
                "${aws_s3_bucket.data.arn}",
            ]
        }
    ]
  })
}

resource "aws_iam_role" "ec2_role" {
    name = "ec2_role"
    assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ec2_role_s3_access_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.jboss_eap_demo_s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2_role_ssm_access_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "jboss_eap_demo_ec2_profile"
  role = aws_iam_role.ec2_role.name
}

### Bastion EC2 Instance #######################################################
resource "aws_key_pair" "http_server_key_pair" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC9csh/nehgwaM7aVRAQq7T+uKO1U9Y+0j3hLJhpzwMkMLUCiQJIcu92Sp8s08ExZacL8pbyONIMxnrrNsE9srk6PmmI5FpMFQYUwBW+g85oO5F0yBKMS1nVWvKhEhxHKvF6TLqkYjRvwM+4j8CkScEZGOeZsiHTxi0KzxFMCU0uRWKCMdrWS66TnFoMmAoNEBSTVqqvLzgbrEio57xwsV2YIEJUK5TVidvAtgDko6GrNwFIdz2uUEPQwyIg4mNg4rJQfrDkzkDI+DcBv/1OqO+kpJahHHiVuaNjoaQs/QUXiPXoqwAay3ZIDvG97EXFhsGKIBcKh1eozhq9/wtbFuGOsPHHDEWiSiwQCC5NS6jSY+Dnc85+CotLW/mMAn7MCqRrYSbvOxkE3uvG6vBBIF0M8LPJQwyE360x1USn9X+UtYFibKYK9UndM1rDO9hBezq5ZjT70ZvvvvCzpJCQ+Wy9ok8FwF25QhlTF1shpyhsHade144KGt6Y1E5jVfGpfU="
}

resource "aws_instance" "http_server_1" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.sg_ec2_public.id]
  key_name               = aws_key_pair.http_server_key_pair.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  tags = {
    Name = "http-server-1"
  }
  user_data = file("../bootstrap.sh")
  depends_on = [aws_vpc_endpoint.s3]
}

resource "aws_instance" "http_server_2" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet_2.id
  vpc_security_group_ids = [aws_security_group.sg_ec2_public.id]
  key_name               = aws_key_pair.http_server_key_pair.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  tags = {
    Name = "http-server-2"
  }
  user_data = file("../bootstrap.sh")
  depends_on = [aws_vpc_endpoint.s3]
}

resource "aws_instance" "ap_server_1" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.sg_ec2_private.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  tags = {
    Name = "ap-server-1"
  }
  user_data = file("../bootstrap_ap.sh")
  depends_on = [aws_vpc_endpoint.s3]
}

resource "aws_instance" "ap_server_2" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.sg_ec2_private.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  tags = {
    Name = "ap-server-2"
  }
  user_data = file("../bootstrap_ap.sh")
  depends_on = [aws_vpc_endpoint.s3]
}


### ALB  #######################################################
data "aws_acm_certificate" "issued" {
  domain   = "*.consulting-io.com"
  statuses = ["ISSUED"]
}

resource "aws_lb" "alb_front" {
  name = "jboss-eap-demo-alb"
  subnets = [aws_subnet.public_subnet_1.id,aws_subnet.public_subnet_2.id]
  security_groups = [aws_security_group.sg_alb.id]
  internal           = false
  load_balancer_type = "application"
}

resource "aws_lb_target_group" "alb_front_target_group" {
  name     = "alb-front-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "alb_front_target_group_attachment_front_1" {
  target_group_arn = aws_lb_target_group.alb_front_target_group.arn
  target_id        = aws_instance.http_server_1.id
  port             = 443
}

resource "aws_lb_target_group_attachment" "alb_front_target_group_attachment_front_2" {
  target_group_arn = aws_lb_target_group.alb_front_target_group.arn
  target_id        = aws_instance.http_server_2.id
  port             = 443
}

resource "aws_lb_listener" "alb_front_listener" {
  load_balancer_arn = aws_lb.alb_front.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = data.aws_acm_certificate.issued.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_front_target_group.arn
  }
}

resource "aws_lb" "alb_internal" {
  name = "jboss-eap-demo-alb-internal"
  subnets = [aws_subnet.private_subnet_1.id,aws_subnet.private_subnet_2.id]
  security_groups = [aws_security_group.sg_alb_internal.id]
  internal           = true
  load_balancer_type = "application"
}

resource "aws_lb_target_group" "alb_internal_target_group" {
  name     = "alb-internal-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "alb_internal_target_group_attachment_1" {
  target_group_arn = aws_lb_target_group.alb_internal_target_group.arn
  target_id        = aws_instance.ap_server_1.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "alb_front_target_group_attachment_2" {
  target_group_arn = aws_lb_target_group.alb_internal_target_group.arn
  target_id        = aws_instance.ap_server_2.id
  port             = 8080
}

resource "aws_lb_listener" "alb_internal_listener" {
  load_balancer_arn = aws_lb.alb_internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_internal_target_group.arn
  }
}

### Aurora #######################################################
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name = "main_subnet_group"
  subnet_ids = [aws_subnet.private_subnet_1.id,aws_subnet.private_subnet_2.id]

}

resource "aws_rds_cluster" "postgresql" {
  cluster_identifier      = "aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "16.6"
  availability_zones      = [var.availability_zone_1,var.availability_zone_2]
  database_name           = "postgres"
  master_username         = "postgres"
  master_password         = "hogehogerz2345!"
  backup_retention_period = 1
  preferred_backup_window = "07:00-09:00"
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.id
  skip_final_snapshot = true

  serverlessv2_scaling_configuration {
    max_capacity             = 1.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 300
  }

  vpc_security_group_ids = [aws_security_group.sg_aurora.id]

  lifecycle {
    ignore_changes = ["master_password", "availability_zones"]
  }
}

resource "aws_rds_cluster_instance" "example" {
  cluster_identifier = aws_rds_cluster.postgresql.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.postgresql.engine
  engine_version     = aws_rds_cluster.postgresql.engine_version
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.id
}