import json
import random
import boto3
from datetime import datetime

def lambda_handler(event, context):
    try:
        now = datetime.utcnow()
        cpu_data = boto3.client('cloudwatch').get_metric_statistics(Namespace='AWS/EC2', MetricName='CPUUtilization', Dimensions=[{'Name': 'AutoScalingGroupName', 'Value': 'cloudops-platform-asg'}], StartTime=now.replace(minute=now.minute-5), EndTime=now, Period=300, Statistics=['Average'])
        cpu = cpu_data['Datapoints'][-1]['Average'] if cpu_data['Datapoints'] else 0
        
        metrics = {'timestamp': now.isoformat(), 'cpu_usage': round(cpu + random.uniform(-5, 15), 1), 'memory_usage': round(random.uniform(45, 85), 1), 'disk_usage': round(random.uniform(25, 45), 1), 'network_in': round(random.uniform(100, 500), 0), 'network_out': round(random.uniform(50, 200), 0), 'active_connections': random.randint(8, 25), 'requests_per_minute': random.randint(50, 200), 'response_time_ms': round(random.uniform(80, 250), 0), 'error_rate': round(random.uniform(0, 2.5), 2)}
        
        boto3.resource('dynamodb').Table('cloudops-demo-sessions').put_item(Item={'sessionId': f'metrics-{int(now.timestamp())}', 'type': 'metrics', 'data': metrics, 'ttl': int(now.timestamp()) + 3600})
        
        return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps(metrics)}
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'error': str(e)})}