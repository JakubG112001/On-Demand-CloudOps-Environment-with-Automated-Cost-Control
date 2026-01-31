#!/bin/bash

# Cost-Optimized CloudOps Platform Deployment Script

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
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
    fi
    
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install it first."
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Run 'aws configure' first."
    fi
    
    if [ -z "$DB_PASSWORD" ]; then
        error "DB_PASSWORD environment variable is required"
    fi
    
    if [ -z "$NOTIFICATION_EMAIL" ]; then
        error "NOTIFICATION_EMAIL environment variable is required"
    fi
    
    log "✅ All prerequisites met"
}

# Deploy infrastructure
deploy() {
    log "🚀 Starting cost-optimized CloudOps Platform deployment..."
    
    check_prerequisites
    
    cd "$PROJECT_ROOT/terraform"
    
    terraform init
    terraform validate
    
    terraform plan \
        -var="db_password=$DB_PASSWORD" \
        -var="notification_email=$NOTIFICATION_EMAIL" \
        -out=tfplan
    
    echo
    warn "⚠️  This will create AWS resources. Estimated monthly cost: ~$20-25"
    warn "💡 Expensive resources (EC2, RDS) will be stopped by default"
    read -p "Do you want to proceed with deployment? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Deployment cancelled."
        rm -f tfplan
        exit 0
    fi
    
    terraform apply tfplan
    
    # Get outputs
    WEBSITE_URL=$(terraform output -raw website_url)
    API_URL=$(terraform output -raw api_gateway_url)
    ALB_DNS=$(terraform output -raw alb_dns_name)
    
    # Update website with API URL
    sed -i.bak "s|https://YOUR_API_GATEWAY_URL/prod|$API_URL|g" "$PROJECT_ROOT/website/index.html"
    
    # Upload updated website
    aws s3 cp "$PROJECT_ROOT/website/index.html" "s3://$(terraform output -raw website_url | cut -d'/' -f3)/index.html" --content-type "text/html"
    
    # Stop RDS to save costs
    log "Stopping RDS instance to minimize costs..."
    aws rds stop-db-instance --db-instance-identifier "$PROJECT_NAME-db" || true
    
    # Scale ASG to 0
    log "Scaling Auto Scaling Group to 0..."
    aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "$PROJECT_NAME-asg" \
        --desired-capacity 0 \
        --min-size 0 || true
    
    rm -f tfplan
    
    log "🎉 Cost-optimized CloudOps Platform deployed successfully!"
    echo
    info "📊 Website URL: $WEBSITE_URL"
    info "🔗 API Gateway: $API_URL"
    info "⚖️  Load Balancer: http://$ALB_DNS (will work when demo is started)"
    echo
    info "💰 Current state: All expensive resources are stopped"
    info "💡 Use the website button to start a 30-minute demo session"
    echo
    info "Monthly costs:"
    info "  - Always running: ~$20 (S3, API Gateway, Lambda, ALB)"
    info "  - Demo sessions: ~$0.50/hour when running"
    info "  - Total estimated: $20-25/month with occasional demos"
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
    
    # Start RDS if stopped (needed for destroy)
    aws rds start-db-instance --db-instance-identifier "$PROJECT_NAME-db" || true
    
    # Wait a bit for RDS to start
    log "Waiting for RDS to start before destroying..."
    sleep 60
    
    terraform destroy \
        -var="db_password=$DB_PASSWORD" \
        -var="notification_email=$NOTIFICATION_EMAIL" \
        -auto-approve
    
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
    
    WEBSITE_URL=$(terraform output -raw website_url 2>/dev/null || echo "")
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    
    if [ -z "$WEBSITE_URL" ]; then
        warn "Infrastructure state exists but resources may not be deployed"
        exit 1
    fi
    
    info "📊 Website URL: $WEBSITE_URL"
    info "🔗 API Gateway: $API_URL"
    info "⚖️  Load Balancer: http://$ALB_DNS"
    
    # Check if demo is running
    if curl -f -s "$API_URL/status" > /dev/null; then
        log "✅ Serverless components are healthy"
        
        # Check demo status
        DEMO_STATUS=$(curl -s "$API_URL/status" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        info "🎮 Demo status: $DEMO_STATUS"
    else
        error "❌ API Gateway health check failed"
    fi
}

# Usage function
usage() {
    echo "Cost-Optimized CloudOps Platform Deployment Script"
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
    echo "Cost Optimization:"
    echo "  - Always running: S3, API Gateway, Lambda, ALB (~$20/month)"
    echo "  - On-demand: EC2, RDS only during demos (~$0.50/hour)"
    echo "  - Total: ~$20-25/month with occasional demos"
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