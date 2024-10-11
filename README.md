
# System Information Script

## Overview
This bash script provides detailed system information for both macOS and Linux. It detects the OS type and retrieves information such as disk usage, network traffic, CPU usage, and system uptime. The script outputs the information in a nicely formatted, color-coded table directly in the terminal.

## Features
- **Cross-platform**: Works on both macOS and Linux.
- **System Info**: Displays OS version, boot volume, disk usage (total, used, and free), CPU usage (user, system, idle), and uptime.
- **Network Traffic**: Displays network download and upload traffic in MB/s.
- **Formatted Output**: Output is color-coded and centered for better readability.

## Requirements
- macOS or Linux with bash.
- `numfmt` utility (which is available on most Linux systems by default, and on macOS via coreutils).
  
## Installation
1. Clone this repository:
    ```bash
    git clone https://github.com/yourusername/system-info-script.git
    cd my_motd
    ```
   
2. Make the script executable:
    ```bash
    chmod +x my_motd.sh
    ```

3. Run the script:
    ```bash
    ./my_motd.sh
    ```

## Usage
- On macOS, the script will automatically detect the operating system and use macOS-specific commands to gather system information.
- On Linux, the script detects the primary network interface and retrieves system information accordingly.
  
## Configuration
- **Network Interface**: The script uses default network interfaces (`en0` for macOS and `eth0` for Linux). If your system uses a different network interface, modify the `net_int_mac` or `net_int_linux` variables accordingly.
  
## Example Output
```text
OS             Boot Volume     Volume Size     Used   Free   Uptime    Load Avg    CPU User   CPU Sys   CPU Idle   Net Down   Net Up
12.7.6         Macintosh HD    500GB           367GB  133GB  30 days   2.21 2.11  1.94%      5.71%     92.35%     1.54MB/s   0.89MB/s
```

## Contributing
Feel free to open issues or submit pull requests if you find bugs or have suggestions for improvements.

## License
This project is licensed under the MIT License.
