# CloudOps Monitoring & Incident Response Platform (AWS)

A cost-optimized, production-ready infrastructure project demonstrating operational excellence with on-demand resource management.

## 💰 Cost-Optimized Architecture

**Always Running (~$20/month):**
- S3 Static Website
- API Gateway
- Lambda Functions  
- Application Load Balancer
- VPC & Networking

**On-Demand (~$0.50/hour when active):**
- EC2 Auto Scaling Group (starts at 0)
- RDS PostgreSQL (stopped by default)
- CloudWatch Alarms
- SNS Notifications

**Total Monthly Cost: ~$20-25 with occasional demos**

## 🚀 Live Demo

Visit the deployed website and click "Start Demo" to spin up the full infrastructure for 30 minutes, then it automatically shuts down to save costs.

## Architecture Overview

- **Compute**: EC2 instances with Auto Scaling Groups (on-demand)
- **Load Balancing**: Application Load Balancer (always on)
- **Database**: RDS PostgreSQL Single-AZ (on-demand)
- **Monitoring**: CloudWatch metrics, logs, and alarms
- **Alerting**: SNS notifications
- **Infrastructure**: Terraform for IaC
- **CI/CD**: GitHub Actions
- **Demo Control**: S3 + API Gateway + Lambda

## Quick Start

### Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- GitHub repository with secrets configured

### Cost-Optimized Deployment
```bash
# Clone and deploy
git clone <your-repo>
cd cloudops-platform

# Set environment variables
export DB_PASSWORD="YourSecurePassword123!"
export NOTIFICATION_EMAIL="your-email@example.com"

# Deploy with cost optimization
chmod +x scripts/deploy-cost-optimized.sh
./scripts/deploy-cost-optimized.sh deploy
```

### Environment Setup
```bash
# Set required environment variables
export AWS_REGION=us-east-1
export DB_PASSWORD=<secure-password>
export NOTIFICATION_EMAIL=<your-email>
```

## Project Structure

```
├── terraform/              # Infrastructure as Code
│   ├── serverless.tf      # S3, API Gateway, Lambda
│   ├── main.tf            # VPC, networking
│   ├── ec2.tf             # Auto Scaling (starts at 0)
│   ├── rds.tf             # Database (single AZ)
│   └── alb.tf             # Load Balancer
├── website/               # Static demo website
├── lambda/                # Start/stop/status functions
├── .github/workflows/     # CI/CD pipelines
├── runbooks/             # Operational procedures
├── incidents/            # Incident documentation
├── postmortems/          # Post-incident analysis
└── scripts/              # Automation scripts
```

## Demo Control System

### Web Interface
- **Start Demo**: Spins up EC2 + RDS for 30 minutes
- **Stop Demo**: Immediately shuts down expensive resources
- **Check Status**: Shows current infrastructure state
- **Auto-Shutdown**: Automatic cleanup after 30 minutes

### What Happens When You Start Demo
1. Lambda function starts RDS instance
2. Auto Scaling Group scales from 0 to 2 instances
3. EventBridge schedules automatic shutdown
4. Website shows live application URL
5. Full monitoring and alerting becomes active

## Operational Features

### Monitoring & Alerting (Active During Demo)
- CPU utilization alerts (>80%)
- Memory usage monitoring
- Database connection tracking
- Application response time metrics
- Error rate monitoring

### Incident Response
- Automated rollback procedures
- Health check endpoints
- Log aggregation and analysis
- Performance degradation detection

## Application Endpoints (During Demo)

- `GET /health` - Health check
- `POST /api/users` - Create user
- `GET /api/users` - List users
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Delete user

## Operational Documentation

### Runbooks
- [Database Connection Issues](runbooks/db-connection-troubleshooting.md)
- [High CPU Utilization](runbooks/high-cpu-response.md)
- [Failed Deployment Rollback](runbooks/rollback-procedure.md)

### Incident Reports
- [Incident 001: High CPU Usage](incidents/incident-001-high-cpu.md)
- [Incident 002: DB Connection Exhaustion](incidents/incident-002-db-connection-exhaustion.md)

## Chaos Engineering

This project includes intentional failure scenarios:
- Instance termination testing
- Database connection exhaustion
- CPU overload simulation
- Network latency injection

## Metrics & KPIs

- **Availability**: 99.9% uptime target
- **Response Time**: <200ms p95
- **Error Rate**: <0.1%
- **Recovery Time**: <5 minutes
- **Cost Efficiency**: 90% cost reduction vs always-on

## Security

- VPC with private subnets
- Security groups with minimal access
- RDS encryption at rest
- CloudWatch log encryption
- IAM roles with least privilege

## Cost Optimization Features

- **On-Demand Infrastructure**: Expensive resources only run when needed
- **Auto-Shutdown**: Prevents forgotten resources from running
- **Single AZ RDS**: Reduced database costs
- **Minimal Backup Retention**: 1 day instead of 7
- **t3.micro Instances**: Smallest viable instance size
- **Serverless Control**: Lambda + API Gateway for management