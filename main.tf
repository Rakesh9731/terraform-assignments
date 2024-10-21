# Provider Configuration
provider "aws" {
  region = var.aws_region
}

# Create a Key Pair
resource "aws_key_pair" "my_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# Create a Security Group to Allow SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Ubuntu EC2 Instance
resource "aws_instance" "ubuntu" {
  ami                    = var.ubuntu_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.my_key.key_name
  security_groups        = [aws_security_group.allow_ssh.name]
  associate_public_ip_address = true

  # Copy Ansible Playbook to EC2 Instance
  provisioner "file" {
    source      = "playbook.yml"
    destination = "/home/ubuntu/playbook.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }

  # Install Ansible on EC2 Instance
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install software-properties-common -y",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt-get install ansible -y"
    ]
  }

  # Run Ansible Playbook
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
    inline = [
      "ansible-playbook /home/ubuntu/playbook.yml"
    ]
  }

  tags = {
    Name = "Terraform-Ansible-EC2"
  }
}

# Output the Public IP of the EC2 Instance
output "instance_public_ip" {
  value = aws_instance.ubuntu.public_ip
}
