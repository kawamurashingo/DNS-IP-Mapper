#!/bin/bash

# Check if required commands are available
for cmd in host ping; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' command is not found. Please install it before running this script."
        exit 1
    fi
done

# Function to expand fqdn
expand_fqdn() {
    local input="$1"
    local final_output=""
    # Handle multi-line input
    while IFS= read -r line; do
        local temp_input="$line"
        while [[ $temp_input =~ \[([0-9]+)-([0-9]+)\] ]]; do
            local prefix="${temp_input%%\[*\]*}"
            local middle="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
            local suffix="${temp_input#*\]}"
            local expanded=""
            IFS=- read start end <<< "$middle"
            for num in $(seq -w $start $end); do
                expanded+="${prefix}${num}${suffix}\n"
            done
            temp_input=$expanded
        done
        final_output+="$temp_input"
    done <<< "$input"
    echo -e "$final_output"
}


# Function to generate IPs for given subnet
generate_ips() {
    local subnet=$1
#    echo "Debug: Processing subnet: $subnet" >&2  # ????????????
    IFS='/' read -ra ADDR <<< "$subnet"
    local ip_parts=($(echo ${ADDR[0]} | awk -F. '{print $1" "$2" "$3" "$4}'))
    local cidr=${ADDR[1]}
    local ip_end=240 # ip range 1-240 
    case $cidr in
        24)
            for i in $(seq 1 $ip_end); do
                echo "${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.$i"
            done
            ;;
        23)
            for third in $(seq ${ip_parts[2]} $((${ip_parts[2]}+1))); do
                for i in $(seq 1 $ip_end); do
                    echo "${ip_parts[0]}.${ip_parts[1]}.$third.$i"
                done
            done
            ;;
        22)
            for third in $(seq ${ip_parts[2]} $((${ip_parts[2]}+3))); do
                for i in $(seq 1 $ip_end); do
                    echo "${ip_parts[0]}.${ip_parts[1]}.$third.$i"
                done
            done
            ;;
        
        # CIDR 21 20 ...
        #

        *)
            echo "CIDR $cidr is not currently supported."
            ;;
    esac
}

# Validate input fqdns format
if [[ ! "$fqdns" =~ ^[a-zA-Z0-9\.-\[\]]+$ ]]; then
    echo "Error: Invalid fqdns format."
    exit 1
fi

# Validate input subnets format
if [[ ! "$subnets" =~ ^[0-9\.\/]+$ ]]; then
    echo "Error: Invalid subnets format."
    exit 1
fi

# Expand and remove duplicate FQDNs
expanded_fqdns=$(expand_fqdn "$fqdns")
fqdns=$(echo "$expanded_fqdns" | sort -u | sed '/^$/d')

# Remove leading and trailing whitespaces and any unwanted newlines
subnets=$(echo "$subnets" | sed 's/^[ \t]*//;s/[ \t]*$//;/^$/d')

# Array to store used IP addresses
declare -A used_ips
declare -A assigned_fqdns

# Find unused IP addresses and assign to FQDNs
while IFS= read -r fqdn; do

    # Skip this fqdn if already assigned
    [ "${assigned_fqdns[$fqdn]}" == "1" ] && continue
    while IFS= read -r subnet; do
        while IFS= read -r ip; do
            if [ -z "${used_ips[$ip]}" ]; then

                # Background process to check DNS and ping
                ( ! host $ip > /dev/null 2>&1 && ! ping -c 1 -W 1 $ip > /dev/null 2>&1 ) &

                # Wait for background process
                wait $!

                # If the background process was successful
                if [ $? -eq 0 ]; then
                    echo "$fqdn,$ip"
                    used_ips[$ip]=1       # Mark this IP address as used
                    assigned_fqdns[$fqdn]=1 # Mark this FQDN as assigned
                    break
                fi
            fi
        done < <(generate_ips "$subnet")

        # If the fqdn has been assigned an IP, break out of the subnet loop
        [ "${assigned_fqdns[$fqdn]}" == "1" ] && break
    done <<< "$subnets"
done <<< "$fqdns"
