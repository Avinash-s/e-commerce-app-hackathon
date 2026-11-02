
#!/bin/bash
set -Eeuo pipefail

# Update system packages
sudo apt-get update -y

# Install Snap
sudo apt-get install -y snapd

sudo systemctl enable --now snapd

# Install AWS CLI
sudo snap install aws-cli --classic

# Install Helm
sudo snap install helm --classic

# Install kubectl
sudo snap install kubectl --classic

# Verify installations
aws --version
helm version
kubectl version --client

echo "Bastion host tools installation completed successfully"
