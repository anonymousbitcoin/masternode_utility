provider "aws" {
  region = "${var.aws_region}"
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

# Generate random RPC user for anon.conf
resource "random_string" "rpcuser" {
  length = 32
  special = false
}

# Generate random RPC password for anon.conf
resource "random_string" "rpcpassword" {
  length = 32
  special = false
}

# Create EC2 instance with generated key pair
resource "aws_instance" "masternode" {
  ami = "ami-04681a1dbd79675a5"
  instance_type = "${var.aws_ec2_instance_type}"
  key_name = "anon_masternode_key"
  root_block_device = {
    volume_type = "gp2"
    volume_size = 100
  }

  provisioner "local-exec" {
    command = "mkdir -p assets; rm -rf assets/*; echo '${tls_private_key.anon_masternode_key.private_key_pem}' > assets/anon_masternode.pem; chmod 400 assets/anon_masternode.pem"
  }

  # Simple bootstrap of Anon MN
  provisioner "remote-exec" {

    connection = {
      type = "ssh"
      user = "ec2-user"
      private_key = "${tls_private_key.anon_masternode_key.private_key_pem}"
    }

    inline = [
      "sudo yum update -y",
      "sudo yum install -y git",
      "sudo yum groupinstall -y 'Development Tools'",
      "git clone https://github.com/anonymousbitcoin/anon/",
      "cd ~/anon/anonutil && ./build.sh",
      "cd ~/anon/anonutil && ./fetch-params.sh",
      "mkdir ~/.anon && touch ~/.anon/anon.conf",
      "echo rpcuser=${random_string.rpcuser.result} > ~/.anon/anon.conf",
      "echo rpcpassword=${random_string.rpcpassword.result} >> ~/.anon/anon.conf",
      "echo rpcallowip=127.0.0.1 >> ~/.anon/anon.conf",
      "echo txindex=1 >> ~/.anon/anon.conf",
      "echo masternode=1 >> ~/.anon/anon.conf",
      "echo masternodeprivkey=${var.masternodeprivkey} >> ~/.anon/anon.conf",
      "echo externalip=${aws_instance.masternode.public_ip} >> ~/.anon/anon.conf",
      "~/anon/src/anond -daemon"
    ]
  }
}

