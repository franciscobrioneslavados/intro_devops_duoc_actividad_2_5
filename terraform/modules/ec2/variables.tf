variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}

variable "name" {
  description = "Base name for the instances"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for the instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID where instances will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "List of Security Group IDs"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile name"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script to run on instance start"
  type        = string
  default     = ""
}

variable "app_zip_base64" {
  description = "Base64 encoded zip content of the app"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Base tags to apply to the instances"
  type        = map(string)
  default     = {}
}