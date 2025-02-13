# 🌐 AWS Web Application Infrastructure

## 🎯 Overview
This project implements a scalable, secure web application infrastructure on AWS using Terraform. The architecture includes auto-scaling EC2 instances, CloudFront distribution, WAF security, monitoring, and CI/CD pipeline integration.

## 🏗️ Architecture
The infrastructure consists of several key components:

### 🌍 Frontend Delivery
- 🚀 CloudFront Distribution for global content delivery
- 🛡️ WAF (Web Application Firewall) for security
- ⚖️ Application Load Balancer for traffic distribution

### 💻 Compute Layer
- ⚡ Auto Scaling Group managing EC2 instances
- 📋 Custom Launch Template with Apache web server
- 🌍 Multiple availability zones for high availability

### 📊 Monitoring & Analytics
- 📈 CloudWatch monitoring with custom metrics
- 📱 SNS notifications for alerts
- 📉 CloudWatch Dashboard for metrics visualization
- 🗄️ DynamoDB for visitor analytics

### 🔄 CI/CD Pipeline
- 🔁 CodePipeline for automated deployments
- 🏗️ CodeBuild for building artifacts
- 🚀 CodeDeploy for deployment automation
- 🗂️ S3 bucket for artifact storage

## ✅ Prerequisites
- ☁️ AWS Account
- 🛠️ Terraform >= 1.0.0
- 💻 AWS CLI configured
- 📦 GitHub repository
- 🔑 Proper IAM permissions

## 📁 Directory Structure
```
├── main.tf                 # Main infrastructure configuration
├── dynamodb.tf             # DynamoDB configuration
├── variables.tf            # Variable definitions
├── outputs.tf             # Output definitions
├── buildspec.yml          # CodeBuild specifications
└── README.md              # Project documentation
```

## 🚀 Quick Start

1. Clone the repository:
```bash
git clone https://github.com/your-username/your-repo.git
cd your-repo
```

2. Update the variables:
- 🌍 Modify `region` in provider block
- 🔄 Update VPC and subnet IDs
- ⚙️ Adjust instance types and counts as needed

3. Initialize Terraform:
```bash
terraform init
```

4. Review the execution plan:
```bash
terraform plan
```

5. Apply the configuration:
```bash
terraform apply
```

## ⚙️ Configuration Details

### 🌐 VPC Configuration
- 🌍 Region: us-west-2
- 🔗 VPC ID: vpc-052392afe48c5a6ac
- 🌐 Subnets: subnet-096a7c55adcfb1322, subnet-03cc4e1accf07603e

### 💻 EC2 Configuration
- 🖥️ Instance Type: t2.micro
- 💾 AMI: ami-0005ee01bca55ab66
- ⚡ Auto Scaling: Min 1, Max 3, Desired 2

### 📊 Monitoring Setup
- 📈 CPU Utilization Alarm: Threshold 80%
- 💾 Memory Usage Alarm: Threshold 80%
- 💽 Disk Usage Alarm: Threshold 85%
- 📊 Custom CloudWatch Dashboard

### 🔒 Security Features
- 🛡️ WAF rules for rate limiting and SQL injection protection
- 🚪 Security groups for controlled access
- 🔑 IAM roles with least privilege access

## 🔧 Maintenance

### 🔄 Updating the Infrastructure
1. Make changes to the Terraform files
2. Run `terraform plan` to review changes
3. Apply changes with `terraform apply`

### 👀 Monitoring
- 📊 Access CloudWatch Dashboard for metrics
- 📱 Configure SNS topic subscription for alerts
- 📝 Review WAF logs periodically

### 💾 Backup and Recovery
- 🔄 DynamoDB has point-in-time recovery enabled
- 🔁 EC2 instances are replaceable through Auto Scaling
- 📦 S3 artifacts are versioned

## 🔄 CI/CD Pipeline

### 🔗 GitHub Integration
- 📂 Repository: https://github.com/idan5353/myproject11.2.git
- 🌿 Branch: main
- 🔔 Webhook configured for automatic triggers

### 🚀 Build and Deploy Process
1. Code pushed to GitHub
2. CodePipeline triggered automatically
3. CodeBuild creates artifacts
4. CodeDeploy updates EC2 instances

## 💰 Cost Optimization
- 💳 CloudFront price class set to PriceClass_100
- 📊 Auto Scaling optimizes instance count
- 💵 DynamoDB on-demand pricing

## 🔍 Troubleshooting

### ❗ Common Issues
1. Instance not launching
   - 🔍 Check security group rules
   - 🔑 Verify IAM roles
   - 📋 Review launch template

2. Deployment failures
   - 📝 Check CodeBuild logs
   - 🔍 Verify buildspec.yml
   - 🔑 Review IAM permissions

### 🆘 Support
For issues or questions:
1. 🎫 Open a GitHub issue
2. 📊 Review CloudWatch logs
3. 🏥 Check AWS service health dashboard

## 👥 Contributing
1. 🍴 Fork the repository
2. 🌿 Create a feature branch
3. 📝 Submit a pull request

## 📜 License
[Your chosen license]

## ✍️ Authors
- 👨‍💻 Your Name
- 👥 Additional Contributors