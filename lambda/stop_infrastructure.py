import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    try:
        session_id = event.get('sessionId', 'manual')
        
        boto3.client('autoscaling').update_auto_scaling_group(AutoScalingGroupName='cloudops-platform-asg', DesiredCapacity=0, MinSize=0)
        boto3.client('rds').stop_db_instance(DBInstanceIdentifier='cloudops-platform-db')
        
        if session_id != 'manual':
            try:
                events = boto3.client('events')
                events.remove_targets(Rule=f'cloudops-shutdown-{session_id}', Ids=['1'])
                events.delete_rule(Name=f'cloudops-shutdown-{session_id}')
                boto3.resource('dynamodb').Table('cloudops-demo-sessions').update_item(Key={'sessionId': session_id}, UpdateExpression='SET #state = :state, endTime = :endTime', ExpressionAttributeNames={'#state': 'state'}, ExpressionAttributeValues={':state': 'stopped', ':endTime': datetime.utcnow().isoformat()})
            except:
                pass
        
        return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'message': 'Infrastructure stopping', 'sessionId': session_id})}
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'error': str(e)})}