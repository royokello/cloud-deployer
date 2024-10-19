param(
    [string]$ConfigPath,
    [string]$ProjectName,
    [string]$OutputPath
)

try {
    # Read the JSON configuration file
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

    # Check if the project exists
    if (-not $config.PSObject.Properties.Name -contains $ProjectName) {
        Write-Error "Project '$ProjectName' not found in configuration."
        exit 1
    }

    # Get the project configuration
    $projectConfig = $config.$ProjectName

    # Prepare the output content
    $outputContent = ""

    foreach ($key in $projectConfig.PSObject.Properties.Name) {
        $value = $projectConfig.$key

        # Handle null values
        if ($value -eq $null) {
            $value = ''
        }

        # Check if the key is 'command' and handle special characters
        if ($key -eq 'command') {
            $value = "`"$value`""  # Wrap command in double quotes to escape special characters
        }

        # Append the variable assignment to the output content as-is
        $outputContent += "$key=$value`n"
    }

    # Write the output content to the specified output file
    $outputContent | Set-Content -Path $OutputPath -Encoding ASCII
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
