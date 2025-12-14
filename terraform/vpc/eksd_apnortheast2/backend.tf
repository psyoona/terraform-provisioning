terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "220526-apnortheast2-tfstate"
    key            = "provisioning/terraform/vpc/eksd_apnortheast2/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "eks-terraform-lock"
  }
}
