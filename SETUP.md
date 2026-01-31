# CloudOps Platform Setup Guide

## Prerequisites

### Required Tools
- **AWS CLI** (v2.x): [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** (v1.0+): [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Git**: For version control
- **curl**: For testing API endpoints

### AWS Account Setup
1. **AWS Account**: Active AWS account with billing enabled
2. **IAM User**: Create IAM user with programmatic access
3. **Required Permissions**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:*",
           "rds:*",
           "elasticloadbalancing:*",
           "autoscaling:*",
           "cloudwatch:*",
           "logs:*",
           "sns:*",
           "iam:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

## Quick Start

### 1. Clone Repository
```bash
git clone <your-repository-url>
cd cloudops-platform
```

### 2. Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (us-east-1)
```

### 3. Set Environment Variables
```bash
export DB_PASSWORD="YourSecurePassword123!"
export NOTIFICATION_EMAIL="your-email@example.com"
```

### 4. Deploy Infrastructure
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh deploy
```

### 5. Verify Deployment
The script will automatically test the deployment, but you can also manually verify:
```bash
# Check application health
curl http://<alb-dns-name>/health

# Test API endpoints
curl -X POST http://<alb-dns-name>/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'

curl http://<alb-dns-name>/api/users
```

## GitHub Repository Setup

### 1. Create GitHub Repository
```bash
# Create new repository on GitHub, then:
git remote add origin https://github.com/yourusername/cloudops-platform.git
git branch -M main
git push -u origin main
```

### 2. Configure GitHub Secrets
Go to your repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `DB_PASSWORD`: Database password
- `NOTIFICATION_EMAIL`: Email for notifications

### 3. Enable GitHub Actions
The CI/CD pipeline will automatically trigger on:
- **Pull Requests**: Runs `terraform plan`
- **Push to main**: Runs `terraform apply`

## Project Structure Explained

```
cloudops-platform/
├── README.md                    # Project overview
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                 # VPC, networking
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── security_groups.tf      # Security configurations
│   ├── rds.tf                  # Database setup
│   ├── ec2.tf                  # Compute resources
│   ├── alb.tf                  # Load balancer
│   ├── monitoring.tf           # CloudWatch & SNS
│   └── user_data.sh           # EC2 initialization script
├── .github/workflows/          # CI/CD pipelines
│   └── deploy.yml             # GitHub Actions workflow
├── runbooks/                   # Operational procedures
│   ├── db-connection-troubleshooting.md
│   ├── high-cpu-response.md
│   └── rollback-procedure.md
├── incidents/                  # Incident documentation
│   ├── incident-001-high-cpu.md
│   └── incident-002-db-connection-exhaustion.md
├── postmortems/               # Post-incident analysis
└── scripts/                   # Automation scripts
    ├── deploy.sh              # Deployment automation
    └── chaos-engineering.sh   # Failure testing
```

## Architecture Overview

### Network Architecture
- **VPC**: 10.0.0.0/16 with public and private subnets
- **Public Subnets**: ALB and NAT Gateway
- **Private Subnets**: EC2 instances and RDS database
- **Multi-AZ**: Resources distributed across 2 availability zones

### Compute Layer
- **Auto Scaling Group**: 2-6 EC2 instances (t3.micro)
- **Application Load Balancer**: Distributes traffic
- **Launch Template**: Standardized instance configuration

### Database Layer
- **RDS PostgreSQL**: Multi-AZ deployment
- **Encryption**: At rest and in transit
- **Backups**: 7-day retention with automated backups

### Monitoring & Alerting
- **CloudWatch**: Metrics, logs, and alarms
- **SNS**: Email notifications for alerts
- **Auto Scaling**: CPU-based scaling policies

## Operational Procedures

### Daily Operations
1. **Monitor Dashboard**: Check CloudWatch dashboard
2. **Review Alerts**: Address any SNS notifications
3. **Check Logs**: Review application and system logs
4. **Capacity Planning**: Monitor resource utilization

### Weekly Operations
1. **Security Updates**: Apply OS and application patches
2. **Backup Verification**: Ensure RDS backups are working
3. **Performance Review**: Analyze response times and errors
4. **Cost Optimization**: Review AWS costs and usage

### Monthly Operations
1. **Chaos Engineering**: Run failure scenarios
2. **Disaster Recovery**: Test backup and restore procedures
3. **Security Audit**: Review access logs and permissions
4. **Documentation Update**: Keep runbooks current

## Monitoring and Alerting

### Key Metrics
- **CPU Utilization**: EC2 and RDS
- **Response Time**: Application performance
- **Error Rate**: 4xx and 5xx errors
- **Database Connections**: Connection pool usage
- **Disk Usage**: Storage utilization

### Alert Thresholds
- **High CPU**: >80% for 10 minutes
- **High Response Time**: >1 second average
- **High Error Rate**: >10 errors in 5 minutes
- **Database Connections**: >15 concurrent connections

### Dashboard Access
CloudWatch Dashboard: `https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=cloudops-platform-dashboard`

## Troubleshooting

### Common Issues

#### 1. Deployment Fails
```bash
# Check Terraform state
cd terraform
terraform show

# Validate configuration
terraform validate

# Check AWS credentials
aws sts get-caller-identity
```

#### 2. Application Not Responding
```bash
# Check instance health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names cloudops-platform-asg

# View application logs
aws logs filter-log-events --log-group-name /aws/ec2/cloudops --start-time $(date -d '1 hour ago' +%s)000
```

#### 3. Database Connection Issues
```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier cloudops-platform-db

# Monitor connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=cloudops-platform-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Getting Help
1. **Check Runbooks**: Detailed procedures in `runbooks/` directory
2. **Review Incidents**: Past incident reports in `incidents/` directory
3. **AWS Documentation**: [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
4. **Terraform Documentation**: [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Security Considerations

### Network Security
- Private subnets for application and database tiers
- Security groups with minimal required access
- No direct internet access to application instances

### Data Security
- RDS encryption at rest and in transit
- CloudWatch log encryption
- IAM roles with least privilege access

### Access Control
- No SSH keys in launch template (use Systems Manager)
- Database access only from application security group
- Regular security group audits

## Cost Optimization

### Current Costs (Estimated)
- **EC2 Instances**: ~$30/month (2 t3.micro instances)
- **RDS**: ~$25/month (db.t3.micro Multi-AZ)
- **Load Balancer**: ~$20/month
- **Data Transfer**: ~$5/month
- **Total**: ~$80/month

### Cost Reduction Strategies
1. **Reserved Instances**: 30-60% savings for predictable workloads
2. **Spot Instances**: Use for non-critical workloads
3. **Right-sizing**: Monitor and adjust instance types
4. **Scheduled Scaling**: Scale down during off-hours

## Next Steps

### Immediate (First Week)
1. ✅ Deploy infrastructure
2. ✅ Configure monitoring
3. ✅ Test all endpoints
4. ✅ Verify alerting works

### Short-term (First Month)
1. 📋 Run chaos engineering tests
2. 📋 Implement additional monitoring
3. 📋 Optimize database queries
4. 📋 Add caching layer

### Long-term (3+ Months)
1. 📋 Implement blue/green deployments
2. 📋 Add container orchestration
3. 📋 Implement service mesh
4. 📋 Add advanced security scanning

## Support and Maintenance

### Regular Tasks
- **Daily**: Monitor alerts and logs
- **Weekly**: Review performance metrics
- **Monthly**: Update dependencies and patches
- **Quarterly**: Disaster recovery testing

### Escalation Procedures
1. **Level 1**: Automated responses and basic troubleshooting
2. **Level 2**: Manual intervention and advanced diagnostics
3. **Level 3**: Architecture changes and emergency procedures

This setup guide provides everything needed to deploy and operate the CloudOps platform successfully. Follow the procedures, monitor the system, and continuously improve based on operational experience.