#!/bin/bash


show_disro() {

OS=$(grep '^ID=' /etc/os-release | cut -d '=' -f 2-)


if [ "$OS" = "debian" ]; then
    echo "$OS detected"
  elif [ "$OS" = "ubuntu" ]; then
    echo "$OS detected"
  else
    echo "It seems like you are running a "$OS" based distrobution, this script has only been tested for Ubuntu and Debian."
    exit 0
fi
}


create_swap() {
  # Check if swapfile already exists
  if [ -f /swapfile ]; then
    echo "Swapfile already exists. Please remove it if you want to create a new one. (sudo swapoff /swapfile && sudo rm /swapfile)"
    return 0
  fi
  # Ask user for desired size of the swapfile (with a sane default of 16G)
  while true; do
    read -p "Enter the size of your swap file in Gigabytes, press enter for default (16G):" swap_size
    if [ -z "$swap_size" ]; then
      swap_size="16"
      break
    elif [[ $swap_size =~ ^[0-9]+$ ]] && (( swap_size >= 1 && swap_size <= 64 )); then
      break
    else
      echo "Please enter a number between 1 and 64"
      echo "" # Spacer
    fi
  done
  # Create, set permission and create a fstab entry of the swapfile 
  echo "Creating swapfile of size "$swap_size"G"
  sudo dd if=/dev/zero of=/swapfile bs=1G count=$swap_size status=progress > /dev/null 2>&1
  sudo chmod 600 /swapfile
  echo "Swapfile created" 
  sudo mkswap /swapfile > /dev/null 2>&1
  sudo swapon /swapfile > /dev/null 2>&1
  sudo cp -p /etc/fstab /etc/fstab.bak #cant hurt to have a backup
  if grep -q "/swapfile                            none            swap    sw              0       0" /etc/fstab; then
    echo "Swapfile entry already exists in fstab."
	else
	echo "/swapfile                            none            swap    sw              0       0" | sudo tee -a /etc/fstab > /dev/null 2>&1
	echo "Swapfile entry written to fstab."
  fi
  echo ""$swap_size"G of swap created"
  sudo grep -q "vm.swappiness=" /etc/sysctl.conf || echo "vm.swappiness=6" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
  sudo grep -q "vm.vfs_cache_pressure=" /etc/sysctl.conf || echo "vm.vfs_cache_pressure=10" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
  echo "Swappiness set in the /etc/systctl.conf file"
  echo "" # Spacer
}


download_rocketpool() {
  cpu_arc=$(uname -m)

  if ! which wget > /dev/null 2>&1; then
    echo "wget is not installed, installing..."
    (sudo apt update && sudo apt install wget -y) || exit 1
  fi

  if [ -f ~/bin/rocketpool ]; then
    echo "~/bin/rocketpool already installed"
    if [ ! -x ~/bin/rocketpool ]; then
      echo "~/bin/rocketpool already installed, but not executable. Making it executable"
      chmod +x ~/bin/rocketpool || exit 1
    fi
  else
    echo "~/bin/rocketpool not installed, Installing..."
    mkdir -p ~/bin
    url="https://github.com/rocket-pool/smartnode/releases/latest/download/rocketpool-cli-linux-"
    if [ "$cpu_arc" = "x86_64" ]; then
      url+="amd64"
    else
      url+="arm64"
    fi
    wget "$url" -O ~/bin/rocketpool > /dev/null 2>&1 || exit 1
    chmod +x ~/bin/rocketpool || exit 1
    echo "Rocketpool has been downloaded"
  fi
}




docker_install() {
# docker install
# prerequisits for the install
sudo apt update &> /dev/null
sudo apt install ca-certificates curl -y &> /dev/null
sudo install -m 0755 -d /etc/apt/keyrings &> /dev/null
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc &> /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc &> /dev/null
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update &> /dev/null

for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt remove $pkg -y &> /dev/null; done
PACKAGES=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
for PACKAGE in "${PACKAGES[@]}"; do sudo apt install $PACKAGE -y &> /dev/null; done
echo "Docker has been installed"
echo "" # Spacer

sudo usermod -aG docker $USER

sudo systemctl restart docker

}

install_rocketpool() {

OS=$(grep '^ID=' /etc/os-release | cut -d '=' -f 2-)

if [ "$OS" = "debian" ]; then
    docker_install
    ~/bin/rocketpool service install -d
  elif [ "$OS" = "ubuntu" ]; then
    ~/bin/rocketpool service install
  else
    exit 0
fi
}


secure_ssh() {

KEYFILE=$(grep -i ssh ~/.ssh/authorized_keys)
  if [ -z "$KEYFILE" ]; then
    echo "No ssh-keys found in the authorized_keys file, please add your ssh public key to the file"
    echo "https://docs.rocketpool.net/guides/node/securing-your-node"
    echo "Please follow the steps under "Adding the Public Key to your Node" in the documentation above"
  else 
    sudo sed -i "/#.*$/!s|.*AuthorizedKeysFile.*|AuthorizedKeysFile .ssh/authorized_keys|" /etc/ssh/sshd_config
    sudo sed -i "/#.*$/!s|.*KbdInteractiveAuthentication.*|KbdInteractiveAuthentication no|" /etc/ssh/sshd_config
    sudo sed -i "/#.*$/!s|.*PasswordAuthentication.*|PasswordAuthentication no|" /etc/ssh/sshd_config
    sudo sed -i "/#.*$/!s|.*PermitRootLogin.*|PermitRootLogin prohibit-password|" /etc/ssh/sshd_config

    #Ubuntu 
    sudo sed -i "/Include \/etc\/ssh\/sshd_config.d/s/^/#/" /etc/ssh/sshd_config
    #  if the sshd_config file were missing some of the above options, the sed command will have done nothing, therefore its important
    #  we check that all options were set correctly.
    sudo grep -q "^[^#]*AuthorizedKeysFile .ssh/authorized_keys" /etc/ssh/sshd_config || echo "AuthorizedKeysFile .ssh/authorized_keys" | sudo tee -a /etc/ssh/sshd_config > /dev/null 2>&1
    sudo grep -q "^[^#]*KbdInteractiveAuthentication no" /etc/ssh/sshd_config || echo "KbdInteractiveAuthentication no" | sudo tee -a /etc/ssh/sshd_config > /dev/null 2>&1
    sudo grep -q "^[^#]*PasswordAuthentication no" /etc/ssh/sshd_config || echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config > /dev/null 2>&1
    sudo grep -q "^[^#]*PermitRootLogin prohibit-password" /etc/ssh/sshd_config || echo "PermitRootLogin prohibit-password" | sudo tee -a /etc/ssh/sshd_config > /dev/null 2>&1

    sudo apt update > /dev/null 2>&1
    sudo apt install fail2ban -y > /dev/null 2>&1
    echo "[sshd]
enabled = true
banaction = ufw
port = 22
filter = sshd
logpath = %(sshd_log)s
maxretry = 5" | sudo tee /etc/fail2ban/jail.d/ssh.local > /dev/null 2>&1

    echo "The recomended changes to the sshd_config according to the Rocketpool documentation has been performed"
    echo "" # Spacer
  fi
}


unattended_upgrades() {

OS=$(grep '^ID=' /etc/os-release | cut -d '=' -f 2-)
date=$(date +"%Y-%m-%d-%H")

# again, small differences between distros
if [ "$OS" = "debian" ]; then

    read -p "We will now enable unattended_upgrades, if you have made changes to the /etc/apt/apt.conf.d/50unattended-upgrades configuration, they will be overwritten, but the old configuration will be saved in /etc/apt/apt.conf.d/50unattended-upgrades.$date.bak (press enter to continue)" temp
    echo "" # Spacer

    sudo apt update > /dev/null 2>&1
    sudo apt install unattended-upgrades apt-config-auto-update -y > /dev/null 2>&1 # seems like the "update-notifier-common is named "apt-config-auto-update" in Debian repos
    sudo cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.$date.bak
    echo "APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

# This is the most important choice: auto-reboot.
# This should be fine since Rocketpool auto-starts on reboot.
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";" | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null 2>&1

elif [ "$OS" = "ubuntu" ]; then

    read -p "We will now enable unattended_upgrades, if you have made changes to the /etc/apt/apt.conf.d/20auto-upgrades configuration, they will be overwritten, but the old configuration will be saved in /etc/apt/apt.conf.d/20auto-upgrades.$date.bak (press enter to continue)" temp
    echo "" # Spacer

    sudo apt update > /dev/null 2>&1
    sudo apt install unattended-upgrades update-notifier-common -y > /dev/null 2>&1
    sudo cp /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades.$date.bak
    echo "APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

# This is the most important choice: auto-reboot.
# This should be fine since Rocketpool auto-starts on reboot.
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";" | sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null 2>&1
  else
    exit 0
fi
}


firewall() {

sudo apt update > /dev/null 2>&1
sudo apt install ufw > /dev/null 2>&1

read -p "The ufw firewall will installed and setup, you will be promted with 'Command may disrupt existing ssh connections. Proceed with operation (y|n)?' your session should not get disrupted because the default ssh port (22) will not be blocked by the firewall (press enter)" temp
echo "" # Spacer
sudo ufw default deny incoming comment 'Deny all incoming traffic' > /dev/null 2>&1
sudo ufw allow "22/tcp" comment 'Allow SSH' > /dev/null 2>&1
sudo ufw allow 30303/tcp comment 'Execution client port, standardized by Rocket Pool' > /dev/null 2>&1
sudo ufw allow 30303/udp comment 'Execution client port, standardized by Rocket Pool' > /dev/null 2>&1
sudo ufw allow 9001/tcp comment 'Consensus client port, standardized by Rocket Pool' > /dev/null 2>&1
sudo ufw allow 9001/udp comment 'Consensus client port, standardized by Rocket Pool' > /dev/null 2>&1
sudo ufw allow 8001/udp comment 'Consensus client port, standardised by Rocket Pool' > /dev/null 2>&1
sudo ufw enable

echo "The ufw firewall has been installed and setup" 
echo "" # Spacer

}

reboot_node() {

echo "It is heavily recommended that you perform a reboot before proceeding. Do you want to reboot now? (y/n) "
    local choice
    read -p "Enter your choice: " choice
    case $choice in
        y|Y|yes|Yes) echo "rebooting..." && sleep 1 && sudo reboot now ;;
        n|N|no|No)  echo "no reboot requested, exiting" && exit 0;;
        *) echo -e "Invalid option. Please try again..." && sleep 1 ;;
    esac
}

install_done() {

echo "WOHOO, YOUR NODE HAS BEEN SUCCESSFULLY SETUP"
echo ""
echo "
______           _        _    ______           _
| ___ \         | |      | |   | ___ \         | |
| |_/ /___   ___| | _____| |_  | |_/ /__   ___ | |
|    // _ \ / __| |/ / _ \ __| |  __/ _ \ / _ \| |
| |\ \ (_) | (__|   <  __/ |_  | | | (_) | (_) | |
\_| \_\___/ \___|_|\_\___|\__| \_|  \___/ \___/|_|



"

}

show_menu1() {
    clear
    echo "Choose a function to execute:"
    echo "1. Run the setup script from scrach, Make a swapfile, install Rocketpool and make the recomended changes to the sshd_config."
    echo "Choose this option if you are setting up a new node from scratch."
    echo "" # Spacer
    echo "2. Run a specific function in the script such as only setting up the swapfile, but not ssh as an example."
    echo "Intended as a secondary option. Should not be used in most cases."
    echo "" # Spacer
    echo "3. Exit"
}

read_input1() {
    local choice
    read -p "Enter your choice [1-3]: " choice
    case $choice in
        1) show_disro && create_swap && download_rocketpool && install_rocketpool && secure_ssh && unattended_upgrades && firewall && install_done && reboot_node;;
        2) clear && read_input2 ;;
        3) exit 0 ;;
        *) echo -e "Invalid option. Please try again..." && sleep 1 ;;
    esac
  read -p "(press enter to continue)" temp
  clear
}

show_menu2() {
    echo "Choose a function to execute:"
    echo "1. Create a swapfile. This function will create a swapfile and set it up"
    echo "2. Install Rocketpool. This function will install the Smartnode package."
    echo "3. Make the recomended changes to the sshd_config according to the Rocketpool documentation"
    echo "4. Enable unattended_upgrades according to the Rocketpool documentation"
    echo "5. Enable and configure the ufw firewall according to the Rocketpool documentation"
    echo "6. Reboot the node" 
    echo "7. Exit"
    }

# Function to read user input and execute corresponding function
read_input2() {
  while true; do
    show_menu2
    local choice
    read -p "Enter your choice [1-7]: " choice
    case $choice in
        1) create_swap ;;
        2) download_rocketpool && install_rocketpool;;
        3) secure_ssh;;
        4) unattended_upgrades;;
        5) firewall;;
        6) reboot_node;;
        7) exit 0 ;;
        *) echo -e "Invalid option. Please try again..." && sleep 1 ;;
    esac
  read -p "(press enter to continue)" temp
  clear
  done
    }

# Loop until user decides to exit
while true; do
    show_menu1
    read_input1
done
