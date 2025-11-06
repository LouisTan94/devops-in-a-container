#!/bin/bash

set -e

sourceDir="/usr/bin/devops-in-a-container/gitlab/data/backups"
destinationDir="/mnt/d/backup"
bucketName="s3://cag-s3-aocs-uat-gitlab-463470941600"
containerName="cpos-gitlab"  # change if your container name differs

# Trigger GitLab backup inside the container
docker exec -t "$containerName" gitlab-rake gitlab:backup:create DIRECTORY=gitlab

# Get current timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")

# Get the latest file in source directory
latestFile=$(ls -t "$sourceDir" | head -n 1)

# Copy latest backup and config files
cp "$sourceDir/$latestFile" "$destinationDir/"
cp "/usr/bin/devops-in-a-container/gitlab/config/gitlab.rb" "$destinationDir/${timestamp}_gitlab.rb"
cp "/usr/bin/devops-in-a-container/gitlab/config/gitlab-secrets.json" "$destinationDir/${timestamp}_gitlab-secrets.json"

# Upload all new backup files to S3
aws s3 cp "$destinationDir/$latestFile" "$bucketName/"
aws s3 cp "$destinationDir/${timestamp}_gitlab.rb" "$bucketName/"
aws s3 cp "$destinationDir/${timestamp}_gitlab-secrets.json" "$bucketName/"

# Optional: clean up local backups older than 7 days
find "$destinationDir" -type f -mtime +7 -delete
