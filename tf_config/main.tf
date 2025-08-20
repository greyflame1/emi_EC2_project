data "aws_ssm_parameter" "al2" {
  name="/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

data "aws_vpcs" "default" {
  filter {
    name="isDefault"
    values=["true"]
  }
}

data "aws_subnets" "default_subnet" {
  filter {
    name="vpc-id"
    values=[data.aws_vpcs.default.ids[0]]
  }
}

resource "aws_security_group" "web_sg" {
  name="web-sg"
  vpc_id=data.aws_vpcs.default.ids[0]

  ingress {
    from_port=80
    to_port=80
    protocol="tcp"
    cidr_blocks=["0.0.0.0/0"]
  }

  egress {
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks=["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami=data.aws_ssm_parameter.al2.value
  instance_type="t3.micro"
  subnet_id=data.aws_subnets.default_subnet.ids[0]
  vpc_security_group_ids=[aws_security_group.web_sg.id]
  associate_public_ip_address=true

  user_data=<<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker

    cat <<EOT >/home/ec2-user/index.html
    ${file("${path.module}/../index.html")}
    EOT

    docker run -d -p 80:80 \
      -v /home/ec2-user/index.html:/usr/share/nginx/html/index.html \
      nginx:alpine
  EOF

  tags={
    Name="emi-ec2"
  }
}

output "public_ip" {
  value=aws_instance.web.public_ip
}
