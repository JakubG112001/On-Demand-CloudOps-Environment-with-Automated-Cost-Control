#!/bin/bash

# CloudOps Chaos Engineering Script
# This script intentionally breaks the system to test operational procedures

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="cloudops-platform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to get ASG name
get_asg_name() {
    aws autoscaling describe-auto-scaling-groups \
        --query "AutoScalingGroups[?contains(AutoScalingGroupName, '$PROJECT_NAME')].AutoScalingGroupName" \
        --output text
}

# Function to get instance IDs
get_instance_ids() {
    local asg_name=$(get_asg_name)
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$asg_name" \
        --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
        --output text
}

# Chaos Test 1: Kill random EC2 instance
chaos_kill_instance() {
    log "🔥 CHAOS TEST: Killing random EC2 instance"
    
    local instances=($(get_instance_ids))
    if [ ${#instances[@]} -eq 0 ]; then
        error "No running instances found"
        return 1
    fi
    
    local random_instance=${instances[$RANDOM % ${#instances[@]}]}
    
    warn "Terminating instance: $random_instance"
    aws ec2 terminate-instances --instance-ids "$random_instance"
    
    log "Instance $random_instance terminated. Auto Scaling should replace it."
    log "Monitor: aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $(get_asg_name)"
}

# Chaos Test 2: Overload CPU
chaos_cpu_overload() {
    log "🔥 CHAOS TEST: CPU Overload Simulation"
    
    local instances=($(get_instance_ids))
    if [ ${#instances[@]} -eq 0 ]; then
        error "No running instances found"
        return 1
    fi
    
    local target_instance=${instances[0]}
    
    warn "Starting CPU stress test on instance: $target_instance"
    
    # Create stress test script
    cat > /tmp/cpu_stress.sh << 'EOF'
#!/bin/bash
# CPU stress test - runs for 10 minutes
echo "Starting CPU stress test..."
for i in {1..$(nproc)}; do
    yes > /dev/null &
done
sleep 600
killall yes
echo "CPU stress test completed"
EOF
    
    # Note: In real scenario, you'd use Systems Manager or SSH to run this
    log "CPU stress script created. In production, use AWS Systems Manager to execute:"
    log "aws ssm send-command --instance-ids $target_instance --document-name 'AWS-RunShellScript' --parameters 'commands=[\"bash /tmp/cpu_stress.sh\"]'"
    
    warn "This should trigger CPU alarms and auto-scaling within 10 minutes"
}

# Chaos Test 3: Database connection exhaustion simulation
chaos_db_connections() {
    log "🔥 CHAOS TEST: Database Connection Exhaustion"
    
    # Get ALB DNS name
    local alb_dns=$(aws elbv2 describe-load-balancers \
        --names "$PROJECT_NAME-alb" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    if [ "$alb_dns" = "None" ]; then
        error "Load balancer not found"
        return 1
    fi
    
    warn "Simulating connection exhaustion by rapid API calls"
    log "Target: http://$alb_dns/api/users"
    
    # Simulate rapid concurrent requests
    for i in {1..50}; do
        curl -X POST "http://$alb_dns/api/users" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"Chaos User $i\",\"email\":\"chaos$i@test.com\"}" \
            --max-time 1 --silent &
    done
    
    log "50 concurrent requests sent. Monitor database connections:"
    log "aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name DatabaseConnections --dimensions Name=DBInstanceIdentifier,Value=$PROJECT_NAME-db --start-time \$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Maximum"
}

# Chaos Test 4: Network latency injection
chaos_network_latency() {
    log "🔥 CHAOS TEST: Network Latency Injection"
    
    local instances=($(get_instance_ids))
    if [ ${#instances[@]} -eq 0 ]; then
        error "No running instances found"
        return 1
    fi
    
    local target_instance=${instances[0]}
    
    warn "Injecting network latency on instance: $target_instance"
    
    # Create latency injection script
    cat > /tmp/network_chaos.sh << 'EOF'
#!/bin/bash
# Add 500ms latency to all network traffic
sudo tc qdisc add dev eth0 root netem delay 500ms
echo "Network latency added (500ms)"
sleep 300  # 5 minutes
sudo tc qdisc del dev eth0 root
echo "Network latency removed"
EOF
    
    log "Network latency script created. Use Systems Manager to execute:"
    log "aws ssm send-command --instance-ids $target_instance --document-name 'AWS-RunShellScript' --parameters 'commands=[\"bash /tmp/network_chaos.sh\"]'"
    
    warn "This should increase response times and potentially trigger alerts"
}

# Chaos Test 5: Disk space exhaustion
chaos_disk_space() {
    log "🔥 CHAOS TEST: Disk Space Exhaustion"
    
    local instances=($(get_instance_ids))
    if [ ${#instances[@]} -eq 0 ]; then
        error "No running instances found"
        return 1
    fi
    
    local target_instance=${instances[0]}
    
    warn "Filling disk space on instance: $target_instance"
    
    # Create disk fill script
    cat > /tmp/disk_chaos.sh << 'EOF'
#!/bin/bash
# Fill disk to 90% capacity
echo "Starting disk fill..."
dd if=/dev/zero of=/tmp/bigfile bs=1M count=1000
df -h
sleep 300  # Keep for 5 minutes
rm -f /tmp/bigfile
echo "Disk space restored"
EOF
    
    log "Disk fill script created. Use Systems Manager to execute:"
    log "aws ssm send-command --instance-ids $target_instance --document-name 'AWS-RunShellScript' --parameters 'commands=[\"bash /tmp/disk_chaos.sh\"]'"
}

# Recovery verification
verify_recovery() {
    log "🔍 RECOVERY VERIFICATION"
    
    # Get ALB DNS name
    local alb_dns=$(aws elbv2 describe-load-balancers \
        --names "$PROJECT_NAME-alb" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    log "Testing health endpoint..."
    for i in {1..5}; do
        local status=$(curl -s -o /dev/null -w "%{http_code}" "http://$alb_dns/health" || echo "000")
        if [ "$status" = "200" ]; then
            log "✅ Health check $i: PASS ($status)"
        else
            error "❌ Health check $i: FAIL ($status)"
        fi
        sleep 2
    done
    
    log "Testing API functionality..."
    local test_response=$(curl -s -X POST "http://$alb_dns/api/users" \
        -H "Content-Type: application/json" \
        -d '{"name":"Recovery Test","email":"recovery@test.com"}' || echo "FAILED")
    
    if [[ "$test_response" == *"Recovery Test"* ]]; then
        log "✅ API test: PASS"
    else
        error "❌ API test: FAIL"
    fi
    
    # Check current metrics
    log "Current system status:"
    local asg_name=$(get_asg_name)
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$asg_name" \
        --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Running:Instances[?LifecycleState==`InService`] | length(@)}'
}

# Main menu
show_menu() {
    echo
    log "CloudOps Chaos Engineering Menu"
    echo "================================"
    echo "1. Kill Random EC2 Instance"
    echo "2. CPU Overload Simulation"
    echo "3. Database Connection Exhaustion"
    echo "4. Network Latency Injection"
    echo "5. Disk Space Exhaustion"
    echo "6. Verify System Recovery"
    echo "7. Exit"
    echo
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "Select chaos test (1-7): " choice
            case $choice in
                1) chaos_kill_instance ;;
                2) chaos_cpu_overload ;;
                3) chaos_db_connections ;;
                4) chaos_network_latency ;;
                5) chaos_disk_space ;;
                6) verify_recovery ;;
                7) log "Exiting chaos engineering session"; exit 0 ;;
                *) error "Invalid option. Please select 1-7." ;;
            esac
            echo
            read -p "Press Enter to continue..."
        done
    else
        case $1 in
            kill-instance) chaos_kill_instance ;;
            cpu-overload) chaos_cpu_overload ;;
            db-connections) chaos_db_connections ;;
            network-latency) chaos_network_latency ;;
            disk-space) chaos_disk_space ;;
            verify) verify_recovery ;;
            *) 
                echo "Usage: $0 [kill-instance|cpu-overload|db-connections|network-latency|disk-space|verify]"
                exit 1
                ;;
        esac
    fi
}

# Safety check
warn "⚠️  CHAOS ENGINEERING SCRIPT ⚠️"
warn "This script will intentionally break your system for testing purposes."
warn "Only run this in a test environment or during planned chaos exercises."
echo
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log "Chaos engineering session cancelled."
    exit 0
fi

main "$@"