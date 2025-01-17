#!/bin/bash

# Function to check for sudo privileges
check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "You must have sudo privileges to install or uninstall the fan control script."
        exit 1
    fi
}

# Prompt the user for install/uninstall
if [ "$1" == "install" ]; then
    # Check for sudo privileges
    check_sudo

    # Define the paths for the script and configuration
    SCRIPT_PATH="/usr/local/bin/fan_control.sh"
    CONFIG_PATH="/etc/fan_control.conf"
    CRON_FILE="/etc/cron.d/fan_control_cron"

    # Prompt the user for the temperature threshold (in °C)
    echo "Welcome to the Fan Control setup!"
    echo "Please enter the temperature threshold (in °C) for maximum fan speed (e.g., 85):"

    # Read user input for temperature threshold
    read -p "Temperature Threshold (°C): " TEMP_THRESHOLD

    # If no input is given, set the default value to 85°C
    if [ -z "$TEMP_THRESHOLD" ]; then
        TEMP_THRESHOLD=85
        echo "No threshold provided. Using default threshold of 85°C."
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
    echo "*/5 * * * * root /usr/local/bin/fan_control.sh" | sudo tee "$CRON_FILE" > /dev/null

    # Ensure the cron job is loaded by the cron daemon
    sudo systemctl restart cron

    # Completion message
    echo "Fan control setup complete!"
    echo "The fan control script will now run every 5 minutes, and you can modify the temperature threshold by editing $CONFIG_PATH."

elif [ "$1" == "uninstall" ]; then
    # Check for sudo privileges
    check_sudo

    # Uninstallation process
    echo "Uninstalling the fan control script..."

    # Remove the fan control script and configuration file
    sudo rm -f /usr/local/bin/fan_control.sh
    sudo rm -f /etc/fan_control.conf
    sudo rm -f /etc/cron.d/fan_control_cron

    # Stop the cron job if it exists
    sudo systemctl stop cron

    echo "Fan control script has been uninstalled successfully."

else
    # If neither "install" nor "uninstall" is passed, show usage
    echo "Usage: $0 {install|uninstall}"
    exit 1
fi
