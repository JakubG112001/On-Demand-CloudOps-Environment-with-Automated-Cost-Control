import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    asg_client = boto3.client('autoscaling')
    rds_client = boto3.client('rds')
    elbv2_client = boto3.client('elbv2')
    dynamodb = boto3.resource('dynamodb')
    
    # Configuration
    ASG_NAME = 'cloudops-platform-asg'
    DB_IDENTIFIER = 'cloudops-platform-db'
    ALB_NAME = 'cloudops-platform-alb'
    TABLE_NAME = 'cloudops-demo-sessions'
    
    try:
        # Get current session
        table = dynamodb.Table(TABLE_NAME)
        response = table.scan(
            FilterExpression='#state = :state',
            ExpressionAttributeNames={'#state': 'state'},
            ExpressionAttributeValues={':state': 'starting'}
        )
        
        current_session = None
        if response['Items']:
            current_session = response['Items'][0]
        
        # Check ASG status
        asg_response = asg_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=[ASG_NAME]
        )
        asg = asg_response['AutoScalingGroups'][0]
        running_instances = len([i for i in asg['Instances'] if i['LifecycleState'] == 'InService'])
        
        # Check RDS status
        rds_response = rds_client.describe_db_instances(
            DBInstanceIdentifier=DB_IDENTIFIER
        )
        db_status = rds_response['DBInstances'][0]['DBInstanceStatus']
        
        # Determine overall state
        if running_instances > 0 and db_status == 'available':
            state = 'running'
            
            # Get ALB DNS name
            alb_response = elbv2_client.describe_load_balancers(Names=[ALB_NAME])
            alb_dns = alb_response['LoadBalancers'][0]['DNSName']
            application_url = f'http://{alb_dns}'
            
            # Update session state
            if current_session:
                table.update_item(
                    Key={'sessionId': current_session['sessionId']},
                    UpdateExpression='SET #state = :state',
                    ExpressionAttributeNames={'#state': 'state'},
                    ExpressionAttributeValues={':state': 'running'}
                )
                
                # Calculate remaining time
                end_time = datetime.fromisoformat(current_session['endTime'])
                remaining_minutes = max(0, int((end_time - datetime.utcnow()).total_seconds() / 60))
            else:
                remaining_minutes = 0
                
        elif asg['DesiredCapacity'] > 0 or db_status in ['starting', 'backing-up']:
            state = 'starting'
            application_url = None
            remaining_minutes = 30 if current_session else 0
        else:
            state = 'stopped'
            application_url = None
            remaining_minutes = 0
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'state': state,
                'applicationUrl': application_url,
                'remainingMinutes': remaining_minutes,
                'runningInstances': running_instances,
                'databaseStatus': db_status
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }