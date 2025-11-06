# PowerShell script for restoring GitLab backup

# Configuration
$gitlabContainerName = "gitlab"
$backupPath = "C:\path\to\your\backup\location"
$backupFileName = "1234567890_2023_07_18_16.0.0_gitlab_backup.tar" # Replace with your actual backup file name

# Function to log messages
function Log-Message {
    param([string]$message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $message"
}

# Function to execute Docker commands
function Invoke-DockerCommand {
    param([string]$command)
    $fullCommand = "docker $command"
    Log-Message "Executing: $fullCommand"
    Invoke-Expression $fullCommand
}

try {
    # 1. Copy the backup file to the GitLab container
    Log-Message "Copying backup file to GitLab container"
    Invoke-DockerCommand "cp $backupPath\$backupFileName ${gitlabContainerName}:/var/opt/gitlab/backups/"

    # 2. Stop the processes that are connected to the database
    Log-Message "Stopping GitLab"
    Invoke-DockerCommand "exec $gitlabContainerName gitlab-ctl stop puma"
    Invoke-DockerCommand "exec $gitlabContainerName gitlab-ctl stop sidekiq"

    # 3. Verify that the processes are all down
    Log-Message "Verifying GitLab processes are stopped"
    Invoke-DockerCommand "exec $gitlabContainerName gitlab-ctl status"

    # 4. Restore the backup
    $backupTimeStamp = $backupFileName -replace '_gitlab_backup.tar', ''
    Log-Message "Restoring GitLab from backup"
    Invoke-DockerCommand "exec $gitlabContainerName gitlab-rake gitlab:backup:restore BACKUP=$backupTimeStamp"

    # 5. Restart GitLab
    Log-Message "Restarting GitLab"
    Invoke-DockerCommand "exec $gitlabContainerName gitlab-ctl restart"

    # 6. Check GitLab status
    Log-Message "Checking GitLab status"
    Invoke-DockerCommand "exec $gitlabContainerName gitlab-rake gitlab:check SANITIZE=true"

    Log-Message "Restore process completed. Please verify that GitLab is functioning correctly."
}
catch {
    Log-Message "Error occurred: $_"
}