terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "220526-apnortheast2-tfstate"
    key            = "provisioning/terraform/init/220526/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "eks-terraform-lock"
  }
}
