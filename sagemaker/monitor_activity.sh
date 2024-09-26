#!/bin/bash

# Do not run this script as a standalone script. If you do just make sure to add these variables:
# AWS_ACCESS_KEY_ID
# AWS_SESSION_TOKEN
# AWS_SECRET_ACCESS_KEY
# This script is meant to run somewhere where these variables are injected into the environment.

# Configuration
IDLE_COUNTER=0             # Idle counter
CHECK_INTERVAL=10          # Check interval in seconds
IDLE_CPU_THRESHOLD=15      # CPU percentage threshold
IDLE_TIME_THRESHOLD=120    # Idle time in seconds

# AWS Options
REGION="us-east-2"
APP_NAME="default"
APP_TYPE="JupyterLab"
DOMAIN_ID="d-cofiway7apio"
PROFILE="lifecycle-config-script"
SPACE_NAME="private-automation-test"

AWS_ACCESS_KEY_ID=$1
AWS_SECRET_ACCESS_KEY=$2
AWS_SESSION_TOKEN=$3

echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
echo $AWS_SESSION_TOKEN

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

    # If idle time threshold is reached, create the flag file
    if [ $IDLE_COUNTER -ge $IDLE_TIME_THRESHOLD ]; then
        echo "JupyterLab has been idle for $IDLE_TIME_THRESHOLD seconds."
        aws sagemaker delete-app --domain-id $DOMAIN_ID --app-type $APP_TYPE --app-name $APP_NAME --space-name $SPACE_NAME --region $REGION --profile $PROFILE
        break
    fi

    sleep $CHECK_INTERVAL
done