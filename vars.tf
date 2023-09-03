variable "aws_region" {

  description = "This variable contains the aws region "  
  type    = list(string)
  default = ["eu-central-1"]
}

variable "ACCESS_KEY_ID" {
    
    description = "This variable contains value for the access key ID"
    type = string
    default = ""
  
}

variable "SECRET_ACCESS_KEY" {
    
    description = "This variable contains value for the secrey key"
    type = string
    default = ""
  
}
