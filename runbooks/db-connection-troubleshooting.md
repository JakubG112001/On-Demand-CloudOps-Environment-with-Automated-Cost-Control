# Database Connection Troubleshooting Runbook

## Overview
This runbook covers troubleshooting database connection issues in the CloudOps platform.

## Symptoms
- Application returning 500 errors
- High database connection count alerts
- Slow response times
- Connection timeout errors in logs

## Immediate Response (5 minutes)

### 1. Check Current Status
```bash
# Check RDS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=cloudops-platform-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

### 2. Check Application Logs
```bash
# View recent application logs
aws logs filter-log-events \
  --log-group-name /aws/ec2/cloudops \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"
```

### 3. Verify RDS Status
```bash
# Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier cloudops-platform-db \
  --query 'DBInstances[0].DBInstanceStatus'
```

## Investigation Steps

### Check Connection Pool
1. Review application connection pool settings
2. Monitor active vs idle connections
3. Check for connection leaks in application code

### Database Performance
```bash
# Check CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=cloudops-platform-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Network Connectivity
1. Test connectivity from EC2 instances to RDS
2. Verify security group rules
3. Check subnet routing

## Resolution Steps

### Immediate Mitigation
1. **Restart Application Instances**
   ```bash
   # Terminate instances to force refresh
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name cloudops-platform-asg \
     --desired-capacity 0
   
   # Wait 2 minutes, then restore
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name cloudops-platform-asg \
     --desired-capacity 2
   ```

2. **Scale Up if Needed**
   ```bash
   # Increase capacity temporarily
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name cloudops-platform-asg \
     --desired-capacity 4
   ```

### Long-term Fixes
1. **Optimize Connection Pooling**
   - Review and tune connection pool size
   - Implement connection timeout settings
   - Add connection retry logic

2. **Database Optimization**
   - Review slow query logs
   - Optimize database queries
   - Consider read replicas for read-heavy workloads

3. **Monitoring Improvements**
   - Add application-level connection metrics
   - Set up proactive alerts for connection exhaustion
   - Implement circuit breaker pattern

## Prevention
- Regular connection pool monitoring
- Automated connection leak detection
- Load testing with realistic connection patterns
- Database performance baseline monitoring

## Escalation
- **Level 1**: Application restart (5 minutes)
- **Level 2**: Database parameter tuning (15 minutes)
- **Level 3**: Architecture review and scaling (30+ minutes)

## Related Incidents
- [Incident 002: DB Connection Exhaustion](../incidents/incident-002-db-connection-exhaustion.md)