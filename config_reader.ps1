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

        # Specifically handle escaping of special characters for batch script
        $escapedValue = $value -replace '([%\^\&\<\>\|])', '^$1' -replace '&&', '^&^&'

        # Append the variable assignment to the output content
        $outputContent += "$key=$escapedValue`n"
    }

    # Write the output content to the specified output file
    $outputContent | Set-Content -Path $OutputPath -Encoding ASCII
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
