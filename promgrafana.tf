resource "aws_instance" "monitoring" {
  ami                    = "ami-0005ee01bca55ab66"
  instance_type          = "t3.small"
  subnet_id              = "subnet-096a7c55adcfb1322"
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  key_name               = "server"

  tags = {
    Name = "prometheus-grafana"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo dnf update -y
    sudo dnf install -y docker
    sudo systemctl enable --now docker

    sudo usermod -aG docker ec2-user

    sudo mkdir -p /prometheus-data /grafana-data /prometheus-config
    sudo chmod 777 /prometheus-data /grafana-data

    cat << 'PROMCONFIG' | sudo tee /prometheus-config/prometheus.yml
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'node'
        ec2_sd_configs:
          - region: us-west-2
            port: 9100
            filters:
              - name: "tag:Name"
                values: ["web-server"]
        relabel_configs:
          - source_labels: [__meta_ec2_tag_Name]
            target_label: instance

      - job_name: 'cloudwatch'
        static_configs:
          - targets: ['localhost:9106']
    PROMCONFIG

    sudo systemctl start docker

    while ! sudo systemctl is-active --quiet docker; do sleep 5; done

    sudo docker run -d \
      --name prometheus \
      --restart=always \
      -p 9090:9090 \
      -v /prometheus-config:/etc/prometheus \
      -v /prometheus-data:/prometheus \
      prom/prometheus

    sudo docker run -d \
      --name cloudwatch-exporter \
      --restart=always \
      -p 9106:9106 \
      -e AWS_REGION=us-west-2 \
      prom/cloudwatch-exporter

    sudo docker run -d \
      --name grafana \
      --restart=always \
      -p 3000:3000 \
      -v /grafana-data:/var/lib/grafana \
      -e "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-worldmap-panel,grafana-piechart-panel" \
      grafana/grafana

    sudo docker run -d \
      --name node-exporter \
      --restart=always \
      --net="host" \
      --pid="host" \
      -v "/:/host:ro,rslave" \
      quay.io/prometheus/node-exporter:latest \
      --path.rootfs=/host

    echo "User data script completed successfully for Amazon Linux 2023" > /home/ec2-user/user-data-completed.txt
  EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Security group for Prometheus and Grafana"
  vpc_id      = "vpc-052392afe48c5a6ac"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus UI access"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana UI access"
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Node Exporter access from within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "monitoring-sg"
  }
}

resource "aws_security_group_rule" "allow_prometheus" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.monitoring_sg.id
  source_security_group_id = aws_security_group.monitoring_sg.id
  description              = "Allow Prometheus to scrape metrics"
}

resource "aws_iam_role" "monitoring_role" {
  name = "monitoring_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "monitoring_policy" {
  name        = "monitoring-policy"
  description = "Allow CloudWatch and EC2 discovery"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "monitoring_policy_attachment" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "monitoring-profile"
  role = aws_iam_role.monitoring_role.name
}

output "grafana_url" {
  value = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.monitoring.public_ip}:9090"
}
