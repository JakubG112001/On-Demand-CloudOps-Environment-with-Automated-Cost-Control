# Failed Deployment Rollback Procedure

## Overview
Step-by-step procedure for rolling back failed deployments in the CloudOps platform.

## When to Rollback
- Health checks failing after deployment
- Error rate > 5% for 5+ minutes
- Critical functionality broken
- Performance degradation > 50%

## Pre-Rollback Checklist
- [ ] Confirm deployment failure (not infrastructure issue)
- [ ] Identify last known good version
- [ ] Notify team of rollback decision
- [ ] Document failure symptoms

## Rollback Methods

### Method 1: GitHub Actions Rollback (Recommended)

#### 1. Identify Last Good Commit
```bash
# Find the last successful deployment
git log --oneline --grep="Deploy CloudOps Platform" | head -5
```

#### 2. Trigger Rollback Deployment
```bash
# Create rollback branch from last good commit
git checkout -b rollback-$(date +%Y%m%d-%H%M%S) <last-good-commit>
git push origin rollback-$(date +%Y%m%d-%H%M%S)

# Create PR to main branch
# This will trigger the deployment pipeline
```

### Method 2: Manual Terraform Rollback

#### 1. Revert Infrastructure Changes
```bash
cd terraform

# If infrastructure changes need reverting
git checkout <last-good-commit> -- .
terraform plan -var="db_password=$DB_PASSWORD" -var="notification_email=$NOTIFICATION_EMAIL"
terraform apply -auto-approve -var="db_password=$DB_PASSWORD" -var="notification_email=$NOTIFICATION_EMAIL"
```

#### 2. Force Instance Refresh
```bash
# Terminate all instances to force new deployment
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name cloudops-platform-asg \
  --desired-capacity 0

# Wait for termination
sleep 120

# Restore capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name cloudops-platform-asg \
  --desired-capacity 2
```

### Method 3: Emergency Instance Replacement

#### 1. Update Launch Template
```bash
# Get current launch template
TEMPLATE_ID=$(aws ec2 describe-launch-templates \
  --filters "Name=tag:Name,Values=cloudops-platform-*" \
  --query 'LaunchTemplates[0].LaunchTemplateId' \
  --output text)

# Create new version with previous AMI or user data
aws ec2 create-launch-template-version \
  --launch-template-id $TEMPLATE_ID \
  --source-version 1 \
  --launch-template-data file://rollback-user-data.json
```

#### 2. Update Auto Scaling Group
```bash
# Update ASG to use new template version
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name cloudops-platform-asg \
  --launch-template LaunchTemplateId=$TEMPLATE_ID,Version='$Latest'

# Force instance refresh
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name cloudops-platform-asg \
  --preferences MinHealthyPercentage=50,InstanceWarmup=300
```

## Verification Steps

### 1. Health Check Verification
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names cloudops-platform-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Test health endpoint
for i in {1..10}; do
  echo "Test $i: $(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health)"
  sleep 10
done
```

### 2. Functional Testing
```bash
# Test API endpoints
echo "Testing user creation..."
curl -X POST http://$ALB_DNS/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'

echo "Testing user retrieval..."
curl http://$ALB_DNS/api/users
```

### 3. Monitor Key Metrics
```bash
# Check error rates
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers \
    --names cloudops-platform-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text | cut -d'/' -f2-) \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Check response times
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers \
    --names cloudops-platform-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text | cut -d'/' -f2-) \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Post-Rollback Actions

### Immediate (0-30 minutes)
1. **Confirm System Stability**
   - All health checks passing
   - Error rates back to normal
   - Response times acceptable

2. **Communication**
   - Notify stakeholders of successful rollback
   - Update incident status
   - Document rollback completion time

### Short-term (30 minutes - 2 hours)
1. **Root Cause Analysis**
   - Identify what caused the deployment failure
   - Review deployment logs and metrics
   - Document findings

2. **Fix Planning**
   - Create plan to fix the original issue
   - Schedule fix deployment
   - Update deployment procedures if needed

### Long-term (2+ hours)
1. **Process Improvement**
   - Review deployment pipeline
   - Enhance testing procedures
   - Update rollback automation

2. **Documentation**
   - Update runbooks based on lessons learned
   - Create post-mortem document
   - Share knowledge with team

## Rollback Time Targets
- **Detection to Decision**: < 5 minutes
- **Decision to Rollback Start**: < 2 minutes
- **Rollback Execution**: < 10 minutes
- **Verification**: < 5 minutes
- **Total Rollback Time**: < 22 minutes

## Prevention Strategies
- **Blue/Green Deployments**: Zero-downtime deployments
- **Canary Releases**: Gradual rollout with monitoring
- **Feature Flags**: Quick feature disable capability
- **Automated Testing**: Comprehensive pre-deployment testing
- **Monitoring**: Real-time deployment health monitoring

## Emergency Contacts
- **On-call Engineer**: [Contact Info]
- **Platform Team Lead**: [Contact Info]
- **Infrastructure Team**: [Contact Info]

## Related Documentation
- [Deployment Pipeline](../.github/workflows/deploy.yml)
- [Monitoring Setup](../terraform/monitoring.tf)
- [Incident Response Procedures](./incident-response.md)