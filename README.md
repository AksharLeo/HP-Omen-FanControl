# HP Omen Fan Control Script

**Warning**: This script is designed specifically for **HP Omen laptops** and has only been tested on the **HP Omen C0140AX**. It may not work correctly on other models.

This script controls the fan speed based on the system's temperature. It can be installed and configured with a customizable temperature threshold for maximum fan speed. The script runs every 5 minutes to ensure the system remains cool by adjusting the fan speed as needed.

## Features
- Automatically adjusts fan speed based on temperature.
- Configurable temperature threshold.
- Runs every 5 minutes.
- Easy to install and uninstall.

## Prerequisites
- A Linux system with `sudo` privileges.
- The system must support fan control via the `hp-wmi` driver.

## Installation

To install the script, simply run the following command:

```bash
curl -sSL https://raw.githubusercontent.com/AksharLeo/HP-Omen-FanControl/main/fan_control_manager.sh -o /tmp/fan_control_manager.sh && sudo bash /tmp/fan_control_manager.sh install && rm -f /tmp/fan_control_manager.sh

```

This command will:
1. Prompt you to set a temperature threshold (in °C) for maximum fan speed.
2. Install the necessary files to control your fan speed.
3. Set up a cron job to run the fan control script every 5 minutes.

If you don't provide a temperature threshold, it will default to **85°C**.

## Uninstallation

To uninstall the fan control script, you can run the following command:

```bash
curl -sSL https://raw.githubusercontent.com/AksharLeo/HP-Omen-FanControl/main/fan_control_manager.sh -o /tmp/fan_control_manager.sh && sudo bash /tmp/fan_control_manager.sh uninstall && rm -f /tmp/fan_control_manager.sh

```

This will:
1. Remove the fan control script and configuration file.
2. Remove the cron job.
3. Stop the fan control process.

## How It Works

The script monitors the system's temperature (from `/sys/class/thermal/thermal_zone0/temp`), and when the temperature exceeds the defined threshold, it sets the PWM (pulse-width modulation) value for the fan to control its speed.

- **PWM Value 0**: Maximum fan speed (fan runs at full speed).
- **PWM Value 2**: Low fan speed (fan runs at a lower speed).

The temperature threshold can be adjusted by modifying the `/etc/fan_control.conf` configuration file.

## Configuration

To change the temperature threshold or adjust the fan control settings:

1. Open the configuration file:

   ```bash
   sudo nano /etc/fan_control.conf
   ```

2. Modify the `TEMP_THRESHOLD` value in millidegrees Celsius (e.g., 85000 for 85°C).
3. Save the file and restart the script if needed.

## License

This script is licensed under the **GNU General Public License v3.0 (GPLv3)**. Feel free to modify, share, and distribute it under the terms of this license.

## Acknowledgments

Special thanks to the Arch Linux wiki for the helpful information on HP Omen laptops:

- [HP Omen 16-c0140AX on Arch Linux Wiki](https://wiki.archlinux.org/title/HP_Omen_16-c0140AX)

---

If you have any issues or suggestions, feel free to open an issue on the [GitHub repository](https://github.com/AksharLeo/HP-Omen-FanControl).
