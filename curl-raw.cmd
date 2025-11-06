@echo off
setlocal

REM DOWNLOAD_PATH has to be full path.
set "DOWNLOAD_PATH=%1" 
set "NEXUS_URL=%2"
set "NEXUS_USERNAME=%3"
set "NEXUS_PASSWORD=%4"

REM Upload the file using curl
curl -u "%NEXUS_USERNAME%:%NEXUS_PASSWORD%" "%NEXUS_URL%" -o "%DOWNLOAD_PATH%"

REM Check if the upload was successful
if %errorlevel% equ 0 (
    echo File download successfully.
) else (
    echo File download failed.
    exit /b 1
)

endlocal
