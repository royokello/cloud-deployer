@echo off

:: Read input arguments
set PROJECT_NAME=
set CONFIG_PATH=

:: Parse input arguments
:parse
if "%1"=="" goto endparse
if "%1"=="-p" (
    set PROJECT_NAME=%2
    shift
    shift
    goto parse
)
if "%1"=="-c" (
    set CONFIG_PATH=%2
    shift
    shift
    goto parse
)
shift
goto parse
:endparse

:: Check if arguments are provided
if "%PROJECT_NAME%"=="" (
    echo "Error: Project name (-p) is required."
    exit /b 1
)
if "%CONFIG_PATH%"=="" (
    echo "Error: Configuration path (-c) is required."
    exit /b 1
)

:: Read JSON config file using PowerShell
for /f "delims=" %%i in ('powershell -Command "Get-Content %CONFIG_PATH% | ConvertFrom-Json | Select-Object -ExpandProperty %PROJECT_NAME%"') do set "config=%%i"

:: Extract variables from the JSON config
for /f "tokens=1,2 delims==" %%A in ('echo %config%') do (
    if "%%A"=="type" set "PROJECT_TYPE=%%B"
    if "%%A"=="ssh_key" set "SSH_KEY=%%B"
    if "%%A"=="server_address" set "SERVER_ADDRESS=%%B"
    if "%%A"=="code_dir" set "CODE_DIR=%%B"
    if "%%A"=="ssh_username" set "SSH_USERNAME=%%B"
)

:: Check if project type, code directory, and SSH details are set
if "%PROJECT_TYPE%"=="" (
    echo "Error: Project type not specified in the configuration for %PROJECT_NAME%"
    exit /b 1
)
if "%CODE_DIR%"=="" (
    echo "Error: Code directory not specified in the configuration for %PROJECT_NAME%"
    exit /b 1
)
if "%SSH_KEY%"=="" (
    echo "Error: SSH key not specified in the configuration for %PROJECT_NAME%"
    exit /b 1
)
if "%SERVER_ADDRESS%"=="" (
    echo "Error: Server address not specified in the configuration for %PROJECT_NAME%"
    exit /b 1
)
if "%SSH_USERNAME%"=="" (
    echo "Error: SSH username not specified in the configuration for %PROJECT_NAME%"
    exit /b 1
)

:: Hardcoded URLs for each project type
if "%PROJECT_TYPE%"=="phoenix" (
    set DEPLOYER_SCRIPT_URL=https://github.com/your-phoenix-deployer-repo/phoenix_deployer.bat
    set DEPLOYER_SCRIPT=phoenix_deployer.bat
) else if "%PROJECT_TYPE%"=="rust" (
    set DEPLOYER_SCRIPT_URL=https://github.com/your-rust-deployer-repo/rust_deployer.bat
    set DEPLOYER_SCRIPT=rust_deployer.bat
) else (
    echo "Error: Unsupported project type '%PROJECT_TYPE%'."
    exit /b 1
)

:: Define the path to save the deployer script in the code directory
set DEPLOYER_SCRIPT_PATH=%CODE_DIR%\%DEPLOYER_SCRIPT%

:: Check if the deployer script exists in the code directory
if exist "%DEPLOYER_SCRIPT_PATH%" (
    echo "Checking for updates to %DEPLOYER_SCRIPT%..."

    :: Get last modified date from GitHub
    for /f "delims=" %%i in ('powershell -Command "(Invoke-RestMethod -Uri '%DEPLOYER_SCRIPT_URL%' -Method Head).Headers.'Last-Modified'"') do set "REMOTE_LAST_MODIFIED=%%i"

    :: Get last modified date of the local file
    for /f "delims=" %%i in ('powershell -Command "(Get-Item '%DEPLOYER_SCRIPT_PATH%').LastWriteTime"') do set "LOCAL_LAST_MODIFIED=%%i"

    :: Compare dates and update if necessary
    if "%REMOTE_LAST_MODIFIED%" GTR "%LOCAL_LAST_MODIFIED%" (
        echo "Updating %DEPLOYER_SCRIPT% from %DEPLOYER_SCRIPT_URL%..."
        powershell -Command "Invoke-WebRequest -Uri '%DEPLOYER_SCRIPT_URL%' -OutFile '%DEPLOYER_SCRIPT_PATH%'"
    ) else (
        echo "No updates needed for %DEPLOYER_SCRIPT%."
    )
) else (
    echo "Deployer script for %PROJECT_TYPE% not found in code directory. Downloading from %DEPLOYER_SCRIPT_URL%..."
    powershell -Command "Invoke-WebRequest -Uri '%DEPLOYER_SCRIPT_URL%' -OutFile '%DEPLOYER_SCRIPT_PATH%'"
)

:: Ensure the deployer script was downloaded successfully
if not exist "%DEPLOYER_SCRIPT_PATH%" (
    echo "Error: Failed to download the deployer script to the code directory."
    exit /b 1
)

:: Call the specific deployment script from the code directory, passing necessary arguments with flags
call "%DEPLOYER_SCRIPT_PATH%" -pn "%PROJECT_NAME%" -sa "%SERVER_ADDRESS%" -sk "%SSH_KEY%" -su "%SSH_USERNAME%"
