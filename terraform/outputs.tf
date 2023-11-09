output "instance_a_public_ip_addr" {
  value = aws_instance.vpc_a_ec2_public.public_ip
}

output "instance_a_private_ip_addr" {
  value = aws_instance.vpc_a_ec2_private.private_ip
}

output "instance_b_private_ip_addr" {
  value = aws_instance.vpc_b_ec2_private.private_ip
}
