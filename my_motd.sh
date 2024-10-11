#!/bin/bash

my_user="$(whoami)"
which_os="1"
os_ver=""
net_int="en0"  # Default network interface for macOS, can be manually changed

# Determine OS type
find_os() {
    case "$(uname)" in
        Darwin)
            which_os="1"
            os_ver="$(sw_vers -productVersion)"  # Set macOS version
            ;;
        Linux)
            which_os="2"
            os_ver="$(uname -r)"  # Set Linux version
            ;;
        *)
            echo "Unsupported OS"
            exit 1
            ;;
    esac
}

convert_to_mbps() {
    if [[ -z "$1" || "$1" -eq 0 ]]; then
        echo "N/A"
    else
        # Use numfmt to format the large byte counts into human-readable MB/s
        numfmt --to=iec --suffix=B --format="%.2f" $1
    fi
}



mac_disk_info() {
    # Store the entire diskutil info output into a variable (preserving newlines)
    disk_info=$(diskutil info /)

    # Process the stored output
    startup_name="$(osascript -e 'tell app "Finder" to get name of startup disk' 2>/dev/null || echo 'N/A')"
    startup_size=$(printf "%s\n" "$disk_info" | grep "Container Total Space:" | awk '{print $4, $5}' || echo 'N/A')
    startup_free=$(printf "%s\n" "$disk_info" | grep "Container Free Space:" | awk '{print $4, $5}' || echo 'N/A')

    # Extract numeric values and units (removing the 'B' suffix)
    size_value=$(echo "$startup_size" | awk '{gsub("B", "", $2); print $1}')
    size_unit=$(echo "$startup_size" | awk '{gsub("B", "", $2); print $2}')
    
    free_value=$(echo "$startup_free" | awk '{gsub("B", "", $2); print $1}')
    free_unit=$(echo "$startup_free" | awk '{gsub("B", "", $2); print $2}')

    # Convert the sizes into bytes using numfmt
    size_in_bytes=$(numfmt --from=iec "$size_value$size_unit")
    free_in_bytes=$(numfmt --from=iec "$free_value$free_unit")

    # Calculate the used space in bytes
    used_in_bytes=$((size_in_bytes - free_in_bytes))

    # Convert the used space back to a human-readable format
    startup_used=$(numfmt --to=iec --suffix=B "$used_in_bytes")

}





mac_get_network() {
    ifconfig_output="$(ifconfig "$net_int" 2>/dev/null || echo 'N/A')"
    
    # Check if the network interface exists
    if [[ "$ifconfig_output" == "N/A" ]]; then
        network_down="N/A"
        network_up="N/A"
    else
        # Get network data in bytes, convert them using numfmt
        network_down="$(netstat -ib | grep "$net_int" | awk '{print $7}' 2>/dev/null || echo 'N/A')"
        network_up="$(netstat -ib | grep "$net_int" | awk '{print $10}' 2>/dev/null || echo 'N/A')"
        
        # Use numfmt to convert large byte counts to readable MB/s
        network_down=$(convert_to_mbps "$network_down")
        network_up=$(convert_to_mbps "$network_up")
    fi
}


mac_get_cpu() {
    cpu_used_user="$(top -l 1 | grep "CPU usage" | awk '{print $3}' 2>/dev/null || echo 'N/A')"
    cpu_used_sys="$(top -l 1 | grep "CPU usage" | awk '{print $5}' 2>/dev/null || echo 'N/A')"
    cpu_used_idle="$(top -l 1 | grep "CPU usage" | awk '{print $7}' 2>/dev/null || echo 'N/A')"
}

mac_get_uptime() {
    uptime_time="$(uptime | awk -F', ' '{print $1}' | sed 's/.*up //' 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime | awk '{print $10, $11, $12}' 2>/dev/null || echo 'N/A')"
}

# Get Linux-specific info
linux_sys_info() {
    startup_name="/"
    startup_size="$(df -h / | awk 'NR==2 {print $2}' 2>/dev/null || echo 'N/A')"
    startup_used="$(df -h / | awk 'NR==2 {print $3}' 2>/dev/null || echo 'N/A')"
    startup_free="$(df -h / | awk 'NR==2 {print $4}' 2>/dev/null || echo 'N/A')"
}

linux_get_network() {
    network_down="$(cat /proc/net/dev | grep "$net_int" | awk '{print $2}' 2>/dev/null || echo 'N/A')"
    network_up="$(cat /proc/net/dev | grep "$net_int" | awk '{print $10}' 2>/dev/null || echo 'N/A')"
    network_down=$(convert_to_mbps "$network_down")
    network_up=$(convert_to_mbps "$network_up")
}

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

linux_get_uptime() {
    uptime_time="$(uptime -p 2>/dev/null || echo 'N/A')"
    uptime_load="$(uptime | awk -F'load average: ' '{print $2}' 2>/dev/null || echo 'N/A')"
}

# Add colors and format text
add_colours() {
    colour_blue="\033[36m"
    colour_yellow="\033[33m"
    colour_reset="\033[0m"

    echo -e "${colour_yellow}OS *&* Boot Volume *&* Volume Size *&* Used *&* Free *&* Uptime *&* Load Avg *&* CPU User *&* CPU Sys *&* CPU Idle *&* Net Down *&* Net Up${colour_reset}"

    # Display Mac or Linux based on detected OS
    echo -e "${colour_blue}${os_ver} *&* ${startup_name} *&* ${startup_size} *&* ${startup_used} *&* ${startup_free} *&* ${uptime_time} *&* ${uptime_load} *&* ${cpu_used_user}% *&* ${cpu_used_sys}% *&* ${cpu_used_idle}% *&* ${network_down} *&* ${network_up}${colour_reset}"
}

# Print information to terminal (centered)
print_terminal() {
    display_center() {
        columns="$(tput cols)"
        while IFS= read -r line; do
            printf "%*s\n" $(( (${#line} + columns) / 2)) "$line"
        done
    }

    add_colours | column -s "*&*" -t | display_center
}

# Main function to call the necessary commands
main() {
    find_os

    if [[ $which_os -eq 1 ]]; then
        mac_disk_info
       # mac_get_network
        mac_get_cpu
        mac_get_uptime
    else
        detect_primary_interface  # Detect primary interface
        linux_sys_info
        linux_get_network
        linux_get_cpu
        linux_get_uptime
    fi

    print_terminal
}

# Run the main function
main
