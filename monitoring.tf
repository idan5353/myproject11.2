resource "aws_ssm_parameter" "cw_agent" {
  name  = "/cloudwatch-agent/config"
  type  = "String"
  value = jsonencode({
    metrics = {
      metrics_collected = {
        cpu = {
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_iowait",
            "cpu_usage_user",
            "cpu_usage_system"
          ],
          metrics_collection_interval = 60
        },
        memory = {
          measurement = [
            "mem_used_percent",
            "mem_available_percent"
          ],
          metrics_collection_interval = 60
        },
        disk = {
          measurement = [
            "disk_used_percent",
            "disk_free"
          ],
          metrics_collection_interval = 60,
          resources = ["/"]
        }
      }
    }
  })
}

# SNS Topic for monitoring alerts
resource "aws_sns_topic" "monitoring_alerts" {
  name = "ec2-monitoring-alerts"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "web-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions      = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_alarm" {
  alarm_name          = "web-memory-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 memory usage"
  alarm_actions      = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_alarm" {
  alarm_name          = "web-disk-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors EC2 disk usage"
  alarm_actions      = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
    path                 = "/"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "ec2_dashboard" {
  dashboard_name = "EC2-Monitoring-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name]
          ]
          period = 300
          stat   = "Average"
          region = "us-west-2"
          title  = "CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name]
          ]
          period = 300
          stat   = "Average"
          region = "us-west-2"
          title  = "Memory Usage"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["CWAgent", "disk_used_percent", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name, "path", "/"]
          ]
          period = 300
          stat   = "Average"
          region = "us-west-2"
          title  = "Disk Usage"
        }
      }
    ]
  })
}

# Add CloudWatch agent policy to your existing EC2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
# Add CloudWatch Logs permissions to EC2 role
resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "cloudwatch-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}