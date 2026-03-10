import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    try:
        table = boto3.resource('dynamodb').Table('cloudops-demo-sessions')
        current_session = table.scan(FilterExpression='#state = :state', ExpressionAttributeNames={'#state': 'state'}, ExpressionAttributeValues={':state': 'starting'})['Items']
        current_session = current_session[0] if current_session else None
        
        asg = boto3.client('autoscaling').describe_auto_scaling_groups(AutoScalingGroupNames=['cloudops-platform-asg'])['AutoScalingGroups'][0]
        running_instances = len([i for i in asg['Instances'] if i['LifecycleState'] == 'InService'])
        db_status = boto3.client('rds').describe_db_instances(DBInstanceIdentifier='cloudops-platform-db')['DBInstances'][0]['DBInstanceStatus']
        
        if running_instances > 0 and db_status == 'available':
            alb_dns = boto3.client('elbv2').describe_load_balancers(Names=['cloudops-platform-alb'])['LoadBalancers'][0]['DNSName']
            if current_session:
                table.update_item(Key={'sessionId': current_session['sessionId']}, UpdateExpression='SET #state = :state', ExpressionAttributeNames={'#state': 'state'}, ExpressionAttributeValues={':state': 'running'})
                remaining_minutes = max(0, int((datetime.fromisoformat(current_session['endTime']) - datetime.utcnow()).total_seconds() / 60))
            else:
                remaining_minutes = 0
            return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'state': 'running', 'applicationUrl': f'http://{alb_dns}', 'remainingMinutes': remaining_minutes, 'runningInstances': running_instances, 'databaseStatus': db_status})}
        elif asg['DesiredCapacity'] > 0 or db_status in ['starting', 'backing-up']:
            return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'state': 'starting', 'applicationUrl': None, 'remainingMinutes': 30 if current_session else 0, 'runningInstances': running_instances, 'databaseStatus': db_status})}
        else:
            return {'statusCode': 200, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'state': 'stopped', 'applicationUrl': None, 'remainingMinutes': 0, 'runningInstances': running_instances, 'databaseStatus': db_status})}
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'}, 'body': json.dumps({'error': str(e)})}