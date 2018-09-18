provider "aws" {
  # TODO - Make region variable / input. MN's should be worldwide! Let user choose it.
  region = "us-east-1"
}

# Generate a random public-private RSA key pair for EC2 instance
resource "tls_private_key" "anon_masternode_key" {
  algorithm = "RSA"
}

# Create AWS key pair
resource "aws_key_pair" "anon_masternode_key_pair" {
  key_name = "anon_masternode_key"
  public_key = "${tls_private_key.anon_masternode_key.public_key_openssh}"
}

# Create EC2 instance with generated key pair
resource "aws_instance" "masternode" {
  ami = "ami-04681a1dbd79675a5"
  # TODO - Make instance_type a variable / input.
  instance_type = "t2.micro"
  key_name = "anon_masternode_key"

  # FIXME - Write out private key to a file so user can SSH into node for troubleshooting or fine-tuning
  # Key name should go into .gitignore
  provisioner "local-exec" {
    command = "mkdir -p assets && echo '${tls_private_key.anon_masternode_key.private_key_pem}' > assets/anon_masternode.pem"
  }

  # Simple bootstrap of Anon MN
  provisioner "remote-exec" {
    
    connection = {
      type = "ssh"
      user = "ec2-user"
      private_key = "${tls_private_key.anon_masternode_key.private_key_pem}"
    }

    inline = [
      "sudo yum install -y git",
      "sudo yum groupinstall "Development Tools",
      "git clone https://github.com/anonymousbitcoin/anon/",
      "cd ~/anon/anonutil && ./build.sh"
      
    ]
  }
}

