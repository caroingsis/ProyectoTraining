terraform {
  backend "s3" {
    bucket = "carobucket1"
    key    = "caro.tfstate"
    region = "us-east-1"
  }

}