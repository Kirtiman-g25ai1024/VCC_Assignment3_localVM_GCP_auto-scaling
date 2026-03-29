#!/usr/bin/env python3
"""Auto-scale controller: provisions GCP VM via Terraform"""

import subprocess
import sys
import time
import logging

logging.basicConfig(
    filename='/var/log/autoscale.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

TERRAFORM_DIR = '/opt/autoscale-demo/terraform'


def run_cmd(cmd, cwd=None):
    """Execute a shell command and log the result."""
    result = subprocess.run(
        cmd, shell=True,
        capture_output=True, text=True, cwd=cwd
    )
    logging.info(f'CMD: {cmd} | RC: {result.returncode}')
    return result


def scale_up():
    """Provision a GCP VM and deploy the application."""
    logging.info('=== SCALE UP TRIGGERED ===')

    # Initialize Terraform
    run_cmd('terraform init', cwd=TERRAFORM_DIR)

    # Apply infrastructure
    result = run_cmd('terraform apply -auto-approve', cwd=TERRAFORM_DIR)
    if result.returncode != 0:
        logging.error(f'Terraform failed: {result.stderr}')
        return False

    # Get the cloud VM IP
    ip_result = run_cmd(
        'terraform output -raw instance_ip',
        cwd=TERRAFORM_DIR
    )
    cloud_ip = ip_result.stdout.strip()
    logging.info(f'Cloud VM provisioned at {cloud_ip}')

    # Wait for VM to be ready (up to 5 min)
    for i in range(30):
        check = run_cmd(f'curl -sf http://{cloud_ip}:5000/health')
        if check.returncode == 0:
            logging.info('Cloud VM health check PASSED')
            return True
        time.sleep(10)

    logging.error('Cloud VM failed health check')
    return False


def scale_down():
    """Destroy the GCP VM to save costs."""
    logging.info('=== SCALE DOWN TRIGGERED ===')
    result = run_cmd('terraform destroy -auto-approve', cwd=TERRAFORM_DIR)
    return result.returncode == 0


if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'scale-up':
        scale_up()
    elif action == 'scale-down':
        scale_down()
    else:
        print('Usage: autoscale.py [scale-up|scale-down]')
