# Create an EC2 instance to host Prometheus and Grafana
resource "aws_instance" "monitoring" {
  ami                    = "ami-0005ee01bca55ab66" # Same Amazon Linux 2 AMI you're using
  instance_type          = "t3.small"              # Adequate for monitoring setup
  subnet_id              = "subnet-096a7c55adcfb1322"
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  key_name               = "server" # Replace with your key pair

  tags = {
    Name = "prometheus-grafana"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update system
    yum update -y
    
    # Install Docker
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    
    # Create directories for persistent storage
    mkdir -p /prometheus-data /grafana-data
    chmod 777 /grafana-data
    
    # Create Prometheus config
    mkdir -p /prometheus-config
    cat > /prometheus-config/prometheus.yml << 'PROMCONFIG'
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
    
    # Start Prometheus container
    docker run -d \
      --name prometheus \
      --restart=always \
      -p 9090:9090 \
      -v /prometheus-config:/etc/prometheus \
      -v /prometheus-data:/prometheus \
      prom/prometheus
    
    # Start CloudWatch exporter
    docker run -d \
      --name cloudwatch-exporter \
      --restart=always \
      -p 9106:9106 \
      -e AWS_REGION=us-west-2 \
      prom/cloudwatch-exporter
    
    # Start Grafana container
    docker run -d \
      --name grafana \
      --restart=always \
      -p 3000:3000 \
      -v /grafana-data:/var/lib/grafana \
      -e "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-worldmap-panel,grafana-piechart-panel" \
      grafana/grafana
    
    # Install Node Exporter on this monitoring instance too
    docker run -d \
      --name node-exporter \
      --restart=always \
      --net="host" \
      --pid="host" \
      -v "/:/host:ro,rslave" \
      quay.io/prometheus/node-exporter:latest \
      --path.rootfs=/host
  EOF
  )

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

# Security group for monitoring instance
resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Security group for Prometheus and Grafana"
  vpc_id      = "vpc-052392afe48c5a6ac"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this to your IP
  }

  # Prometheus UI
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this
  }

  # Grafana UI
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # VPC CIDR
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "monitoring-sg"
  }
}

# IAM Role for monitoring
resource "aws_iam_role" "monitoring_role" {
  name = "monitoring_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for monitoring
resource "aws_iam_policy" "monitoring_policy" {
  name        = "monitoring-policy"
  description = "Policy allowing access to CloudWatch metrics and EC2 discovery"

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

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "monitoring_policy_attachment" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

# Create an instance profile
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "monitoring-profile"
  role = aws_iam_role.monitoring_role.name
}


# Update the web security group to allow Prometheus to scrape metrics
resource "aws_security_group_rule" "allow_prometheus" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  security_group_id = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.monitoring_sg.id
  description       = "Allow Prometheus to scrape node_exporter metrics"
}

# Output the public IP of the monitoring instance
output "monitoring_ip" {
  value = aws_instance.monitoring.public_ip
  description = "Public IP address of the Prometheus/Grafana server"
}

output "grafana_url" {
  value = "http://${aws_instance.monitoring.public_ip}:3000"
  description = "URL to access Grafana (default credentials: admin/admin)"
}

output "prometheus_url" {
  value = "http://${aws_instance.monitoring.public_ip}:9090"
  description = "URL to access Prometheus"
}