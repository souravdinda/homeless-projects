terraform {

  # S3 Backend for CI/CD Remote State Management (Using native S3 locking)
  backend "s3" {
    bucket       = "opeyemi-terraform-remote-state-file"
    key          = "pilot/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
