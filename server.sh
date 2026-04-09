#!/bin/bash

source .env
echo $SG_ID
echo $AMI_ID
echo $ZONE_ID
echo $DOMAIN_NAME


for instance in $@
do
   instance_id=$(
     aws ec2 run-instances \
    --image-id $AMI_ID    \
    --instance-type "t3.micro" \
    --security-group-ids $SG_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text 
   )

    if [ "$instance" == "frontend" ]; then
        IP=$(
            aws ec2 describe-instances \
            --instance-ids $instance_id \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text

        )
        RECORD_NAME="job-internship-application-tracker"
        RECORD_NAME="$RECORD_NAME.$DOMAIN_NAME"  
    else
         IP=$(
            aws ec2 describe-instances \
            --instance-ids $instance_id \
            --query 'Reservations[].Instances[].PrivateIpAddress' \
            --output text
         )
         RECORD_NAME="$instance.$DOMAIN_NAME"  
    fi
    echo "IP Address: $IP"

    aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch '
    {
        "Comment": "Updating Record",
        "Changes": [
           {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'$RECORD_NAME'",
                "Type": "A",
                "TTL": 1,
                "ResourceRecords": [
                {
                    "Value": "'$IP'"
                }
                ]
            }
        }
    ]
}
'
echo "record updated for $instance"

done