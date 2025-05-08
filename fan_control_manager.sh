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
    check_sudo

    SCRIPT_PATH="/usr/local/bin/fan_control.sh"
    CONFIG_PATH="/etc/fan_control.conf"
    CRON_FILE="/etc/cron.d/fan_control_cron"

    echo "Welcome to the Fan Control setup!"
    echo "Please enter the temperature threshold (in °C) for maximum fan speed (e.g., 85):"
    read -p "Temperature Threshold (°C): " TEMP_THRESHOLD

    if [ -z "$TEMP_THRESHOLD" ]; then
        TEMP_THRESHOLD=85
        echo "No threshold provided. Using default threshold of 85°C."
    fi

    TEMP_THRESHOLD_MILLIDEGREE=$((TEMP_THRESHOLD * 1000))

    echo "# /etc/fan_control.conf" | sudo tee "$CONFIG_PATH" > /dev/null
    echo "# Temperature threshold for maximum fan speed (in millidegrees Celsius)" | sudo tee -a "$CONFIG_PATH" > /dev/null
    echo "TEMP_THRESHOLD=$TEMP_THRESHOLD_MILLIDEGREE" | sudo tee -a "$CONFIG_PATH" > /dev/null

    cat << 'EOF' | sudo tee "$SCRIPT_PATH" > /dev/null
#!/bin/bash

CONFIG_FILE="/etc/fan_control.conf"
DEFAULT_THRESHOLD=85000

# Load threshold
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    TEMP_THRESHOLD=$DEFAULT_THRESHOLD
fi

# Read current temperature
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
else
    echo "Temperature sensor not found."
    exit 1
fi

# Decide PWM setting
if [ "$TEMP" -gt "$TEMP_THRESHOLD" ]; then
    PWM_VALUE=0  # Max fan
else
    PWM_VALUE=2  # Auto
fi

# Update pwm1_enable
for pwm_file in /sys/devices/platform/hp-wmi/hwmon/hwmon*/pwm1_enable; do
    if [ -e "$pwm_file" ]; then
        echo "$PWM_VALUE" > "$pwm_file" 2>/dev/null && echo "Updated $pwm_file to $PWM_VALUE"
    fi
done
EOF

    sudo chmod +x "$SCRIPT_PATH"

    echo "Setting up the cron job to run the fan control script every 5 minutes..."
    echo "*/5 * * * * root /usr/local/bin/fan_control.sh" | sudo tee "$CRON_FILE" > /dev/null

    # Try to detect and restart cron service
    if systemctl list-units --type=service | grep -qE 'cron.service|cronie.service'; then
        sudo systemctl restart cron.service 2>/dev/null || sudo systemctl restart cronie.service
    else
        echo "⚠️ Warning: No cron service found (cron or cronie). Please ensure it's installed and enabled."
    fi

    echo "✅ Fan control setup complete!"
    echo "The fan control script will now run every 5 minutes. Edit $CONFIG_PATH to change the threshold."

elif [ "$1" == "uninstall" ]; then
    check_sudo

    echo "Uninstalling the fan control script..."
    sudo rm -f /usr/local/bin/fan_control.sh
    sudo rm -f /etc/fan_control.conf
    sudo rm -f /etc/cron.d/fan_control_cron

    echo "🗑️ Removed script, config, and cron job. You may disable cron manually if needed."

else
    echo "Usage: $0 {install|uninstall}"
    exit 1
fi
