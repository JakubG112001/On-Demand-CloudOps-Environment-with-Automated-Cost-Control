import json
import random
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    try:
        scenarios = {'cpu_spike': {'title': 'High CPU Usage Detected', 'severity': 'warning', 'description': 'CPU utilization spiked to 89% on 2 instances', 'action': 'Auto-scaling triggered, adding 1 instance', 'duration': 180, 'metrics': {'cpu': 89, 'instances': 3}}, 'memory_leak': {'title': 'Memory Leak Detected', 'severity': 'critical', 'description': 'Memory usage climbing steadily on instance i-abc123', 'action': 'Instance restart scheduled, traffic redirected', 'duration': 240, 'metrics': {'memory': 92, 'affected_instances': 1}}, 'db_slow': {'title': 'Database Performance Degradation', 'severity': 'warning', 'description': 'Query response time increased to 850ms average', 'action': 'Connection pool optimized, slow queries identified', 'duration': 300, 'metrics': {'response_time': 850, 'connections': 18}}, 'network_latency': {'title': 'Network Latency Spike', 'severity': 'warning', 'description': 'Inter-AZ latency increased to 45ms', 'action': 'Traffic routing optimized, monitoring increased', 'duration': 120, 'metrics': {'latency': 45, 'affected_requests': 15}}}
        
        s = scenarios.get(event.get('chaos_type', 'cpu_spike'), scenarios['cpu_spike'])
        now = datetime.utcnow()
        inc_id = f'INC-{random.randint(1000, 9999)}'
        
        incident = {'incident_id': inc_id, 'title': s['title'], 'severity': s['severity'], 'description': s['description'], 'timeline': [{'time': (now - timedelta(seconds=s['duration'])).isoformat(), 'event': f"🚨 {s['title']}", 'status': 'detected'}, {'time': (now - timedelta(seconds=s['duration']-30)).isoformat(), 'event': '🔍 Root cause analysis started', 'status': 'investigating'}, {'time': (now - timedelta(seconds=s['duration']-60)).isoformat(), 'event': f"⚡ {s['action']}", 'status': 'mitigating'}, {'time': (now - timedelta(seconds=30)).isoformat(), 'event': '✅ Metrics returning to normal', 'status': 'recovering'}, {'time': now.isoformat(), 'event': '🎉 Incident resolved - system stable', 'status': 'resolved'}], 'metrics': s['metrics'], 'resolved': True, 'resolution_time': f"{s['duration']}s"}
        
        boto3.resource('dynamodb').Table('cloudops-demo-sessions').put_item(Item={'sessionId': f'incident-{inc_id}', 'type': 'incident', 'data': incident, 'ttl': int(now.timestamp()) + 3600})
        
        return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'message': f'Chaos scenario "{event.get("chaos_type", "cpu_spike")}" simulated', 'incident': incident})}
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'error': str(e)})}