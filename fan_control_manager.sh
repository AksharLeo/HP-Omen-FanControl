#!/bin/bash

# Create a temporary directory for the installation script
TEMP_DIR=$(mktemp -d)

# Define paths for the script and configuration files
SCRIPT_PATH="/usr/local/bin/fan_control_manager.sh"
CONFIG_PATH="/etc/fan_control.conf"
CRON_FILE="/etc/cron.d/fan_control_cron"

# Function to install the script
install_script() {
    # Prompt user for temperature threshold
    echo "Welcome to the Fan Control setup!"
    echo "Please enter the temperature threshold (in °C) for maximum fan speed (e.g., 85):"
    read -p "Temperature Threshold (°C): " TEMP_THRESHOLD

    # Check if the input is empty and default to 85°C if not provided
    if [ -z "$TEMP_THRESHOLD" ]; then
        echo "No temperature threshold provided. Defaulting to 85°C."
        TEMP_THRESHOLD=85
    fi

    # Validate the input
    if [[ ! "$TEMP_THRESHOLD" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a valid integer."
        exit 1
    fi

    # Convert the threshold to millidegrees Celsius (multiply by 1000)
    TEMP_THRESHOLD_MILLIDEGREE=$((TEMP_THRESHOLD * 1000))

    # Create the configuration file
    echo "# /etc/fan_control.conf" | sudo tee "$CONFIG_PATH" > /dev/null
    echo "# Temperature threshold for maximum fan speed (in millidegrees Celsius)" | sudo tee -a "$CONFIG_PATH" > /dev/null
    echo "TEMP_THRESHOLD=$TEMP_THRESHOLD_MILLIDEGREE" | sudo tee -a "$CONFIG_PATH" > /dev/null

    # Install the fan control script
    cat << 'EOF' | sudo tee "$SCRIPT_PATH" > /dev/null
#!/bin/bash

# Path to the configuration file
CONFIG_FILE="/etc/fan_control.conf"

# Default temperature threshold (in millidegrees Celsius)
DEFAULT_THRESHOLD=85000

# Check if the config file exists, and read the temperature threshold from it
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # If the config file does not exist, use the default threshold
    TEMP_THRESHOLD=$DEFAULT_THRESHOLD
fi

# Get the current system temperature (in millidegrees Celsius)
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)

# Determine the pwm1_enable value based on the temperature
if [ "$TEMP" -gt "$TEMP_THRESHOLD" ]; then
    PWM_VALUE=0  # Set pwm1_enable to 0 if the temperature is above the threshold
else
    PWM_VALUE=2  # Set pwm1_enable to 2 if the temperature is below the threshold
fi

# Find and update the pwm1_enable file(s)
for pwm_file in /sys/devices/platform/hp-wmi/hwmon/hwmon*/pwm1_enable; do
    echo "$PWM_VALUE" > "$pwm_file"
    echo "Updated $pwm_file to $PWM_VALUE"
done
EOF

    # Make the script executable
    sudo chmod +x "$SCRIPT_PATH"

    # Set up the cron job to run the script every 5 minutes
    echo "Setting up the cron job to run the fan control script every 5 minutes..."
    echo "*/5 * * * * root /usr/local/bin/fan_control_manager.sh" | sudo tee "$CRON_FILE" > /dev/null

    # Ensure the cron job is loaded by the cron daemon
    sudo systemctl restart cron

    # Completion message
    echo "Fan control setup complete!"
    echo "The fan control script will now run every 5 minutes, and you can modify the temperature threshold by editing $CONFIG_PATH."
}

# Function to uninstall the script
uninstall_script() {
    # Check if the user has sudo privileges
    if ! sudo -v; then
        echo "You need sudo privileges to uninstall the fan control script. Exiting."
        exit 1
    fi

    # Confirm with the user before uninstalling
    echo "Are you sure you want to uninstall the fan control script? (y/n)"
    read -p "Enter choice: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Uninstallation aborted."
        exit 0
    fi

    # Remove the fan control script
    echo "Removing the fan control script..."
    sudo rm -f "$SCRIPT_PATH"

    # Remove the configuration file
    if [ -f "$CONFIG_PATH" ]; then
        echo "Removing configuration file..."
        sudo rm -f "$CONFIG_PATH"
    fi

    # Remove the cron job
    if [ -f "$CRON_FILE" ]; then
        echo "Removing cron job..."
        sudo rm -f "$CRON_FILE"
    fi

    # Restart cron to apply changes
    sudo systemctl restart cron

    echo "Fan control has been uninstalled."
}

# Check for arguments (install or uninstall)
if [ "$1" == "install" ]; then
    install_script
elif [ "$1" == "uninstall" ]; then
    uninstall_script
else
    echo "Usage: $0 {install|uninstall}"
    exit 1
fi

# Clean up the temporary directory and remove the install/uninstall script
rm -rf "$TEMP_DIR"
