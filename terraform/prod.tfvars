aws_region         = "ap-southeast-1"
project_name       = "skyrouter"
environment        = "prod"

# VPC
vpc_cidr = "10.0.0.0/16"

# EKS
cluster_version    = "1.30"
node_instance_type = "t3.small"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 3

# RDS (single-AZ for demo — no multi_az override needed, see rds module)
db_name           = "skyrouterdb"
db_username       = "dbadmin"
db_instance_class = "db.t3.micro"

# S3 buckets the backend service needs (add yours here)
s3_bucket_arns = []
