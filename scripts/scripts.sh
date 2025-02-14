# scripts/before_install.sh
#!/bin/bash
yum update -y
yum install -y httpd

# scripts/after_install.sh
#!/bin/bash
chmod -R 755 /var/www/html

# scripts/start_application.sh
#!/bin/bash
systemctl start httpd
systemctl enable httpd

# scripts/validate_service.sh
#!/bin/bash
systemctl status httpd