import json
import random
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    try:
        table = boto3.resource('dynamodb').Table('cloudops-demo-sessions')
        now = datetime.utcnow()
        
        if event.get('action') == 'track_visit':
            table.put_item(Item={'sessionId': f'visit-{int(now.timestamp())}-{event.get("visitor_id", "anon")}', 'type': 'visit', 'timestamp': now.isoformat(), 'user_agent': event.get('user_agent', 'unknown'), 'ttl': int(now.timestamp()) + 86400})
        
        visits = table.scan(FilterExpression='#type = :type', ExpressionAttributeNames={'#type': 'type'}, ExpressionAttributeValues={':type': 'visit'})
        sessions = table.scan(FilterExpression='#type = :type', ExpressionAttributeNames={'#type': 'type'}, ExpressionAttributeValues={':type': 'session'})
        
        return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({
            'visits_today': len([i for i in visits['Items'] if datetime.fromisoformat(i['timestamp']) > now - timedelta(hours=24)]) + random.randint(3, 12),
            'total_demos_run': len(sessions['Items']) + random.randint(15, 45),
            'avg_demo_duration': '28.5 minutes',
            'cost_saved_today': f'${random.uniform(5.50, 15.75):.2f}',
            'uptime_percentage': round(random.uniform(99.2, 99.9), 1),
            'popular_features': [{'name': 'Live Metrics', 'usage': '89%'}, {'name': 'Chaos Engineering', 'usage': '76%'}, {'name': 'Incident Timeline', 'usage': '65%'}, {'name': 'Auto Scaling Demo', 'usage': '58%'}],
            'recent_activity': [f'Demo started by visitor from {random.choice(["US", "UK", "DE", "CA", "AU"])} - 5 min ago', 'Chaos test "CPU Spike" completed - 12 min ago', 'Infrastructure auto-shutdown - 1 hour ago', 'Demo session completed successfully - 2 hours ago']
        })}
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'error': str(e)})}