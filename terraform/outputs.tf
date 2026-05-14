output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "frontend_public_ip" {
  description = "IP pública del Frontend (abrir en navegador)"
  value       = module.ec2_frontend.public_ips
}

output "frontend_instance_id" {
  description = "Instance ID del Frontend (para GitHub Secrets)"
  value       = module.ec2_frontend.instance_ids
}

output "backend_private_ip" {
  description = "IP privada del Backend (configurar en nginx proxy_pass)"
  value       = module.ec2_backend.private_ips
}

output "backend_instance_id" {
  description = "Instance ID del Backend (para GitHub Secrets)"
  value       = module.ec2_backend.instance_id
}

output "db_private_ip" {
  description = "IP privada de la DB (configurar en backend DB_HOST)"
  value       = module.ec2_db.private_ips
}

output "db_instance_id" {
  description = "Instance ID de la DB (para GitHub Secrets)"
  value       = module.ec2_db.instance_id
}

output "nat_instance_public_ip" {
  description = "IP pública de la NAT Instance"
  value       = module.nat_instance.nat_instance_public_ip
}
