# RocketInstall

RocketInstall is a comprehensive bash script for setting up a Rocket Pool Ethereum staking node. It simplifies the setup process by automating critical tasks such as creating a swap file, installing Docker, configuring Rocket Pool, setting SSH security setting, and ensuring system reliability through unattended upgrades and firewall configurations.

---

## Installation

1. Clone the repository or download the script:
   
   wget https://raw.githubusercontent.com/centauridoteth/RocketInstall/refs/heads/main/Rocketinstall.sh -O rocketinstall.sh
   chmod +x rocketinstall.sh

2. Run the script:

./rocketinstall.sh

---

## Prerequisites

- A fresh installation of Ubuntu or Debian.
- Administrative privileges (`sudo` access).
- SSH key added to `~/.ssh/authorized_keys` for secure remote connection to the node.

---

Usage

Upon running the script, you will be presented with an interactive menu:

1. Full Setup:

Automates the entire setup process, including swap file creation, Rocket Pool installation, SSH security hardening, unattended upgrades, and firewall configuration.

2. Individual Tasks:

Run specific tasks, such as creating a swap file or configuring SSH, without executing the full setup.

3. Exit:

Exits the script.

---

Configuration

SSH Security

Ensure your public SSH key is added to ~/.ssh/authorized_keys before running the script. Follow Rocket Pool's SSH guide for details.
(https://docs.rocketpool.net/guides/node/securing-your-node)

Firewall

ufw is configured to allow only the necessary ports:

22 (SSH)

30303 (Execution client)

9001 & 8001 (Consensus client)

---

## Features

1. **Automated Distribution Detection**:
   - Automatically detects Ubuntu or Debian to tailor the setup process.

2. **Swap File Creation**:
   - Creates a swap file (default size: 16GB, customizable between 1GB and 64GB).
   - Configures swap settings for optimal performance.

3. **Rocket Pool Installation**:
   - Downloads and installs the Rocket Pool Smartnode package. (For both ARM and x86 CPU's)
   

4. **Docker Installation**:
   - Installs Docker and its required components for Rocket Pool.

5. **SSH Security**:
   - Hardens the SSH configuration as recommended by Rocket Pool documentation.
   - Enables `fail2ban` for intrusion detection.

6. **Unattended Upgrades**:
   - Configures automatic system updates and reboots to ensure your node remains up-to-date.

7. **Firewall Configuration**:
   - Sets up `ufw` with pre-configured rules for Rocket Pool's required ports.

8. **Interactive Menu**:
   - User-friendly menu for running the full setup or individual tasks.

---

Recommendations

Reboot After Setup: A reboot is recommended to apply all changes.

Monitor Logs: Regularly check fail2ban and Docker logs to ensure system health.

