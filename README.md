# cloud-deployer
A dynamic Windows batch script for automating app deployments to cloud servers. Supports multiple project types by downloading and executing project-specific deployer scripts from separate repositories, using a flexible configuration file for easy management of server details, SSH keys, and deployment paths.

## Features

1. Project-specific deployment configuration using JSON files
2. Support for multiple project types (currently Phoenix and Rust)
3. Automatic download and update of project-specific deployer scripts
4. Logging of deployment process with timestamps
5. Error handling and validation of required parameters
6. Flexible command execution for different project types
7. SSH-based deployment to remote servers
8. Optional database handling for Phoenix projects
9. Dynamic script selection based on project type
10. Automatic creation of log directories
11. Real-time console output for deployment progress
12. Parameterized deployment allowing for project name and deployment directory specification
13. Version checking and updating of deployer scripts
14. Secure handling of SSH keys and server credentials
15. Cross-platform compatibility using PowerShell for certain operations

## Installation

1. Clone the repository to your local machine.

## Usage

To use the cloud-deployer, follow these steps:

1. Ensure you have a `config.json` file in your deployment directory with the necessary configuration for your project(s).

2. Open a command prompt or terminal.

3. Navigate to the directory containing the `main.bat` script.

4. Run the script with the following command structure:

   ```
   main.bat -pn <PROJECT_NAME> -dd <DEPLOYMENT_DIRECTORY>
   ```

   Where:
   - `-pn`: Specifies the project name (must match a project name in your `config.json`)
   - `-dd`: Specifies the deployment directory (where your `config.json` is located)

   Example:
   ```
   main.bat -pn my_phoenix_app -dd C:\deployments\my_phoenix_app
   ```

5. The script will automatically:
   - Load the configuration for the specified project
   - Download or update the appropriate deployer script (Phoenix or Rust)
   - Execute the deployment process
   - Log all actions to a timestamped log file in the `logs` subdirectory of your deployment directory

6. Monitor the console output for real-time deployment progress and check the log file for detailed information.

### Configuration

Ensure your `config.json` file in the deployment directory has the following structure for each project:

```json
{
    "project_name": {
        "type": "phoenix|rust",
        "ssh_key": "path/to/ssh_key.pem",
        "ssh_username": "username",
        "server_address": "server_address",
        "code_dir": "path/to/code/directory",
        "command": "deployment_command",
        "db": true|false
    }
}
```

### Notes:

- The `type` field should be either "phoenix" or "rust".
- The `ssh_key` field should point to the path of your SSH key file.
- The `ssh_username` is the username used for SSH connection.
- The `server_address` is the IP address or domain of your deployment server.
- The `code_dir` is the directory where your project code is located.
- The `command` field specifies the deployment command to run.
- The `db` field is a boolean indicating whether database operations are required (primarily for Phoenix projects).
- For Phoenix projects, both `command` and `db` fields are required.
- For Rust projects, the `db` field is optional and typically set to `false`.

Ensure that all paths are correct and accessible, and that the SSH key has the necessary permissions for deployment.
