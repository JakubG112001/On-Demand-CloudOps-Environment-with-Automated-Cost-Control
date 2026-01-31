#!/bin/bash

# CloudOps Platform Deployment Script
# Automates the deployment of the entire infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="cloudops-platform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install it first."
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Run 'aws configure' first."
    fi
    
    # Check required environment variables
    if [ -z "$DB_PASSWORD" ]; then
        error "DB_PASSWORD environment variable is required"
    fi
    
    if [ -z "$NOTIFICATION_EMAIL" ]; then
        error "NOTIFICATION_EMAIL environment variable is required"
    fi
    
    log "✅ All prerequisites met"
}

# Validate Terraform configuration
validate_terraform() {
    log "Validating Terraform configuration..."
    
    cd "$PROJECT_ROOT/terraform"
    
    terraform fmt -check=true -diff=true
    terraform validate
    
    log "✅ Terraform configuration is valid"
}

# Initialize Terraform
init_terraform() {
    log "Initializing Terraform..."
    
    cd "$PROJECT_ROOT/terraform"
    terraform init
    
    log "✅ Terraform initialized"
}

# Plan deployment
plan_deployment() {
    log "Planning deployment..."
    
    cd "$PROJECT_ROOT/terraform"
    
    terraform plan \
        -var="db_password=$DB_PASSWORD" \
        -var="notification_email=$NOTIFICATION_EMAIL" \
        -out=tfplan
    
    log "✅ Deployment plan created"
}

# Deploy infrastructure
deploy_infrastructure() {
    log "Deploying infrastructure..."
    
    cd "$PROJECT_ROOT/terraform"
    
    terraform apply tfplan
    
    log "✅ Infrastructure deployed successfully"
}

# Get deployment outputs
get_outputs() {
    log "Getting deployment outputs..."
    
    cd "$PROJECT_ROOT/terraform"
    
    ALB_DNS=$(terraform output -raw alb_dns_name)
    VPC_ID=$(terraform output -raw vpc_id)
    SNS_TOPIC=$(terraform output -raw sns_topic_arn)
    
    info "🌐 Application URL: http://$ALB_DNS"
    info "🏥 Health Check: http://$ALB_DNS/health"
    info "🔗 VPC ID: $VPC_ID"
    info "📧 SNS Topic: $SNS_TOPIC"
    
    # Save outputs to file
    cat > "$PROJECT_ROOT/deployment-info.txt" << EOF
CloudOps Platform Deployment Information
========================================
Deployment Date: $(date)
Application URL: http://$ALB_DNS
Health Check URL: http://$ALB_DNS/health
VPC ID: $VPC_ID
SNS Topic ARN: $SNS_TOPIC

API Endpoints:
- GET  http://$ALB_DNS/health
- GET  http://$ALB_DNS/api/users
- POST http://$ALB_DNS/api/users
- PUT  http://$ALB_DNS/api/users/{id}
- DELETE http://$ALB_DNS/api/users/{id}
EOF
    
    log "✅ Deployment information saved to deployment-info.txt"
}

# Test deployment
test_deployment() {
    log "Testing deployment..."
    
    cd "$PROJECT_ROOT/terraform"
    ALB_DNS=$(terraform output -raw alb_dns_name)
    
    info "Waiting for load balancer to be ready..."
    sleep 60
    
    # Test health endpoint
    log "Testing health endpoint..."
    for i in {1..10}; do
        if curl -f -s "http://$ALB_DNS/health" > /dev/null; then
            log "✅ Health check passed (attempt $i)"
            break
        else
            warn "Health check failed (attempt $i/10), retrying in 30s..."
            if [ $i -eq 10 ]; then
                error "Health check failed after 10 attempts"
            fi
            sleep 30
        fi
    done
    
    # Test API endpoints
    log "Testing API endpoints..."
    
    # Create a test user
    CREATE_RESPONSE=$(curl -s -X POST "http://$ALB_DNS/api/users" \
        -H "Content-Type: application/json" \
        -d '{"name":"Test User","email":"test@example.com"}')
    
    if [[ "$CREATE_RESPONSE" == *"Test User"* ]]; then
        log "✅ User creation test passed"
    else
        error "User creation test failed: $CREATE_RESPONSE"
    fi
    
    # List users
    LIST_RESPONSE=$(curl -s "http://$ALB_DNS/api/users")
    if [[ "$LIST_RESPONSE" == *"Test User"* ]]; then
        log "✅ User listing test passed"
    else
        error "User listing test failed: $LIST_RESPONSE"
    fi
    
    log "✅ All tests passed"
}

# Setup monitoring dashboard
setup_monitoring() {
    log "Setting up monitoring dashboard..."
    
    # Create CloudWatch dashboard
    aws cloudwatch put-dashboard \
        --dashboard-name "$PROJECT_NAME-dashboard" \
        --dashboard-body file://<(cat << 'EOF'
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/cloudops-platform-alb" ],
                    [ ".", "TargetResponseTime", ".", "." ],
                    [ ".", "HTTPCode_Target_5XX_Count", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Application Load Balancer Metrics"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "cloudops-platform-asg" ],
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "cloudops-platform-db" ],
                    [ ".", "DatabaseConnections", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "System Resource Utilization"
            }
        }
    ]
}
EOF
)
    
    log "✅ CloudWatch dashboard created"
    info "📊 Dashboard URL: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=$PROJECT_NAME-dashboard"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    cd "$PROJECT_ROOT/terraform"
    rm -f tfplan
}

# Main deployment function
deploy() {
    log "🚀 Starting CloudOps Platform deployment..."
    
    check_prerequisites
    validate_terraform
    init_terraform
    plan_deployment
    
    # Confirm deployment
    echo
    warn "⚠️  This will create AWS resources that may incur charges."
    read -p "Do you want to proceed with deployment? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Deployment cancelled."
        cleanup
        exit 0
    fi
    
    deploy_infrastructure
    get_outputs
    test_deployment
    setup_monitoring
    cleanup
    
    log "🎉 CloudOps Platform deployed successfully!"
    echo
    info "Next steps:"
    info "1. Check the application at the URL above"
    info "2. Confirm SNS subscription in your email"
    info "3. Review the monitoring dashboard"
    info "4. Run chaos engineering tests: ./scripts/chaos-engineering.sh"
    info "5. Review operational documentation in runbooks/ and incidents/"
}

# Destroy function
destroy() {
    log "🔥 Destroying CloudOps Platform infrastructure..."
    
    cd "$PROJECT_ROOT/terraform"
    
    warn "⚠️  This will permanently delete all AWS resources."
    read -p "Are you sure you want to destroy the infrastructure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Destruction cancelled."
        exit 0
    fi
    
    terraform destroy \
        -var="db_password=$DB_PASSWORD" \
        -var="notification_email=$NOTIFICATION_EMAIL" \
        -auto-approve
    
    # Clean up dashboard
    aws cloudwatch delete-dashboards --dashboard-names "$PROJECT_NAME-dashboard" || true
    
    log "✅ Infrastructure destroyed successfully"
}

# Status function
status() {
    log "Checking CloudOps Platform status..."
    
    cd "$PROJECT_ROOT/terraform"
    
    if [ ! -f "terraform.tfstate" ]; then
        info "No infrastructure deployed"
        exit 0
    fi
    
    # Check if resources exist
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ]; then
        warn "Infrastructure state exists but resources may not be deployed"
        exit 1
    fi
    
    info "🌐 Application URL: http://$ALB_DNS"
    
    # Quick health check
    if curl -f -s "http://$ALB_DNS/health" > /dev/null; then
        log "✅ Application is healthy"
    else
        error "❌ Application health check failed"
    fi
    
    # Show resource status
    terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_autoscaling_group") | .values.desired_capacity' | head -1 | xargs -I {} echo "Auto Scaling Group desired capacity: {}"
}

# Usage function
usage() {
    echo "CloudOps Platform Deployment Script"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  deploy    Deploy the infrastructure (default)"
    echo "  destroy   Destroy the infrastructure"
    echo "  status    Check deployment status"
    echo "  help      Show this help message"
    echo
    echo "Environment Variables Required:"
    echo "  DB_PASSWORD        Database password"
    echo "  NOTIFICATION_EMAIL Email for alerts"
    echo
    echo "Example:"
    echo "  export DB_PASSWORD='your-secure-password'"
    echo "  export NOTIFICATION_EMAIL='your-email@example.com'"
    echo "  $0 deploy"
}

# Main execution
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    destroy)
        destroy
        ;;
    status)
        status
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        error "Unknown command: $1"
        usage
        exit 1
        ;;
esac