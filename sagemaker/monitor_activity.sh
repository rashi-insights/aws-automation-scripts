#!/bin/bash

# Pass the AWS's Access Key ID, Secret Access Key, Session Token and Space name as arguements to this script
# E.g this is how you should run the command in a shell:
# /path/to/monitor_activity.sh "your-access-key-id" "your-secret-access-key" "your-session-token" "your-space-name"

# Configuration
IDLE_COUNTER=0             # Idle counter
CHECK_INTERVAL=10          # Check interval in seconds
IDLE_CPU_THRESHOLD=15      # CPU percentage threshold
IDLE_TIME_THRESHOLD=120    # Idle time in seconds

# AWS Options
REGION="us-east-2"
APP_NAME="default"
APP_TYPE="JupyterLab"
DOMAIN_ID="d-cofiway7apio"          # Sagemaker's domain id
PROFILE="lifecycle-config-script"   # Temporary AWS profile
SPACE_NAME=$4                       # Name of the JupyterLab Space

AWS_ACCESS_KEY_ID=$1        # 1st Arguement
AWS_SECRET_ACCESS_KEY=$2    # 2nd Argument
AWS_SESSION_TOKEN=$3        # 3rd Argument

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID --profile $PROFILE
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY --profile $PROFILE
aws configure set aws_session_token $AWS_SESSION_TOKEN --profile $PROFILE

# Function to check CPU usage
check_cpu_usage() {
    CPU_USAGE=$(mpstat 1 1 | awk 'NR==4 {print 100 - $NF}')
    echo $CPU_USAGE
}

# Main loop
while true; do
    CPU_USAGE=$(check_cpu_usage)
    echo $CPU_USAGE

    # Check if the CPU is below the threshold using bc for floating-point comparison
    if echo "$CPU_USAGE < $IDLE_CPU_THRESHOLD" | bc -l | grep -q 1; then
        IDLE_COUNTER=$((IDLE_COUNTER + CHECK_INTERVAL))
    else
        IDLE_COUNTER=0  # Reset if there's activity
    fi

    # If idle time threshold is reached, stop the space
    if [ $IDLE_COUNTER -ge $IDLE_TIME_THRESHOLD ]; then
        echo "JupyterLab has been idle for $IDLE_TIME_THRESHOLD seconds. Stopping the space now..."
        aws sagemaker delete-app --domain-id $DOMAIN_ID --app-type $APP_TYPE --app-name $APP_NAME --space-name $SPACE_NAME --region $REGION --profile $PROFILE
        echo "Space was stopped successfully."
        break
    fi

    sleep $CHECK_INTERVAL
done