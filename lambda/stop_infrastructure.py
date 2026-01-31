import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    asg_client = boto3.client('autoscaling')
    rds_client = boto3.client('rds')
    events_client = boto3.client('events')
    dynamodb = boto3.resource('dynamodb')
    
    # Configuration
    ASG_NAME = 'cloudops-platform-asg'
    DB_IDENTIFIER = 'cloudops-platform-db'
    TABLE_NAME = 'cloudops-demo-sessions'
    
    try:
        session_id = event.get('sessionId', 'manual')
        
        # Scale down ASG to 0
        asg_client.update_auto_scaling_group(
            AutoScalingGroupName=ASG_NAME,
            DesiredCapacity=0,
            MinSize=0
        )
        
        # Stop RDS instance
        rds_client.stop_db_instance(DBInstanceIdentifier=DB_IDENTIFIER)
        
        # Clean up scheduled shutdown rule
        if session_id != 'manual':
            try:
                events_client.remove_targets(
                    Rule=f'cloudops-shutdown-{session_id}',
                    Ids=['1']
                )
                events_client.delete_rule(Name=f'cloudops-shutdown-{session_id}')
            except:
                pass  # Rule might not exist
        
        # Update session state
        if session_id != 'manual':
            table = dynamodb.Table(TABLE_NAME)
            table.update_item(
                Key={'sessionId': session_id},
                UpdateExpression='SET #state = :state, endTime = :endTime',
                ExpressionAttributeNames={'#state': 'state'},
                ExpressionAttributeValues={
                    ':state': 'stopped',
                    ':endTime': datetime.utcnow().isoformat()
                }
            )
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'message': 'Infrastructure stopping',
                'sessionId': session_id
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }