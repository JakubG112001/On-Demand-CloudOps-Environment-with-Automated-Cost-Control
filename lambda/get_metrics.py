import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    cloudwatch = boto3.client('cloudwatch')
    
    # Configuration
    TABLE_NAME = 'cloudops-demo-sessions'
    ASG_NAME = 'cloudops-platform-asg'
    
    try:
        # Get live CloudWatch metrics
        end_time = datetime.utcnow()
        start_time = datetime.utcnow().replace(minute=end_time.minute-5)
        
        # CPU Utilization
        cpu_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/EC2',
            MetricName='CPUUtilization',
            Dimensions=[{'Name': 'AutoScalingGroupName', 'Value': ASG_NAME}],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average']
        )
        
        cpu_value = cpu_response['Datapoints'][-1]['Average'] if cpu_response['Datapoints'] else 0
        
        # Generate fake but realistic operational data
        import random
        
        metrics = {
            'timestamp': datetime.utcnow().isoformat(),
            'cpu_usage': round(cpu_value + random.uniform(-5, 15), 1),
            'memory_usage': round(random.uniform(45, 85), 1),
            'disk_usage': round(random.uniform(25, 45), 1),
            'network_in': round(random.uniform(100, 500), 0),
            'network_out': round(random.uniform(50, 200), 0),
            'active_connections': random.randint(8, 25),
            'requests_per_minute': random.randint(50, 200),
            'response_time_ms': round(random.uniform(80, 250), 0),
            'error_rate': round(random.uniform(0, 2.5), 2)
        }
        
        # Store in DynamoDB for historical data
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(Item={
            'sessionId': f'metrics-{int(datetime.utcnow().timestamp())}',
            'type': 'metrics',
            'data': metrics,
            'ttl': int(datetime.utcnow().timestamp()) + 3600  # 1 hour TTL
        })
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps(metrics)
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }