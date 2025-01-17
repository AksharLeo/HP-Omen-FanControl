#!/bin/bash

# Check if the user has sudo privileges
if ! sudo -v; then
    echo "You need sudo privileges to manage this script. Exiting."
    exit 1
fi

# Define paths for the script, config file, and cron job
SCRIPT_PATH="/usr/local/bin/fan_control.sh"
CONFIG_PATH="/etc/fan_control.conf"
CRON_FILE="/etc/cron.d/fan_control_cron"

# Default temperature threshold (in °C)
DEFAULT_THRESHOLD=85  # Default threshold if no input is given (85°C)

# Function to install
install_fan_control() {
    # Prompt the user for the temperature threshold (in °C)
    echo "Welcome to the Fan Control setup!"
    echo "Please enter the temperature threshold (in °C) for maximum fan speed (e.g., 85). Press Enter to use the default threshold ($DEFAULT_THRESHOLD °C):"
    read -p "Temperature Threshold (°C): " TEMP_THRESHOLD

    # If no input is given, use the default temperature threshold
    if [ -z "$TEMP_THRESHOLD" ]; then
        TEMP_THRESHOLD=$DEFAULT_THRESHOLD
        echo "No input provided, using the default threshold of $DEFAULT_THRESHOLD°C."
    fi

    # Validate the input
    if [ -z "$TEMP_THRESHOLD" ] || ! echo "$TEMP_THRESHOLD" | grep -q '^[0-9]*$'; then
        echo "Invalid input. Please enter a valid integer for the temperature threshold."
        exit 1
    fi

    # Convert the threshold to millidegrees Celsius (multiply by 1000)
    TEMP_THRESHOLD_MILLIDEGREE=$((TEMP_THRESHOLD * 1000))

    # Create the configuration file
    echo "# /etc/fan_control.conf" | sudo tee "$CONFIG_PATH" > /dev/null
    echo "# Temperature threshold for maximum fan speed (in millidegrees Celsius)" | sudo tee -a "$CONFIG_PATH" > /dev/null
    echo "TEMP_THRESHOLD=$TEMP_THRESHOLD_MILLIDEGREE" | sudo tee -a "$CONFIG_PATH" > /dev/null

    # Create the fan control script
    cat << 'EOF' | sudo tee "$SCRIPT_PATH" > /dev/null
#!/bin/bash

# Path to the configuration file
CONFIG_FILE="/etc/fan_control.conf"

# Default temperature threshold (in millidegrees Celsius)
DEFAULT_THRESHOLD=85000  # Default threshold = 85.000°C (85000 millidegrees)

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
    echo "*/5 * * * * root /usr/local/bin/fan_control.sh" | sudo tee "$CRON_FILE" > /dev/null

    # Ensure the cron job is loaded by the cron daemon
    sudo systemctl restart cron

    # Completion message
    echo "Fan control setup complete!"
    echo "The fan control script will now run every 5 minutes, and you can modify the temperature threshold by editing $CONFIG_PATH."
}

# Function to uninstall
uninstall_fan_control() {
    echo "Uninstalling Fan Control..."
    # Remove the fan control script
    if [ -f "$SCRIPT_PATH" ]; then
        echo "Removing the fan control script..."
        sudo rm "$SCRIPT_PATH"
    else
        echo "Fan control script not found. Skipping removal."
    fi

    # Remove the configuration file
    if [ -f "$CONFIG_PATH" ]; then
        echo "Removing the configuration file..."
        sudo rm "$CONFIG_PATH"
    else
        echo "Configuration file not found. Skipping removal."
    fi

    # Remove the cron job
    if [ -f "$CRON_FILE" ]; then
        echo "Removing the cron job..."
        sudo rm "$CRON_FILE"
        # Restart the cron service to apply changes
        sudo systemctl restart cron
    else
        echo "Cron job not found. Skipping removal."
    fi

    # Completion message
    echo "Fan control has been successfully uninstalled."
}

# Ask the user what action to take
echo "Do you want to (I)nstall or (U)ninstall the fan control script? (I/U):"
read -p "Choose (I/U): " ACTION

# Execute the appropriate function based on user input
if [ "$ACTION" = "I" ] || [ "$ACTION" = "i" ]; then
    install_fan_control
elif [ "$ACTION" = "U" ] || [ "$ACTION" = "u" ]; then
    uninstall_fan_control
else
    echo "Invalid choice. Exiting."
    exit 1
fi
