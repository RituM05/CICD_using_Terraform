terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }

  backend "s3" {
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
  name        = "terraform-security-group"
  description = "Security group for Terraform-managed instances"

  vpc_id      = "vpc-045a49b950287bf72"  

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
}

# IAM Role for EC2
resource "aws_iam_instance_profile" "ec2-profile" {
  name = "ec2-profile"
  role = "EC2-ECR-AUTH"
}

# EC2 Instance
resource "aws_instance" "servernode" {
  ami                    = "ami-0e35ddab05955cf57"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2-profile.name
  subnet_id              = "subnet-000fed4adb0958265" # <-- Public subnet
  vpc_security_group_ids = ["sg-0e904b9d395c1511b"]

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y ruby wget

              cd /home/ubuntu
              wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
              chmod +x ./install
              sudo ./install auto

              sudo systemctl start codedeploy-agent
              sudo systemctl enable codedeploy-agent
              EOF

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

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "CodePipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "codepipeline.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach IAM Policy to CodePipeline Role
resource "aws_iam_policy" "codepipeline_policy" {
  name        = "CodePipelinePolicy"
  description = "Permissions for CodePipeline to access CodeBuild, S3, EC2, and Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      "Effect": "Allow",
      "Action": [
        "codepipeline:*",
        "codebuild:*",
        "codedeploy:*",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecrets",
        "iam:PassRole",
        "codestar-connections:UseConnection"
      ],
     "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::${var.terraform_state_bucket}/*"
    }
    ]
  })
}

# Attach Policy to CodePipeline IAM Role
resource "aws_iam_role_policy_attachment" "codepipeline_policy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

# Attach AWS-Managed Policies to CodePipeline Role
locals {
  managed_policies = [
    "arn:aws:iam::aws:policy/AWSCodeStarFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]
}

resource "aws_iam_role_policy_attachment" "managed_policies_attachment" {
  for_each = toset(local.managed_policies)
  role     = aws_iam_role.codepipeline_role.name
  policy_arn = each.value
}

resource "aws_iam_role" "codebuild_role" {
  name = "CodeBuildRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "codebuild_policy" {
  name        = "CodeBuildPolicy"
  description = "Permissions for CodeBuild to access Terraform backend, logs, EC2, S3, IAM, and CodeConnections"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codebuild:*",
          "secretsmanager:GetSecretValue",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:ImportKeyPair"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::ec2-app-state-bucket1/Terraform-CICD-Pipel/source_out/*",
          "arn:aws:s3:::ec2-app-state-bucket1/Terraform-CICD-Pipel/build_outp/*",
          "arn:aws:s3:::ec2-app-state-bucket1/terraform/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::ec2-app-state-bucket1"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:CreateInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:PassRole"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:CreateRole",
          "iam:PutRolePolicy",
          "iam:AttachRolePolicy",
          "iam:CreatePolicy",
          "iam:PassRole"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codeconnections:CreateConnection",
          "codeconnections:GetConnection",
          "codeconnections:DeleteConnection",
          "codeconnections:ListConnections"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

resource "aws_iam_role" "codedeploy_service_role" {
  name = "CodeDeployServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codedeploy.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codestarconnections_connection" "github_connection" {
  name          = "GitHubConnection"
  provider_type = "GitHub"
}

# GitHub Source for CodePipeline
resource "aws_codepipeline" "terraform_pipeline" {
  name     = "Terraform-CICD-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = var.terraform_state_bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId = "RituM05/CICD_using_Terraform"
        BranchName       = "main"
        DetectChanges    = "true"
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
      version          = "1" 
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "CodeDeploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ApplicationName     = aws_codedeploy_app.nodejs_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.nodejs_group.deployment_group_name
      }
    }
  }
}

# AWS CodeBuild Project to Run Terraform
resource "aws_codebuild_project" "terraform_build" {
  name         = "Terraform-Build"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:6.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TF_VAR_region"
      value = var.region
    }
    environment_variable {
      name  = "TF_VAR_github_owner"
      value = var.github_owner
    }
    environment_variable {
      name  = "TF_VAR_github_repo"
      value = var.github_repo
    }
    environment_variable {
      name  = "TF_VAR_github_branch"
      value = var.github_branch
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

resource "aws_codedeploy_app" "nodejs_app" {
  name             = "NodeJSApp"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "nodejs_group" {
  app_name              = aws_codedeploy_app.nodejs_app.name
  deployment_group_name = "NodeJSDeploymentGroup"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      value = "DeployVM"
      type  = "KEY_AND_VALUE"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# Output EC2 Public IP
output "instance_public_ip" {
  value     = aws_instance.servernode.public_ip
  sensitive = true
}

output "codebuild_role_arn" {
  value = aws_iam_role.codebuild_role.arn
}