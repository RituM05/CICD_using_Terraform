variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "ap-south-2"
}

variable "key_name" {
  description = "The name of the SSH key pair"
  type        = string
  default     = "my-key-pair"
}

variable "github_token" {
  description = "GitHub OAuth Token for accessing the repository"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub username or organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "main"
  type        = string
  default     = "main"
}