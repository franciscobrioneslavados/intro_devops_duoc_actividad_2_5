output "security_group_id" {
  description = "ID del Security Group"
  value       = aws_security_group.this.id
}
