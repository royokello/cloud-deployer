"""
Cloud Deployer
"""

import argparse
import os
from datetime import datetime
import json
import subprocess
import sys
import logging
import requests


def setup_logging(log_file):
    """
    Setup logging to file and console
    """
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[logging.FileHandler(log_file), logging.StreamHandler()],
    )


def log_message(message):
    """
    Log a message to the console and file
    """
    logging.info(message)


def main():
    """
    Main function
    """
    parser = argparse.ArgumentParser(description="Cloud Deployer")
    parser.add_argument(
        "-cd",
        "--cloud-directory",
        type=str,
        required=True,
        help="The directory containing the cloud configuration files",
    )
    parser.add_argument(
        "-pn",
        "--project-name",
        type=str,
        required=True,
        help="The name of the project to deploy",
    )
    args = parser.parse_args()

    cloud_dir = args.cloud_directory
    project_name = args.project_name

    config_file = os.path.join(cloud_dir, "config.json")

    if not os.path.exists(config_file):
        raise ValueError(f"Configuration file not found in {cloud_dir}")

    logs_dir = os.path.join(cloud_dir, "logs")
    if not os.path.exists(logs_dir):
        os.makedirs(logs_dir)

    log_name = f"{project_name}_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.log"
    log_file = os.path.join(logs_dir, log_name)

    setup_logging(log_file)
    log_message(f"Starting deployment for project {project_name}")

    with open(config_file, "r", encoding="utf-8") as file:
        config = json.load(file)

    project_config = config[project_name]

    project_type = project_config["project_type"]
    ssh_key = project_config["ssh_key"]
    ssh_username = project_config["ssh_username"]
    server_address = project_config["server_address"]
    code_dir = project_config["code_dir"]
    command = project_config["command"]
    db = project_config["db"]

    log_message(f"Configuration loaded successfully for project '{project_name}'.")
    log_message("Configuration Details:")
    log_message(f"  project_type    = {project_type}")
    log_message(f"  code_dir        = {code_dir}")
    log_message(f"  ssh_key         = {ssh_key}")
    log_message(f"  server_address  = {server_address}")
    log_message(f"  ssh_username    = {ssh_username}")
    log_message(f"  command         = {command}")
    log_message(f"  DB              = {db}")

    if project_type == "phoenix":
        deployer_script_url = "https://raw.githubusercontent.com/royokello/phoenix-deployer/main/phoenix_deployer.bat"
        deployer_script = "phoenix_deployer.bat"
    elif project_type == "rust":
        deployer_script_url = "https://raw.githubusercontent.com/royokello/rust-deployer/main/rust_deployer.bat"
        deployer_script = "rust_deployer.bat"
    else:
        log_message(f"Error: Unsupported project type '{project_type}'.")
        exit(1)

    deployer_script_path = os.path.join(code_dir, deployer_script)

    log_message(f"Downloading {deployer_script} from {deployer_script_url}...")
    response = requests.get(deployer_script_url, timeout=10)
    with open(deployer_script_path, "wb") as file:
        file.write(response.content)

    log_message(f"{deployer_script} downloaded successfully.")

    if project_type == "phoenix":
        if command == "":
            log_message("Command required for phoenix projects.")
            exit(1)

        log_message(f"Executing Phoenix deployer script at '{deployer_script_path}'")
        cmd = [
            deployer_script_path,
            "-pn",
            project_name,
            "-sa",
            server_address,
            "-sk",
            ssh_key,
            "-su",
            ssh_username,
            "-cmd",
            command,
            "-db",
            db,
            "-log",
            log_file,
        ]
    elif project_type == "rust":
        log_message("Executing Rust deployer script...")
        cmd = [
            deployer_script_path,
            "-pn",
            project_name,
            "-sa",
            server_address,
            "-sk",
            ssh_key,
            "-su",
            ssh_username,
            "-cmd",
            command,
            "-log",
            log_file,
        ]
    else:
        log_message(f"Unsupported project type '{project_type}'.")
        exit(1)

    try:
        with open(log_file, "a", encoding="utf-8") as log_f:
            subprocess.run(
                cmd,
                stdout=log_f,
                stderr=subprocess.STDOUT,
                check=True,
                shell=True,  # Set to True if necessary; otherwise, False is safer
            )
        log_message("Deployer script executed successfully.")
    except subprocess.CalledProcessError as e:
        log_message(
            f"Deployer script failed with return code {e.returncode}. Check the log file for details."
        )
        sys.exit(e.returncode)
    except Exception as e:
        log_message(
            f"An unexpected error occurred while executing the deployer script: {e}"
        )
        sys.exit(1)

    log_message(f"Deployment completed successfully for project {project_name}.")


if __name__ == "__main__":
    main()
