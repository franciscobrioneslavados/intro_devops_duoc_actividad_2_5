resource "aws_instance" "this" {
  count = var.instance_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile
  user_data              = var.user_data

  user_data_replace_on_change = true
  tags = merge(
    var.tags,
    {
      Name = var.instance_count > 1 ? "${var.name}-${count.index + 1}" : var.name
    }
  )
}