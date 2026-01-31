# Incident 002: Database Connection Exhaustion

## Incident Summary
- **Incident ID**: INC-002
- **Date**: 2024-01-22
- **Duration**: 25 minutes (09:15 - 09:40 UTC)
- **Severity**: High
- **Status**: Resolved
- **Impact**: 15% error rate, partial service degradation

## Timeline

### 09:15 UTC - Detection
- Multiple 500 errors reported by users
- CloudWatch alarm: High database connection count (>20)
- Application logs showing "connection pool exhausted" errors

### 09:17 UTC - Initial Assessment
- On-call engineer paged via PagerDuty
- Confirmed database connection exhaustion
- Error rate at 15% and climbing

### 09:20 UTC - Emergency Response
- Identified connection leak in user update endpoint
- Immediately restarted all application instances
- Scaled ASG to 0 then back to 2 for clean restart

### 09:25 UTC - Temporary Fix Applied
- Database connections dropped to normal levels
- Error rate decreased to <1%
- Monitoring connection pool closely

### 09:30 UTC - Root Cause Confirmed
- Code review revealed missing connection.close() in error handling
- Recent deployment (v1.2.3) introduced the bug
- Prepared hotfix for immediate deployment

### 09:40 UTC - Resolution
- Hotfix deployed (v1.2.4)
- All metrics returned to normal
- Incident declared resolved

## Root Cause Analysis

### Primary Cause
**Code Bug**: Missing database connection cleanup in error handling path of the user update endpoint (`PUT /api/users/:id`).

### Technical Details
```javascript
// Problematic code in v1.2.3
app.put('/api/users/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    const result = await client.query('UPDATE users SET ...');
    client.release(); // Only released on success
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
    // BUG: client.release() missing in catch block
  }
});
```

### Contributing Factors
1. **Insufficient Code Review**: Bug not caught during PR review
2. **Missing Integration Tests**: No tests for error scenarios with database connections
3. **Inadequate Monitoring**: No alerts for connection pool utilization
4. **Deployment Process**: No automated rollback on error rate increase

### Trigger Event
- User attempted to update profile with invalid data
- Error handling path executed without releasing connection
- Multiple users hit the same error, exhausting connection pool

## Impact Assessment

### User Impact
- **Error Rate**: 15% of requests failed during peak (09:20-09:25)
- **Affected Users**: ~150 users experienced errors
- **Functionality**: User profile updates completely unavailable
- **Duration**: 25 minutes total, 10 minutes of high error rate

### Business Impact
- Customer support tickets increased by 300%
- Temporary loss of user trust
- No data corruption or loss
- Estimated revenue impact: <$500

### System Impact
- Database connection pool exhausted (22/20 connections)
- Application instances became unresponsive
- Load balancer marked instances as unhealthy
- Auto-scaling triggered but couldn't resolve the issue

## Resolution Actions

### Immediate Fixes (Completed within 2 hours)
1. ✅ **Hotfix Deployed**: Added proper connection cleanup in all error paths
2. ✅ **Code Review**: Audited all database connection usage patterns
3. ✅ **Monitoring Added**: Connection pool utilization alerts
4. ✅ **Testing**: Added integration tests for error scenarios

### Short-term Improvements (Within 1 week)
1. 🔄 **Enhanced Code Review**: Mandatory database connection review checklist
2. 🔄 **Automated Testing**: Connection leak detection in CI/CD pipeline
3. 🔄 **Monitoring Dashboard**: Real-time connection pool visualization
4. 🔄 **Deployment Safety**: Automatic rollback on error rate >5%

### Long-term Improvements (Within 1 month)
1. 📋 **Connection Pool Optimization**: Implement connection pooling best practices
2. 📋 **Database Proxy**: Consider RDS Proxy for connection management
3. 📋 **Circuit Breaker**: Implement circuit breaker pattern for database calls
4. 📋 **Chaos Engineering**: Regular connection exhaustion testing

## Technical Deep Dive

### Connection Pool Configuration
```javascript
// Current configuration
const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  port: 5432,
  max: 20,        // Maximum connections
  min: 2,         // Minimum connections
  idle: 10000,    // Idle timeout
  acquire: 30000, // Acquire timeout
});
```

### Bug Fix Implementation
```javascript
// Fixed code in v1.2.4
app.put('/api/users/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    const result = await client.query('UPDATE users SET ...');
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    client.release(); // Always release connection
  }
});
```

### Monitoring Improvements
```javascript
// Added connection pool monitoring
setInterval(() => {
  console.log('Pool stats:', {
    total: pool.totalCount,
    idle: pool.idleCount,
    waiting: pool.waitingCount
  });
}, 30000);
```

## Lessons Learned

### Code Quality
- **Always use try/finally**: Ensure resource cleanup in all code paths
- **Connection management**: Treat database connections as precious resources
- **Error handling**: Test error scenarios as thoroughly as happy paths
- **Code review focus**: Pay special attention to resource management

### Testing Strategy
- **Integration tests**: Must include error scenarios and resource cleanup
- **Load testing**: Should include connection exhaustion scenarios
- **Automated testing**: CI/CD must catch resource leaks before deployment
- **Chaos engineering**: Regular failure injection to test resilience

### Monitoring and Alerting
- **Proactive monitoring**: Alert on resource utilization, not just failures
- **Real-time dashboards**: Visualize connection pool status
- **Threshold tuning**: Set alerts before resource exhaustion occurs
- **Correlation**: Link application metrics with infrastructure metrics

### Deployment Safety
- **Automated rollback**: Deploy with automatic rollback triggers
- **Gradual rollout**: Use canary deployments for risky changes
- **Health checks**: Comprehensive health checks including resource usage
- **Monitoring during deployment**: Watch key metrics during rollouts

## Metrics and Evidence

### Database Connection Metrics
```
Time     | Total Connections | Idle | Active | Waiting
---------|-------------------|------|--------|--------
09:10    | 8                 | 6    | 2      | 0
09:15    | 15                | 2    | 13     | 0
09:20    | 22                | 0    | 20     | 5
09:25    | 3                 | 2    | 1      | 0
09:30    | 8                 | 6    | 2      | 0
```

### Error Rate Timeline
```
Time     | Total Requests | Errors | Error Rate
---------|----------------|--------|------------
09:10    | 120           | 0      | 0%
09:15    | 145           | 8      | 5.5%
09:20    | 180           | 27     | 15%
09:25    | 160           | 2      | 1.25%
09:30    | 125           | 0      | 0%
```

## Prevention Measures Implemented

### Code Standards
- Mandatory use of try/finally for database connections
- Code review checklist including resource management
- Static analysis rules for connection leak detection
- Automated testing requirements for error paths

### Infrastructure Improvements
- Connection pool monitoring and alerting
- Database connection limits and timeouts
- Automated deployment rollback on error spikes
- Enhanced logging for connection lifecycle

### Process Changes
- Mandatory load testing for database-related changes
- Incident response drill including connection exhaustion
- Regular code audits for resource management patterns
- Cross-team knowledge sharing on database best practices

## Related Documentation
- [Database Connection Troubleshooting Runbook](../runbooks/db-connection-troubleshooting.md)
- [Code Review Guidelines](../docs/code-review-guidelines.md)
- [Database Configuration](../terraform/rds.tf)

## Incident Commander
**Name**: Senior DevOps Engineer  
**Contact**: senior-devops@company.com

## Post-Mortem Actions
- [x] Blameless post-mortem conducted
- [x] Action items assigned with owners and deadlines
- [x] Knowledge sharing session scheduled
- [x] Incident response procedures updated
- [x] Monitoring improvements implemented