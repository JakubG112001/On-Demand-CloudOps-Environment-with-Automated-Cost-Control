# High CPU Utilization Response Runbook

## Overview
Response procedures for high CPU utilization alerts in the CloudOps platform.

## Alert Triggers
- CPU utilization > 80% for 10 minutes
- Auto-scaling events triggered
- Application response time degradation

## Immediate Response (2 minutes)

### 1. Verify Alert Status
```bash
# Check current CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=cloudops-platform-asg \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

### 2. Check Auto Scaling Status
```bash
# Verify auto scaling group status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names cloudops-platform-asg \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Current:Instances[?LifecycleState==`InService`] | length(@)}'
```

### 3. Monitor Application Health
```bash
# Check load balancer target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names cloudops-platform-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

## Investigation Steps

### Identify Root Cause
1. **Traffic Spike Analysis**
   ```bash
   # Check request count
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ApplicationELB \
     --metric-name RequestCount \
     --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers \
       --names cloudops-platform-alb \
       --query 'LoadBalancers[0].LoadBalancerArn' \
       --output text | cut -d'/' -f2-) \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Sum
   ```

2. **Process Analysis**
   ```bash
   # SSH to instance and check processes (if needed)
   # Note: Requires bastion host or Systems Manager
   top -n 1 -b | head -20
   ps aux --sort=-%cpu | head -10
   ```

3. **Application Logs Review**
   ```bash
   # Check for errors or unusual patterns
   aws logs filter-log-events \
     --log-group-name /aws/ec2/cloudops \
     --start-time $(date -d '1 hour ago' +%s)000 \
     --filter-pattern "[timestamp, request_id, ERROR]"
   ```

## Resolution Actions

### Automatic Scaling
The system should automatically scale up when CPU > 80%. Verify this is working:

```bash
# Check recent scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name cloudops-platform-asg \
  --max-items 5
```

### Manual Intervention (if auto-scaling fails)
```bash
# Manually increase capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name cloudops-platform-asg \
  --desired-capacity 4

# Update max capacity if needed
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name cloudops-platform-asg \
  --max-size 8
```

### Application-Level Fixes
1. **Restart Problematic Instances**
   ```bash
   # Identify and terminate high-CPU instances
   # Auto Scaling will replace them
   aws ec2 terminate-instances --instance-ids i-1234567890abcdef0
   ```

2. **Database Query Optimization**
   - Check for long-running queries
   - Review recent code deployments
   - Verify database connection pooling

## Monitoring During Incident

### Key Metrics to Watch
```bash
# CPU utilization trend
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=cloudops-platform-asg \
  --start-time $(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Response time impact
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers \
    --names cloudops-platform-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text | cut -d'/' -f2-) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Post-Incident Actions

### Immediate (within 1 hour)
1. Verify system stability
2. Document timeline and actions taken
3. Check if scaling policies need adjustment

### Follow-up (within 24 hours)
1. Analyze root cause
2. Review auto-scaling thresholds
3. Consider instance type optimization
4. Update monitoring and alerting if needed

## Prevention Strategies
- **Proactive Scaling**: Lower CPU threshold for scaling (70%)
- **Load Testing**: Regular performance testing
- **Code Review**: Performance impact assessment for deployments
- **Monitoring**: Application-level performance metrics

## Escalation Path
- **0-15 minutes**: Automated scaling response
- **15-30 minutes**: Manual scaling intervention
- **30+ minutes**: Architecture review and emergency scaling

## Related Documentation
- [Auto Scaling Configuration](../terraform/ec2.tf)
- [Incident 001: High CPU Usage](../incidents/incident-001-high-cpu.md)