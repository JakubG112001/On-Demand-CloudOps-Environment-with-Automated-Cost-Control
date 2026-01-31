import json
import boto3
import random
from datetime import datetime, timedelta

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    
    # Configuration
    TABLE_NAME = 'cloudops-demo-sessions'
    
    try:
        chaos_type = event.get('chaos_type', 'cpu_spike')
        
        # Generate chaos scenario data
        scenarios = {
            'cpu_spike': {
                'title': 'High CPU Usage Detected',
                'severity': 'warning',
                'description': 'CPU utilization spiked to 89% on 2 instances',
                'action': 'Auto-scaling triggered, adding 1 instance',
                'duration': 180,  # seconds
                'metrics': {'cpu': 89, 'instances': 3}
            },
            'memory_leak': {
                'title': 'Memory Leak Detected',
                'severity': 'critical',
                'description': 'Memory usage climbing steadily on instance i-abc123',
                'action': 'Instance restart scheduled, traffic redirected',
                'duration': 240,
                'metrics': {'memory': 92, 'affected_instances': 1}
            },
            'db_slow': {
                'title': 'Database Performance Degradation',
                'severity': 'warning',
                'description': 'Query response time increased to 850ms average',
                'action': 'Connection pool optimized, slow queries identified',
                'duration': 300,
                'metrics': {'response_time': 850, 'connections': 18}
            },
            'network_latency': {
                'title': 'Network Latency Spike',
                'severity': 'warning',
                'description': 'Inter-AZ latency increased to 45ms',
                'action': 'Traffic routing optimized, monitoring increased',
                'duration': 120,
                'metrics': {'latency': 45, 'affected_requests': 15}
            }
        }
        
        scenario = scenarios.get(chaos_type, scenarios['cpu_spike'])
        
        # Create incident timeline
        now = datetime.utcnow()
        incident_id = f'INC-{random.randint(1000, 9999)}'
        
        timeline = [
            {
                'time': (now - timedelta(seconds=scenario['duration'])).isoformat(),
                'event': f"🚨 {scenario['title']}",
                'status': 'detected'
            },
            {
                'time': (now - timedelta(seconds=scenario['duration']-30)).isoformat(),
                'event': f"🔍 Root cause analysis started",
                'status': 'investigating'
            },
            {
                'time': (now - timedelta(seconds=scenario['duration']-60)).isoformat(),
                'event': f"⚡ {scenario['action']}",
                'status': 'mitigating'
            },
            {
                'time': (now - timedelta(seconds=30)).isoformat(),
                'event': f"✅ Metrics returning to normal",
                'status': 'recovering'
            },
            {
                'time': now.isoformat(),
                'event': f"🎉 Incident resolved - system stable",
                'status': 'resolved'
            }
        ]
        
        incident_data = {
            'incident_id': incident_id,
            'title': scenario['title'],
            'severity': scenario['severity'],
            'description': scenario['description'],
            'timeline': timeline,
            'metrics': scenario['metrics'],
            'resolved': True,
            'resolution_time': f"{scenario['duration']}s"
        }
        
        # Store incident in DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(Item={
            'sessionId': f'incident-{incident_id}',
            'type': 'incident',
            'data': incident_data,
            'ttl': int(datetime.utcnow().timestamp()) + 3600
        })
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'message': f'Chaos scenario "{chaos_type}" simulated',
                'incident': incident_data
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }