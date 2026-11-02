
#!/bin/bash
set -Eeuo pipefail

echo "Starting Jenkins EC2 setup..."

# --------------------------------
# Clean old repository entries
# --------------------------------

sudo rm -f /etc/apt/sources.list.d/jenkins.list
sudo rm -f /etc/apt/sources.list.d/trivy.list
sudo rm -f /etc/apt/sources.list.d/helm-stable-debian.list

sudo rm -f /usr/share/keyrings/jenkins-keyring.asc
sudo rm -f /usr/share/keyrings/trivy.gpg
sudo rm -f /usr/share/keyrings/helm.gpg

# --------------------------------
# Install dependencies
# --------------------------------

sudo apt-get update

sudo apt-get install -y \
    fontconfig \
    openjdk-21-jre \
    curl \
    wget \
    gnupg \
    ca-certificates \
    lsb-release \
    unzip

# --------------------------------
# Jenkins LTS
# --------------------------------

echo "Installing Jenkins..."

sudo mkdir -p /etc/apt/keyrings

sudo wget -q -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# --------------------------------
# Docker
# --------------------------------

echo "Installing Docker..."

sudo apt-get update
sudo apt-get install -y docker.io

sudo systemctl enable --now docker

# --------------------------------
# Trivy
# --------------------------------

echo "Installing Trivy..."

curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

# --------------------------------
# Helm
# --------------------------------

echo "Installing Helm..."

HELM_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
    -o /tmp/helm.asc

ACTUAL_HELM_KEY_ID=$(gpg --show-keys --with-colons /tmp/helm.asc \
    | awk -F: '$1 == "fpr" {print $10; exit}')

if [ "$ACTUAL_HELM_KEY_ID" != "$HELM_KEY_ID" ]; then
    echo "ERROR: Helm signing key verification failed"
    exit 1
fi

gpg --dearmor < /tmp/helm.asc \
    | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" \
    | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null

# --------------------------------
# Install Jenkins, Trivy and Helm
# --------------------------------

sudo apt-get update

sudo apt-get install -y jenkins trivy helm

# --------------------------------
# AWS CLI v2
# --------------------------------

echo "Installing AWS CLI..."

ARCH=$(dpkg --print-architecture)

case "$ARCH" in
    amd64) AWS_ARCH="x86_64" ;;
    arm64) AWS_ARCH="aarch64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

curl -fsSL \
    "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
    -o /tmp/awscliv2.zip

unzip -oq /tmp/awscliv2.zip -d /tmp

sudo /tmp/aws/install --update

rm -rf /tmp/aws /tmp/awscliv2.zip /tmp/helm.asc

# --------------------------------
# Docker permissions
# --------------------------------

echo "Configuring Docker permissions..."

LOGIN_USER="${SUDO_USER:-ubuntu}"

sudo usermod -aG docker "$LOGIN_USER"
sudo usermod -aG docker jenkins

# --------------------------------
# Start services
# --------------------------------

echo "Starting services..."

sudo systemctl enable --now docker
sudo systemctl enable --now jenkins
sudo systemctl restart jenkins

# --------------------------------
# Verify installations
# --------------------------------

echo "Checking installed versions..."

java -version
docker --version
trivy --version
aws --version
helm version

sudo systemctl is-active docker
sudo systemctl is-active jenkins

echo "=================================="
echo "Jenkins EC2 setup completed!"
echo "=================================="
