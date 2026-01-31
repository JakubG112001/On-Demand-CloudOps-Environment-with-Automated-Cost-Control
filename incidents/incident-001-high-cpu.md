# Incident 001: High CPU Usage Event

## Incident Summary
- **Incident ID**: INC-001
- **Date**: 2024-01-15
- **Duration**: 45 minutes (14:30 - 15:15 UTC)
- **Severity**: Medium
- **Status**: Resolved
- **Impact**: Increased response times, no service outage

## Timeline

### 14:30 UTC - Detection
- CloudWatch alarm triggered: CPU utilization > 80%
- Auto-scaling policy activated
- SNS alert sent to on-call engineer

### 14:32 UTC - Initial Response
- On-call engineer acknowledged alert
- Verified auto-scaling group status
- Confirmed new instances launching

### 14:35 UTC - Investigation Started
- Reviewed CloudWatch metrics
- Identified traffic spike: 300% increase in requests
- Checked application logs for errors

### 14:40 UTC - Root Cause Identified
- Traffic spike caused by marketing campaign launch
- Database queries not optimized for increased load
- Connection pool exhaustion on some instances

### 14:45 UTC - Mitigation Actions
- Manually increased ASG desired capacity from 2 to 6 instances
- Restarted application on instances showing connection issues
- Monitored database connection metrics

### 15:00 UTC - Stabilization
- CPU utilization dropped below 60%
- Response times returned to normal (<200ms)
- All health checks passing

### 15:15 UTC - Resolution
- System fully stabilized
- Reduced ASG capacity to 4 instances (keeping buffer)
- Incident marked as resolved

## Root Cause Analysis

### Primary Cause
Unexpected traffic surge (3x normal load) from marketing campaign that wasn't communicated to the infrastructure team.

### Contributing Factors
1. **Inadequate Capacity Planning**: Auto-scaling thresholds set for normal traffic patterns
2. **Database Query Performance**: Some queries not optimized for high concurrency
3. **Connection Pool Configuration**: Pool size insufficient for peak load
4. **Lack of Load Testing**: System not tested at 3x capacity

### What Went Well
- Auto-scaling responded correctly and launched new instances
- Monitoring and alerting worked as designed
- Response time was quick (2 minutes to acknowledgment)
- No data loss or corruption occurred

### What Could Be Improved
- Earlier communication about traffic spikes
- More aggressive auto-scaling thresholds
- Better database query optimization
- Load testing at higher capacity levels

## Impact Assessment

### User Impact
- **Response Time**: Increased from ~100ms to ~800ms during peak
- **Error Rate**: Remained below 0.1% (no user-facing errors)
- **Availability**: 100% uptime maintained

### Business Impact
- No revenue loss
- Marketing campaign continued successfully
- Customer satisfaction maintained

### Technical Impact
- Temporary performance degradation
- Increased AWS costs due to scaling
- Database connection pool stress

## Resolution Actions

### Immediate Fixes (Completed)
1. ✅ Increased ASG max capacity from 6 to 10 instances
2. ✅ Lowered CPU scaling threshold from 80% to 70%
3. ✅ Optimized top 3 database queries identified during incident
4. ✅ Increased database connection pool size from 10 to 20

### Short-term Improvements (Within 1 week)
1. 🔄 Implement predictive scaling based on scheduled events
2. 🔄 Add application-level metrics for connection pool monitoring
3. 🔄 Create load testing scenarios for 5x normal capacity
4. 🔄 Establish communication process for marketing campaigns

### Long-term Improvements (Within 1 month)
1. 📋 Implement database read replicas for read-heavy operations
2. 📋 Add caching layer (Redis/ElastiCache) for frequently accessed data
3. 📋 Develop automated performance testing in CI/CD pipeline
4. 📋 Create capacity planning dashboard with traffic forecasting

## Lessons Learned

### Technical Lessons
- Auto-scaling works but needs tuning for rapid traffic changes
- Database connection pooling is critical for high-concurrency scenarios
- Query optimization has significant impact under load
- Monitoring granularity should match scaling speed requirements

### Process Lessons
- Cross-team communication is essential for capacity planning
- Load testing should include realistic peak scenarios
- Incident response procedures worked well but can be streamlined
- Documentation and runbooks proved valuable during response

### Organizational Lessons
- Marketing and infrastructure teams need better coordination
- Proactive capacity planning prevents reactive scaling issues
- Investment in performance optimization pays off during incidents
- Regular chaos engineering exercises would help identify weaknesses

## Metrics and Data

### Performance Metrics
```
Metric                  | Normal    | During Incident | Peak
------------------------|-----------|-----------------|--------
CPU Utilization         | 25%       | 85%            | 92%
Response Time (p95)     | 120ms     | 650ms          | 890ms
Requests/minute         | 1,200     | 3,600          | 4,200
Database Connections    | 8         | 18             | 22
Active Instances        | 2         | 4              | 6
```

### Cost Impact
- Additional EC2 costs: ~$15 for 4 hours of extra capacity
- No data transfer cost increase
- Total incident cost: <$20

## Follow-up Actions

### Monitoring Improvements
- Added dashboard for marketing campaign traffic patterns
- Created alerts for rapid traffic increase (>50% in 5 minutes)
- Implemented connection pool utilization monitoring

### Process Changes
- Weekly capacity planning meetings with marketing team
- Mandatory infrastructure review for campaigns >2x normal traffic
- Updated incident response procedures with new escalation paths

### Technical Debt
- Database query optimization backlog created
- Connection pool configuration review scheduled
- Load testing framework implementation planned

## Related Documentation
- [High CPU Response Runbook](../runbooks/high-cpu-response.md)
- [Auto Scaling Configuration](../terraform/ec2.tf)
- [Monitoring Setup](../terraform/monitoring.tf)

## Incident Commander
**Name**: DevOps Engineer  
**Contact**: devops@company.com

## Post-Mortem Meeting
**Date**: 2024-01-16 10:00 UTC  
**Attendees**: DevOps, Backend, Marketing teams  
**Recording**: [Link to meeting recording]