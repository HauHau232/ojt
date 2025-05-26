#!/bin/bash

# Set a log file
LOGFILE="/var/log/setup.log"

# Reset the log file
echo "" > $LOGFILE

# Function to write to log file
log_message() {
    echo "$1" >> "$LOGFILE"
}

# Function to display console messages
console_message() {
    flg="${2:-n}"
    str=$1
    if [ $flg == 1 ]; then
        str="$1\n"
    fi
    echo -e $str
    echo -e "\n----> $1 <----\n" >> $LOGFILE
}

# Function to execute command and log messages
execute_and_log() {
    log_message "Executing: $1"
    eval $1 >> $LOGFILE 2>&1
    status=$?
    if [ $status -ne 0 ]; then
        echo "Error: '$1' failed with status $status. Check /var/log/setup.log."
        exit 1
    fi
    return $status
}

# Function to exectute and log messages with progress indicator
execute_and_log_with_progress() {
    log_message "Executing: $1"
    eval $1 >> $LOGFILE 2>&1 &
    pid=$!
    progress_indicator=('|' '/' '-' '|')
    index=0

    while kill -0 $pid 2> /dev/null; do
        echo -ne "${progress_indicator[$index]} Command is still running...\r"
        sleep 1
        let "index = (index + 1) % 4"
    done
    echo ""
    wait $pid
    status=$?
    if [ $status -ne 0 ]; then
        echo "Error: '$1' failed with status $status. Check /var/log/setup.log."
        exit 1
    else
        echo "" >> $LOGFILE
    fi
    return $status
}

# Function to display progress messages
progress_message() {
    echo "========================================================" | tee -a $LOGFILE
    echo $1 | tee -a $LOGFILE
    echo "========================================================" | tee -a $LOGFILE
}

# Change nameservers
progress_message "Changing nameservers..."
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "\-i\-"; then
    execute_and_log "chattr -i /etc/resolv.conf"
    console_message "Removed immutable attribute from /etc/resolv.conf."
fi
execute_and_log "rm -f /etc/resolv.conf"
execute_and_log "echo -e \"nameserver 8.8.8.8\nnameserver 1.1.1.1\" > /etc/resolv.conf"
execute_and_log "chattr +i /etc/resolv.conf"
console_message "Changed nameservers." 1

# Update Ubuntu
progress_message "Updating Ubuntu... (This may take some time...)"
execute_and_log "hwclock --hctosys"
execute_and_log_with_progress "ping -c 2 8.8.8.8"
console_message "Checked internet connectivity. (Step 1/3)"
execute_and_log_with_progress "apt-get update -y"
console_message "Updated Ubuntu. (Step 2/3)"
execute_and_log_with_progress "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
console_message "Upgraded Ubuntu. (Step 3/3)" 1

# Install Docker
progress_message "Installing Docker... (This may take some time...)"
execute_and_log_with_progress "curl -fsSL https://get.docker.com | sh"
console_message "Installed Docker." 1

# Install tinet
progress_message "Installing tinet..."
execute_and_log "cp /mnt/c/tinet/tinet /usr/bin/tinet"
execute_and_log "chmod +x /usr/bin/tinet"
console_message "Installed tinet." 1

# Write to wsl.conf
progress_message "Writing to wsl.conf..."
execute_and_log "echo -e \"[network]\nhostname = UBUNTU\ngenerateResolvConf = false\n[boot]\ncommand = service docker start\n[user]\ndefault = root\" > /etc/wsl.conf"
console_message "Wrote to wsl.conf." 1

progress_message "Setup complete. Please restart this WSL instance."
