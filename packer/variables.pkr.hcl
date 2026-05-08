variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "hcp_bucket_name" {
  type    = string
  default = "demo-ubuntu-base"
}

variable "hcp_bucket_channel" {
  type    = string
  default = "production"
}
