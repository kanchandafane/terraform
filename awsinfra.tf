provider "aws" {
  region = "us-east-2"
//  shared_credentials_file = "/Users/kanchandafane/Desktop/Terraform Code/AWS/creds/awslabs.ini"
  profile = "default"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
//  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow ssh"
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

  tags = {
    Name = "allow_http"
  }
}

output "secgrp" {
  value = aws_security_group.allow_http
}

resource "aws_iam_instance_profile" "s3_instance_profile" {
  name = "s3_instance_profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "s3_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement":
        {
            "Action": "s3:*"
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "s1"
        }  
}
EOF
}

resource "aws_instance" "web" {
  ami           = "ami-026dea5602e368e96"
  instance_type = "t2.micro"
  key_name = "labec2key"
  security_groups = ["${aws_security_group.allow_http.name}"]
  iam_instance_profile = aws_iam_instance_profile.s3_instance_profile.name

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("./labec2key.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "labos1"
  }

}


resource "aws_ebs_volume" "labebs1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "labebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.labebs1.id
  instance_id = aws_instance.web.id
  force_detach = true
}

output "myos_ip" {
  value = aws_instance.web.public_ip
}

resource "null_resource" "nulllocal1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}

resource "null_resource" "nullremote1"  {

depends_on = [
    aws_volume_attachment.ebs_att,
    aws_s3_bucket.b
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/Users/kanchandafane/Desktop/Terraform Code/labec2key.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/kanchandafane/webapp.git /var/www/html/",
      "aws s3 cp /var/www/html/quino-al-5WMkrgjCzFo-unsplash.jpg s3://${aws_s3_bucket.b.id}/images/sunset.jpg",
      "sed 's+changesrc+https://${aws_cloudfront_distribution.s3_distribution.domain_name}+g' /var/www/html/index.html"  
    ]
  }
}

resource "null_resource" "nulllocal2"  {

depends_on = [
    null_resource.nullremote1,
  ]

	provisioner "local-exec" {
	    command = "open -a 'Google Chrome' ${aws_instance.web.public_ip}"
  	}
}