variable "name" {
  description = "Nombre del Security Group"
  type        = string
}

variable "description" {
  description = "Descripción del Security Group"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "ingress_rules" {
  description = "Lista de reglas de ingreso"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
