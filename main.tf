provider "aws" {
  region = "ap-south-1"
}


resource "aws_key_pair" "demo" {
  key_name = "key-1"
  public_key = file("/home/ubuntu/key-1.pub")
}

resource "aws_vpc" "My-VPC-AWS-vpc" {
  cidr_block = "19.0.0.0/16"

  tags = {
    Name = "my_vpc"
  }
}

resource "aws_subnet" "subnet_az1" {
  vpc_id                  = aws_vpc.My-VPC-AWS-vpc.id
  cidr_block              = "19.0.16.0/20"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-az1"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.My-VPC-AWS-vpc.id
  
  tags = {
    Name = "my_igw"
  }
}

resource "aws_route_table" "RT" {
   vpc_id = aws_vpc.My-VPC-AWS-vpc.id
  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
   
}

resource "aws_route_table_association" "rtal" {
  subnet_id = aws_subnet.subnet_az1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Security group for EC2 instances in the subnet"

  vpc_id = aws_vpc.My-VPC-AWS-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2_instance" {
  ami           = "ami-03f4878755434977f"
  instance_type = "t2.micro"
  key_name = "key-1"
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  subnet_id = aws_subnet.subnet_az1.id


    connection {
        type        = "ssh"
        user        = "ubuntu" 
        private_key = file("/home/ubuntu/key-1")
        host        = self.public_ip
    }

    provisioner "remote-exec" {
      inline = [ 
        "sudo apt update -y",
        "sudo apt-get install -y python3-pip",
        "sudo apt --fix-broken install",
        "sudo apt update -y",
        "sudo apt install -y openjdk-17-jdk",
        "wget https://downloads.apache.org/tomcat/tomcat-9/v9.0.85/bin/apache-tomcat-9.0.85.tar.gz",
        "tar -xvzf apache-tomcat-9.0.85.tar.gz",
        "sudo mv apache-tomcat-9.0.85 /opt/tomcat9"
      ]
      
    }
# Provisioner to copy and deploy WAR file
    provisioner "file" {
      source      = "/home/ubuntu/warfile/jenkins_workflow/sample.war"  # Path to your WAR file
      destination = "/opt/tomcat9/webapps/sample.war"    # Destination path in Tomcat
    }
     
  tags = {
    Name = "ec2-instance"
  }
}  
resource "aws_eip" "ip" {
  instance = aws_instance.ec2_instance.id
}  

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2_instance.id
  allocation_id = aws_eip.ip.id
}
