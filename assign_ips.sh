#!/bin/bash

# Default values
DEFAULT_IP_START=1
DEFAULT_IP_END=240

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
    local subnet=$1
    local ip_start=${2:-$IP_START}  # Use global IP_START
    local ip_end=${3:-$IP_END}      # Use global IP_END

    IFS='/' read -ra ADDR <<< "$subnet"
    local ip_parts=($(echo ${ADDR[0]} | awk -F. '{print $1" "$2" "$3" "$4}'))
    local cidr=${ADDR[1]}

    case $cidr in
        24)
            for i in $(seq $ip_start $ip_end); do
                echo "${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.$i"
            done
            ;;
        23)
            for third in $(seq ${ip_parts[2]} $((${ip_parts[2]}+1))); do
                for i in $(seq $ip_start $ip_end); do
                    echo "${ip_parts[0]}.${ip_parts[1]}.$third.$i"
                done
            done
            ;;
        22)
            for third in $(seq ${ip_parts[2]} $((${ip_parts[2]}+3))); do
                for i in $(seq $ip_start $ip_end); do
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

# Parse command-line options
while getopts "s:e:f:n:" opt; do
    case $opt in
        s)
            IP_START=$OPTARG
            ;;
        e)
            IP_END=$OPTARG
            ;;
        f)
            FQDN_FILE=$OPTARG
            ;;
        n)
            SUBNET_FILE=$OPTARG
            ;;
        *)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Use default values if not provided
IP_START=${IP_START:-$DEFAULT_IP_START}
IP_END=${IP_END:-$DEFAULT_IP_END}

# Read FQDNs and subnets from provided files
if [[ -z "$FQDN_FILE" || -z "$SUBNET_FILE" ]]; then
    echo "Both FQDN and subnet files must be provided!"
    exit 1
fi

fqdns=$(cat "$FQDN_FILE")
subnets=$(cat "$SUBNET_FILE")

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
