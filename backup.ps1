# PowerShell script for backing up Docker bind volumes using Docker Compose

# Configuration
$sourcePath = "C:\Users\kaisian\Documents\devops-in-a-container"
$backupPath = "C:\Users\kaisian\Documents\docker-backup"
$composeProjectPath = "C:\Users\kaisian\Documents\devops-in-a-container\"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFileName = "docker-volume-backup-${timestamp}.zip"

# Function to log messages
function Log-Message {
    param([string]$message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $message"
}

# Function to execute Docker Compose commands
function Invoke-DockerComposeCommand {
    param([string]$command)
    $currentLocation = Get-Location
    Set-Location $composeProjectPath
    try {
        $fullCommand = "docker compose $command"
        Log-Message ("Executing in {0}: {1}" -f $composeProjectPath, $fullCommand)
        Invoke-Expression $fullCommand
    }
    finally {
        Set-Location $currentLocation
    }
}

# Stop the Docker Compose project
Log-Message "Stopping Docker Compose project in $composeProjectPath"
Invoke-DockerComposeCommand "down"

try {
    # Create backup directory if it doesn't exist
    if (-not (Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath | Out-Null
    }

    # Create the backup
    Log-Message "Creating backup of $sourcePath"
    Compress-Archive -Path $sourcePath -DestinationPath "$backupPath\$backupFileName" -Force

    # Verify the backup
    if (Test-Path "$backupPath\$backupFileName") {
        Log-Message "Backup created successfully: $backupPath\$backupFileName"
    } else {
        throw "Backup file not found. Backup may have failed."
    }
}
catch {
    Log-Message "Error occurred: $_"
}
finally {
    # Restart the Docker Compose project
    Log-Message "Restarting Docker Compose project in $composeProjectPath"
    Invoke-DockerComposeCommand "up -d"
}

Log-Message "Backup process completed"