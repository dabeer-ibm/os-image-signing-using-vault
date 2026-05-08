output "ami_id" {
  description = "AMI ID resolved from the HCP Packer channel"
  value       = data.hcp_packer_artifact.ubuntu.external_identifier
}

output "ami_signature_verified" {
  description = "True if Vault Transit verified the AMI signature for this run"
  value       = local.ami_signature_valid
}

output "instance_id" {
  value = aws_instance.demo.id
}

output "public_ip" {
  value = aws_instance.demo.public_ip
}

output "ssh_command" {
  description = "Pull the private key from Vault, then SSH"
  value       = "vault kv get -field=private_key kv/demo/ssh > /tmp/demo.pem && chmod 600 /tmp/demo.pem && ssh -i /tmp/demo.pem ubuntu@${aws_instance.demo.public_ip}"
}
