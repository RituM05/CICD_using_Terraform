terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }

  backend "s3" {
    bucket = data.aws_secretsmanager_secret_version.terraform_state_bucket.secret_string
    key    = "aws/ec2-deploy/terraform.tfstate"
    region = var.region
  }
}

# Fetch Secrets from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "private_key" {
  secret_id = "deployer-key"
}

data "aws_secretsmanager_secret_version" "public_key" {
  secret_id = "deployer-key-public"
}

data "aws_secretsmanager_secret_version" "terraform_state_bucket" {
  secret_id = "aws-tf-state-bucket"
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "github_token"
}

provider "aws" {
  region = var.region
}

# SSH Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = data.aws_secretsmanager_secret_version.public_key.secret_string
}

# Security Group
resource "aws_security_group" "maingroup" {
  egress = [{
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }]

  ingress = [
    {
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    },
    {
      cidr_blocks = ["0.0.0.0/0"]
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
    }
  ]
}

# IAM Role for EC2
resource "aws_iam_instance_profile" "ec2-profile" {
  name = "ec2-profile"
  role = "EC2-ECR-AUTH"
}

# EC2 Instance
resource "aws_instance" "servernode" {
  ami                    = "ami-0c3b809fcf2445b6a"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.maingroup.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2-profile.name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = data.aws_secretsmanager_secret_version.private_key.secret_string
    timeout     = "4m"
  }

  tags = {
    "Name" = "DeployVM"
  }
}

# CodePipeline IAM Role
resource "aws_iam_role" "codepipeline_role" {
  name = "CodePipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# GitHub Source for CodePipeline
resource "aws_codepipeline" "terraform_pipeline" {
  name     = "Terraform-CICD-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = data.aws_secretsmanager_secret_version.terraform_state_bucket.secret_string
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "2"
      output_artifacts = ["source_output"]
      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = var.github_branch
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "TerraformBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
      }
    }
  }
}

# AWS CodeBuild Project to Run Terraform
resource "aws_codebuild_project" "terraform_build" {
  name         = "Terraform-Build"
  service_role = aws_iam_role.codepipeline_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOT
      version: 0.2
      phases:
        install:
          runtime-versions:
            docker: 20
          commands:
            - echo "Installing Terraform..."
            - curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
            - sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
            - sudo apt-get update && sudo apt-get install -y terraform
        build:
          commands:
            - echo "Initializing Terraform..."
            - terraform init -backend-config="bucket=${data.aws_secretsmanager_secret_version.terraform_state_bucket.secret_string}"
            - terraform plan -out=tfplan
            - terraform apply -auto-approve tfplan
    EOT
  }
}

# Output EC2 Public IP
output "instance_public_ip" {
  value     = aws_instance.servernode.public_ip
  sensitive = true
}