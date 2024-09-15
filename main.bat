@echo off
setlocal EnableDelayedExpansion

:: Read input arguments
set "PROJECT_NAME="
set "DEPLOY_DIR="

:: Parse input arguments
:parse
if "%~1"=="" goto endparse
if /I "%~1"=="-pn" (
    set "PROJECT_NAME=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-dd" (
    set "DEPLOY_DIR=%~2"
    shift
    shift
    goto parse
)
echo "Unknown argument: %~1" | call :Log
echo "Unknown argument: %~1"
exit /b 1
:endparse

:: Check if arguments are provided
if "%PROJECT_NAME%"=="" (
    echo "Error: Project name (-pn) is required." | call :Log
    echo "Error: Project name (-pn) is required."
    exit /b 1
)
if "%DEPLOY_DIR%"=="" (
    echo "Error: Deployment directory (-dd) is required." | call :Log
    echo "Error: Deployment directory (-dd) is required."
    exit /b 1
)

:: Define paths
set "CONFIG_PATH=%DEPLOY_DIR%\config.json"
set "LOG_DIR=%DEPLOY_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\deployment_%DATE:~-4,4%-%DATE:~4,2%-%DATE:~7,2%.log"

:: Create logs directory if it doesn't exist
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%"
    if errorlevel 1 (
        echo "Error: Failed to create logs directory at '%LOG_DIR%'." | call :Log
        echo "Error: Failed to create logs directory at '%LOG_DIR%'."
        exit /b 1
    )
)

:: Define log function with timestamp
:Log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Log start of deployment
echo "Starting deployment for project '%PROJECT_NAME%' using config '%CONFIG_PATH%'." | call :Log

:: Check if config.json exists
if not exist "%CONFIG_PATH%" (
    echo "Error: Configuration file '%CONFIG_PATH%' not found." | call :Log
    echo "Error: Configuration file '%CONFIG_PATH%' not found."
    exit /b 1
)

:: Read JSON config file using PowerShell and extract properties
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command ^
    "(Get-Content -Path '%CONFIG_PATH%' | ConvertFrom-Json).%PROJECT_NAME%"`) do set "config=%%i"

:: Check if config was retrieved
if "%config%"=="" (
    echo "Error: No configuration found for project '%PROJECT_NAME%' in '%CONFIG_PATH%'." | call :Log
    echo "Error: No configuration found for project '%PROJECT_NAME%' in '%CONFIG_PATH%'."
    exit /b 1
)

:: Extract variables from the JSON config using PowerShell
for /f "usebackq tokens=1,2 delims=:" %%A in (`powershell -NoProfile -Command ^
    "$config = Get-Content -Path '%CONFIG_PATH%' | ConvertFrom-Json; ^
    $props = $config.%PROJECT_NAME% | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name; ^
    foreach ($prop in $props) { Write-Output \"$prop:$(($config.%PROJECT_NAME%.$prop) -replace '\"','')\" }"`) do (
    set "key=%%A"
    set "value=%%B"
    :: Remove any leading/trailing spaces
    set "key=!key: =!"
    set "value=!value: =!"
    :: Assign variables based on keys
    if /I "!key!"=="type" set "PROJECT_TYPE=!value!"
    if /I "!key!"=="ssh_key" set "SSH_KEY=!value!"
    if /I "!key!"=="server_address" set "SERVER_ADDRESS=!value!"
    if /I "!key!"=="code_dir" set "CODE_DIR=!value!"
    if /I "!key!"=="ssh_username" set "SSH_USERNAME=!value!"
    if /I "!key!"=="command" set "COMMAND=!value!"
    if /I "!key!"=="db" set "DB=!value!"
)

:: Check if required variables are set
if "!PROJECT_TYPE!"=="" (
    echo "Error: Project type not specified in the configuration for '%PROJECT_NAME%'." | call :Log
    echo "Error: Project type not specified in the configuration for '%PROJECT_NAME%'."
    exit /b 1
)
if "!CODE_DIR!"=="" (
    echo "Error: Code directory not specified in the configuration for '%PROJECT_NAME%'." | call :Log
    echo "Error: Code directory not specified in the configuration for '%PROJECT_NAME%'."
    exit /b 1
)
if "!SSH_KEY!"=="" (
    echo "Error: SSH key not specified in the configuration for '%PROJECT_NAME%'." | call :Log
    echo "Error: SSH key not specified in the configuration for '%PROJECT_NAME%'."
    exit /b 1
)
if "!SERVER_ADDRESS!"=="" (
    echo "Error: Server address not specified in the configuration for '%PROJECT_NAME%'." | call :Log
    echo "Error: Server address not specified in the configuration for '%PROJECT_NAME%'."
    exit /b 1
)
if "!SSH_USERNAME!"=="" (
    echo "Error: SSH username not specified in the configuration for '%PROJECT_NAME%'." | call :Log
    echo "Error: SSH username not specified in the configuration for '%PROJECT_NAME%'."
    exit /b 1
)
if "!COMMAND!"=="" (
    echo "Error: Command not specified in the configuration for '%PROJECT_NAME%'." | call :Log
    echo "Error: Command not specified in the configuration for '%PROJECT_NAME%'."
    exit /b 1
)

:: Validate 'db' parameter if it's defined
if defined DB (
    :: Ensure 'DB' is either 'true' or 'false' (case-insensitive)
    if /I "!DB!" NEQ "true" if /I "!DB!" NEQ "false" (
        echo "Error: 'db' parameter must be a boolean (true or false) in the configuration for '%PROJECT_NAME%'." | call :Log
        echo "Error: 'db' parameter must be a boolean (true or false) in the configuration for '%PROJECT_NAME%'."
        exit /b 1
    )
) else (
    :: Default to false if 'db' is not defined
    set "DB=false"
)

:: Log extracted variables
echo "Extracted variables:" | call :Log
echo "PROJECT_TYPE=!PROJECT_TYPE!" | call :Log
echo "SSH_KEY=!SSH_KEY!" | call :Log
echo "SERVER_ADDRESS=!SERVER_ADDRESS!" | call :Log
echo "CODE_DIR=!CODE_DIR!" | call :Log
echo "SSH_USERNAME=!SSH_USERNAME!" | call :Log
echo "COMMAND=!COMMAND!" | call :Log
echo "DB=!DB!" | call :Log

:: Define Deployer Script URLs (Hosted on GitHub)
if /I "!PROJECT_TYPE!"=="phoenix" (
    set "DEPLOYER_SCRIPT_URL=https://raw.githubusercontent.com/royokello/phoenix-server-deploy/main/phoenix_server_deploy.bat"
    set "DEPLOYER_SCRIPT=phoenix_server_deploy.bat"
) else if /I "!PROJECT_TYPE!"=="rust" (
    set "DEPLOYER_SCRIPT_URL=https://raw.githubusercontent.com/royokello/rust-deployer/main/rust_deployer.bat"
    set "DEPLOYER_SCRIPT=rust_deployer.bat"
) else (
    echo "Error: Unsupported project type '!PROJECT_TYPE!'." | call :Log
    echo "Error: Unsupported project type '!PROJECT_TYPE!'."
    exit /b 1
)

:: Define the path to save the deployer script in the code directory
set "DEPLOYER_SCRIPT_PATH=%CODE_DIR%\%DEPLOYER_SCRIPT%"

:: Function to download deployer script from GitHub
:DownloadDeployer
echo "Downloading %DEPLOYER_SCRIPT% from %DEPLOYER_SCRIPT_URL%..." | call :Log
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%DEPLOYER_SCRIPT_URL%' -OutFile '%DEPLOYER_SCRIPT_PATH%'" >> "%LOG_FILE%" 2>&1
if not exist "%DEPLOYER_SCRIPT_PATH%" (
    echo "Error: Failed to download the deployer script to '%DEPLOYER_SCRIPT_PATH%'." | call :Log
    echo "Error: Failed to download the deployer script to '%DEPLOYER_SCRIPT_PATH%'."
    exit /b 1
)
echo "Deployer script downloaded successfully." | call :Log
goto :eof

:: Check if the deployer script exists in the code directory
if exist "%DEPLOYER_SCRIPT_PATH%" (
    echo "Checking for updates to %DEPLOYER_SCRIPT%..." | call :Log

    :: Get last modified date from GitHub using HEAD request
    for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command ^
        "$response = Invoke-WebRequest -Uri '%DEPLOYER_SCRIPT_URL%' -Method Head; ^
        $response.Headers.'Last-Modified'"`) do set "REMOTE_LAST_MODIFIED=%%i"

    :: Get last modified date of the local file in RFC1123 format
    for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command ^
        "(Get-Item '%DEPLOYER_SCRIPT_PATH%').LastWriteTime.ToUniversalTime().ToString('R')"`) do set "LOCAL_LAST_MODIFIED=%%i"

    :: Compare dates using PowerShell
    powershell -NoProfile -Command ^
        "$remote = Get-Date '%REMOTE_LAST_MODIFIED%' -Format 'R'; ^
        $local = Get-Date '%LOCAL_LAST_MODIFIED%' -Format 'R'; ^
        if ($remote -gt $local) { exit 1 } else { exit 0 }"
    if errorlevel 1 (
        echo "Updating %DEPLOYER_SCRIPT% from %DEPLOYER_SCRIPT_URL%..." | call :Log
        call :DownloadDeployer
    ) else (
        echo "No updates needed for %DEPLOYER_SCRIPT%." | call :Log
    )
) else (
    echo "Deployer script for '!PROJECT_TYPE!' not found in code directory. Downloading from %DEPLOYER_SCRIPT_URL%..." | call :Log
    call :DownloadDeployer
)

:: Ensure the deployer script was downloaded successfully
if not exist "%DEPLOYER_SCRIPT_PATH%" (
    echo "Error: Failed to download the deployer script to the code directory." | call :Log
    echo "Error: Failed to download the deployer script to the code directory."
    exit /b 1
)

:: Log deployer script path
echo "Using deployer script at '%DEPLOYER_SCRIPT_PATH%'." | call :Log

:: Call the specific deployment script from the code directory, passing necessary arguments
if /I "!PROJECT_TYPE!"=="phoenix" (
    if "!COMMAND!"=="" (
        echo "Error: Command required for phoenix projects." | call :Log
        echo "Error: Command required for phoenix projects."
        exit /b 1
    )
    echo "Executing Phoenix deployer script..." | call :Log
    call "%DEPLOYER_SCRIPT_PATH%" -pn "!PROJECT_NAME!" -sa "!SERVER_ADDRESS!" -sk "!SSH_KEY!" -su "!SSH_USERNAME!" -cmd "!COMMAND!" -db "!DB!" -log "!LOG_FILE!" >> "%LOG_FILE%" 2>&1
) else if /I "!PROJECT_TYPE!"=="rust" (
    echo "Executing Rust deployer script..." | call :Log
    call "%DEPLOYER_SCRIPT_PATH%" -pn "!PROJECT_NAME!" -sa "!SERVER_ADDRESS!" -sk "!SSH_KEY!" -su "!SSH_USERNAME!" -cmd "!COMMAND!" -log "!LOG_FILE!" >> "%LOG_FILE%" 2>&1
) else (
    echo "Error: Unsupported project type '!PROJECT_TYPE!'." | call :Log
    echo "Error: Unsupported project type '!PROJECT_TYPE!'."
    exit /b 1
)

:: Check if deployer script executed successfully
if errorlevel 1 (
    echo "Error: Deployer script encountered an issue. Check '%LOG_FILE%' for details." | call :Log
    echo "Error: Deployer script encountered an issue. Check '%LOG_FILE%' for details."
    exit /b 1
) else (
    echo "Deployer script executed successfully." | call :Log
)

:: Log completion
echo "Deployment completed successfully for project '%PROJECT_NAME%'." | call :Log
echo "Deployment completed successfully for project '%PROJECT_NAME%'."
endlocal
pause
