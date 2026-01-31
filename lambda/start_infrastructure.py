import json
import boto3
import uuid
from datetime import datetime, timedelta

def lambda_handler(event, context):
    asg_client = boto3.client('autoscaling')
    rds_client = boto3.client('rds')
    events_client = boto3.client('events')
    dynamodb = boto3.resource('dynamodb')
    
    # Configuration
    ASG_NAME = 'cloudops-platform-asg'
    DB_IDENTIFIER = 'cloudops-platform-db'
    TABLE_NAME = 'cloudops-demo-sessions'
    DEMO_DURATION = 30  # minutes
    
    try:
        # Generate session ID
        session_id = str(uuid.uuid4())[:8]
        
        # Start RDS instance
        rds_client.start_db_instance(DBInstanceIdentifier=DB_IDENTIFIER)
        
        # Scale up ASG
        asg_client.update_auto_scaling_group(
            AutoScalingGroupName=ASG_NAME,
            DesiredCapacity=2,
            MinSize=1,
            MaxSize=4
        )
        
        # Schedule auto-shutdown
        shutdown_time = datetime.utcnow() + timedelta(minutes=DEMO_DURATION)
        
        events_client.put_rule(
            Name=f'cloudops-shutdown-{session_id}',
            ScheduleExpression=f'at({shutdown_time.strftime("%Y-%m-%dT%H:%M:%S")})',
            State='ENABLED'
        )
        
        events_client.put_targets(
            Rule=f'cloudops-shutdown-{session_id}',
            Targets=[{
                'Id': '1',
                'Arn': context.invoked_function_arn.replace(':start-', ':stop-'),
                'Input': json.dumps({'sessionId': session_id, 'autoShutdown': True})
            }]
        )
        
        # Store session info
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(Item={
            'sessionId': session_id,
            'startTime': datetime.utcnow().isoformat(),
            'endTime': shutdown_time.isoformat(),
            'state': 'starting'
        })
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'sessionId': session_id,
                'message': 'Infrastructure starting',
                'shutdownTime': shutdown_time.isoformat()
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }