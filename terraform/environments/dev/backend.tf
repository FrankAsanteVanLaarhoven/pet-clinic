terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-158709926611"
    key            = "petclinic/dev/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "petclinic-terraform-locks"
  }
}
