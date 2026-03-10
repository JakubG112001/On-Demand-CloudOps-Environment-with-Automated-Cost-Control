import json
import boto3
import uuid
from datetime import datetime, timedelta

def lambda_handler(event, context):
    try:
        session_id = str(uuid.uuid4())[:8]
        now = datetime.utcnow()
        shutdown_time = now + timedelta(minutes=30)
        
        boto3.client('rds').start_db_instance(DBInstanceIdentifier='cloudops-platform-db')
        boto3.client('autoscaling').update_auto_scaling_group(AutoScalingGroupName='cloudops-platform-asg', DesiredCapacity=2, MinSize=1, MaxSize=4)
        
        events = boto3.client('events')
        events.put_rule(Name=f'cloudops-shutdown-{session_id}', ScheduleExpression=f'at({shutdown_time.strftime("%Y-%m-%dT%H:%M:%S")})', State='ENABLED')
        events.put_targets(Rule=f'cloudops-shutdown-{session_id}', Targets=[{'Id': '1', 'Arn': context.invoked_function_arn.replace(':start-', ':stop-'), 'Input': json.dumps({'sessionId': session_id, 'autoShutdown': True})}])
        
        boto3.resource('dynamodb').Table('cloudops-demo-sessions').put_item(Item={'sessionId': session_id, 'startTime': now.isoformat(), 'endTime': shutdown_time.isoformat(), 'state': 'starting'})
        
        return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'sessionId': session_id, 'message': 'Infrastructure starting', 'shutdownTime': shutdown_time.isoformat()})}
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'error': str(e)})}