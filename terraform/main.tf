# initialize terraform with AWS provider

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Create a new S3 bucket
resource "aws_s3_bucket" "staging-bucket" {
  bucket = "rob-wing-tf-staging-bucket"
  tags = {
      Name = "My Bucket"
      Environment = "Dev"
  }
}

resource "aws_s3_object" "staging-jar" {
  bucket = aws_s3_bucket.staging-bucket.id 
  key    = "g-hello-0.0.1-SNAPSHOT.jar"
  source = "../build/libs/g-hello-0.0.1-SNAPSHOT.jar"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
#   etag = filemd5("../build/libs/g-hello-0.0.1-SNAPSHOT.jar")
  source_hash = filemd5("../build/libs/g-hello-0.0.1-SNAPSHOT.jar")
}

resource "aws_iam_role_policy" "staging_bucket_access_policy" {
    name = "staging_bucket_access_policy"
    role = aws_iam_role.staging_bucket_access.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:ListBucket"
                ]
                Effect = "Allow"
                Resource = [
                    aws_s3_bucket.staging-bucket.arn,
                    "${aws_s3_bucket.staging-bucket.arn}",
                    aws_s3_bucket.staging-bucket.arn,
                    "${aws_s3_bucket.staging-bucket.arn}/*"
                ]
            },
            {
                Action = [
                    "s3:ListAllMyBuckets"
                ]
                Effect = "Allow"
                Resource = "*"
            }
        ]
    })
}

resource "aws_iam_role" "staging_bucket_access" {
    name = "staging_bucket_access"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Sid = ""
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_instance_profile" "staging_bucket_access" {
    name = "staging_bucket_access"
    role = aws_iam_role.staging_bucket_access.name
}

resource "aws_instance" "my_server" {
  ami           = "ami-0ad86651279e2c354"
  instance_type = "t3.micro"

  security_groups = [aws_security_group.inbound_sg.name]

  # Role to access S3 bucket
  iam_instance_profile = aws_iam_instance_profile.staging_bucket_access.name

  key_name = "rlw-s1-us-west-2"

  user_data = <<EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install -y java-17-amazon-corretto-headless
  aws s3api get-object --bucket ${aws_s3_bucket.staging-bucket.id} --key ${aws_s3_object.staging-jar.key} ${aws_s3_object.staging-jar.key}
  java -jar ${aws_s3_object.staging-jar.key} &
  EOF


  tags = {
    Name = "robs-terraform-server"
  }
}

resource "aws_security_group" "inbound_sg" {
    name = "robs-sg"
    description = "Allow inbound traffic"
    

    ingress {
        description = "allow SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "allow Spring Boot"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }
  
}

output "aws_instance_ssh_connect_string" {
    value = "ssh -i ~/.ssh/rlw-s1-us-west-2.pem ec2-user@${aws_instance.my_server.public_dns}"
}

output "spring_boot_app_url" {
    value = "http://${aws_instance.my_server.public_dns}:8080/hello"
}