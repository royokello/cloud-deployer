@echo off
setlocal EnableDelayedExpansion

echo Cloud Deployer v0.1.0
echo Author: Roy Okello, roy@stelar.xyz

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

echo Arguments parsed: project name: %PROJECT_NAME%, deployment directory: %DEPLOY_DIR%

:: Define paths
set "DATE=%date%"
set "TIME=%time%"

set "LOG_DIR=%DEPLOY_DIR%\logs"
:: Create logs directory if it doesn't exist
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%"
    if errorlevel 1 (
        echo Error: Failed to create logs directory at '%LOG_DIR%'.
        exit /b 1
    ) else (
        echo Logs directory created at '%LOG_DIR%'.
    )
) else (
    echo Logs directory exists at '%LOG_DIR%'.
)

set "LOG_FILE=%LOG_DIR%\%DATE:~-4,4%-%DATE:~4,2%-%DATE:~7,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%.log"
echo Log file: %LOG_FILE%

set "CONFIG_PATH=%DEPLOY_DIR%\config.json"

:: Check if config.json exists
if not exist "%CONFIG_PATH%" (
    call :Log "Configuration file not found in %DEPLOY_DIR%."
    exit /b 1
) else (
    call :Log "Configuration file found in %DEPLOY_DIR%."
)

:: Log start of deployment
call :Log "Starting deployment for project %PROJECT_NAME%"

:: ---------------------------
:: Read and Parse JSON Configuration
:: ---------------------------
:: This section uses PowerShell to parse the JSON file and set environment variables
:: based on the project-specific configuration.

set TEMP_DIR=%DEPLOY_DIR%\temp

:: Create temp directory if it doesn't exist
if not exist "%TEMP_DIR%" (
    mkdir "%TEMP_DIR%"
    if errorlevel 1 (
        echo Error: Failed to create temp directory at '%TEMP_DIR%'.
        exit /b 1
    ) else (
        echo Temp directory created at '%TEMP_DIR%'.
    )
) else (
    echo Temp directory exists at '%TEMP_DIR%'.
)


set "OUTPUT_PATH=%TEMP_DIR%\config_vars.txt"

:: Get config loader from GitHub
set "CONFIG_LOADER_URL=https://raw.githubusercontent.com/royokello/cloud-deployer/main/config_reader.ps1"
echo "Downloading config loader from %CONFIG_LOADER_URL%..."

set "CONFIG_LOADER_PATH=%TEMP_DIR%\config_reader.ps1"

:: Download the config loader script
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%CONFIG_LOADER_URL%' -OutFile '%CONFIG_LOADER_PATH%'"

:: Call the PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "%CONFIG_LOADER_PATH%" -ConfigPath "%CONFIG_PATH%" -ProjectName "%PROJECT_NAME%" -OutputPath "%OUTPUT_PATH%"

rem Check if the PowerShell script executed successfully
if errorlevel 1 (
    echo Error occurred while reading configuration.
    exit /b 1
)

rem Read the variables from the output file
for /f "usebackq tokens=1* delims==" %%A in ("%OUTPUT_PATH%") do (
    set "%%A=%%B"
)

rem Delete the output file
del "%OUTPUT_PATH%"

rem Output the variables to verify
echo project_type=%project_type%
echo ssh_key=%ssh_key%
echo ssh_username=%ssh_username%
echo server_address=%server_address%
echo code_dir=%code_dir%
echo command=%command%
echo db=%db%

if errorlevel 1 (
    call :Log "Error parsing configuration file."
    exit /b 1
)

call :Log "Configuration variables set."

:: ---------------------------
:: Validate Configuration Variables
:: ---------------------------
:: This section checks that all required variables are set and valid.
call :Log "Validating configuration variables..."

:: Define required variables (in lowercase)
set "REQUIRED_VARS=project_type code_dir ssh_key server_address ssh_username command"

:: Iterate over each required variable and check if it's set
for %%V in (%REQUIRED_VARS%) do (
    if "!%%V!"=="" (
        call :Log "ERROR: %%V is not specified in the configuration for project '%PROJECT_NAME%'."
        exit /b 1
    )
)

:: Validate 'DB' parameter if it's defined
if defined DB (
    :: Ensure 'DB' is either 'true' or 'false' (case-insensitive)
    if /I "!DB!" NEQ "true" if /I "!DB!" NEQ "false" (
        call :Log "ERROR: 'DB' parameter must be a boolean ('true' or 'false') in the configuration for project '%PROJECT_NAME%'."
        exit /b 1
    )
) else (
    :: Default to false if 'DB' is not defined
    set "DB=false"
    call :Log "'DB' parameter not defined. Defaulting to 'false'."
)

:: ---------------------------
:: Confirmation of Loaded Configurations
:: ---------------------------
call :Log "Configuration loaded successfully for project '%PROJECT_NAME%'."
call :Log "Configuration Details:"
call :Log "  project_type    = !project_type!"
call :Log "  code_dir        = !code_dir!"
call :Log "  ssh_key         = !ssh_key!"
call :Log "  server_address  = !server_address!"
call :Log "  ssh_username    = !ssh_username!"
call :Log "  command         = !command!"
call :Log "  DB              = !DB!"

:: Define Deployer Script URLs (Hosted on GitHub)
if /I "!PROJECT_TYPE!"=="phoenix" (
    set "DEPLOYER_SCRIPT_URL=https://raw.githubusercontent.com/royokello/phoenix-deployer/main/phoenix_deployer.bat"
    set "DEPLOYER_SCRIPT=phoenix_deployer.bat"
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

:: Define the log function at the end
goto :eof

:Log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
echo [%date% %time%] %~1
goto :eof
