#!/bin/bash

# User and system information variables
my_user="$(whoami)"
which_os="1"  # 1 for macOS, 2 for Linux
os_ver=""
net_int_mac="en0"  # Default network interface for macOS
net_int_linux="eth0"  # Default network interface for Linux

# Function to detect the operating system (macOS or Linux)
find_os() {
    case "$(uname)" in
        Darwin)
            which_os="1"
            os_ver="$(sw_vers -productVersion)"  # Get macOS version
            ;;
        Linux)
            which_os="2"
            os_ver="$(uname -r)"  # Get Linux kernel version
            ;;
        *)
            echo "Unsupported OS"
            exit 1
            ;;
    esac
}

# Function to convert bytes to MB/s using numfmt for a human-readable format
convert_to_mbps() {
    if [[ -z "$1" || "$1" -eq 0 ]]; then
        echo "N/A"
    else
        numfmt --to=iec --suffix=B --format="%.2f" "$1"
    fi
}

# macOS-specific function to get disk information
mac_disk_info() {
    # Store the entire diskutil info output into a variable
    disk_info=$(diskutil info /)

    # Get startup disk name and size information
    startup_name="$(osascript -e 'tell app "Finder" to get name of startup disk' 2>/dev/null || echo 'N/A')"
    startup_size=$(printf "%s\n" "$disk_info" | grep "Container Total Space:" | awk '{print $4, $5}' || echo 'N/A')
    startup_free=$(printf "%s\n" "$disk_info" | grep "Container Free Space:" | awk '{print $4, $5}' || echo 'N/A')

    # Extract numeric values and remove 'B' suffix for processing
    size_value=$(echo "$startup_size" | awk '{gsub("B", "", $2); print $1}')
    size_unit=$(echo "$startup_size" | awk '{gsub("B", "", $2); print $2}')
    
    free_value=$(echo "$startup_free" | awk '{gsub("B", "", $2); print $1}')
    free_unit=$(echo "$startup_free" | awk '{gsub("B", "", $2); print $2}')

    # Convert sizes to bytes for calculation
    size_in_bytes=$(numfmt --from=iec "$size_value$size_unit")
    free_in_bytes=$(numfmt --from=iec "$free_value$free_unit")

    # Calculate used space in bytes and convert it to a human-readable format
    used_in_bytes=$((size_in_bytes - free_in_bytes))
    startup_used=$(numfmt --to=iec --suffix=B "$used_in_bytes")
}

# macOS-specific function to get network information
mac_get_network() {
    ifconfig_output="$(ifconfig "$net_int_mac" 2>/dev/null || echo 'N/A')"
    
    if [[ "$ifconfig_output" == "N/A" ]]; then
        network_down="N/A"
        network_up="N/A"
    else
        # Get network data (bytes sent/received) for the given network interface
        network_down="$(netstat -ib | grep "$net_int_mac" | awk '{print $7}' | head -n 1 2>/dev/null || echo 'N/A')"
        network_up="$(netstat -ib | grep "$net_int_mac" | awk '{print $10}' | head -n 1 2>/dev/null || echo 'N/A')"
        
        # Convert the byte counts to MB/s
        network_down=$(convert_to_mbps "$network_down")
        network_up=$(convert_to_mbps "$network_up")
    fi
}

# macOS-specific function to get CPU usage
mac_get_cpu() {
    cpu_used_user="$(top -l 1 | grep "CPU usage" | awk '{print $3}' 2>/dev/null || echo 'N/A')"
    cpu_used_sys="$(top -l 1 | grep "CPU usage" | awk '{print $5}' 2>/dev/null || echo 'N/A')"
    cpu_used_idle="$(top -l 1 | grep "CPU usage" | awk '{print $7}' 2>/dev/null || echo 'N/A')"
}

# macOS-specific function to get uptime information
mac_get_uptime() {
    uptime_time="$(uptime | awk -F', ' '{print $1}' | sed 's/.*up //' 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime | awk '{print $10, $11, $12}' 2>/dev/null || echo 'N/A')"
}

# Linux-specific function to get disk information
linux_disk_info() {
    startup_name="/"
    startup_size="$(df -h / | awk 'NR==2 {print $2}' 2>/dev/null || echo 'N/A')"
    startup_used="$(df -h / | awk 'NR==2 {print $3}' 2>/dev/null || echo 'N/A')"
    startup_free="$(df -h / | awk 'NR==2 {print $4}' 2>/dev/null || echo 'N/A')"
}

# Linux-specific function to get network information
linux_get_network() {
    network_down="$(cat /proc/net/dev | grep "$net_int_linux" | awk '{print $2}' 2>/dev/null || echo 'N/A')"
    network_up="$(cat /proc/net/dev | grep "$net_int_linux" | awk '{print $10}' 2>/dev/null || echo 'N/A')"
    
    # Convert the byte counts to MB/s
    network_down=$(convert_to_mbps "$network_down")
    network_up=$(convert_to_mbps "$network_up")
}

# Linux-specific function to get CPU usage
linux_get_cpu() {
    cpu_stat=$(grep 'cpu ' /proc/stat)

    # Parse CPU usage from /proc/stat
    cpu_user=$(echo "$cpu_stat" | awk '{print $2}')
    cpu_sys=$(echo "$cpu_stat" | awk '{print $4}')
    cpu_idle=$(echo "$cpu_stat" | awk '{print $5}')

    total=$((cpu_user + cpu_sys + cpu_idle))
    
    if [[ $total -ne 0 ]]; then
        cpu_used_user=$((100 * cpu_user / total))
        cpu_used_sys=$((100 * cpu_sys / total))
        cpu_used_idle=$((100 * cpu_idle / total))
    else
        cpu_used_user="N/A"
        cpu_used_sys="N/A"
        cpu_used_idle="N/A"
    fi
}

# Linux-specific function to get uptime information
linux_get_uptime() {
    uptime_time="$(uptime -p 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime | awk -F'load average: ' '{print $2}' 2>/dev/null || echo 'N/A')"
}

# Function to detect the primary network interface for Linux
detect_primary_interface() {
    net_int_linux=$(ip route | grep '^default' | awk '{print $5}' 2>/dev/null || echo "eth0")
}

# Function to add colors and format the text output
add_colours() {
    colour_blue="\033[36m"
    colour_yellow="\033[33m"
    colour_reset="\033[0m"

    # Print the system information with formatted columns
    echo -e "${colour_yellow}OS *&* Boot Volume *&* Volume Size *&* Used *&* Free *&* Uptime *&* Load Avg *&* CPU User *&* CPU Sys *&* CPU Idle *&* Net Down *&* Net Up${colour_reset}"

    echo -e "${colour_blue}${os_ver} *&* ${startup_name} *&* ${startup_size} *&* ${startup_used} *&* ${startup_free} *&* ${uptime_time} *&* ${uptime_load} *&* ${cpu_used_user}% *&* ${cpu_used_sys}% *&* ${cpu_used_idle}% *&* ${network_down} *&* ${network_up}${colour_reset}"
}

# Function to print information to the terminal, centered
print_terminal() {
    display_center() {
        columns="$(tput cols)"
        while IFS= read -r line; do
            printf "%*s\n" $(( (${#line} + columns) / 2)) "$line"
        done
    }

    # Format and display information
    add_colours | column -s "*&*" -t | display_center
}

# Main function to collect system information and print it
main() {
    find_os

    if [[ $which_os -eq 1 ]]; then
        mac_disk_info
        mac_get_network
        mac_get_cpu
        mac_get_uptime
    else
        detect_primary_interface  # Detect primary network interface for Linux
        linux_disk_info
        linux_get_network
        linux_get_cpu
        linux_get_uptime
    fi

    print_terminal
}

# Run the main function
main
