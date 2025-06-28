#!/bin/bash

# IP utility functions for DNS-IP-Mapper

# Validate IP address format
validate_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $regex ]]; then
        return 1
    fi
    
    # Check each octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ $octet -lt 0 || $octet -gt 255 ]]; then
            return 1
        fi
        # Check for leading zeros (except for "0")
        if [[ ${#octet} -gt 1 && ${octet:0:1} == "0" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Calculate network address from IP and CIDR
get_network_address() {
    local ip="$1"
    local cidr="$2"
    
    # Convert IP to integer
    IFS='.' read -ra octets <<< "$ip"
    local ip_int=$(( (octets[0] << 24) + (octets[1] << 16) + (octets[2] << 8) + octets[3] ))
    
    # Calculate network mask
    local mask=$(( 0xFFFFFFFF << (32 - cidr) ))
    
    # Calculate network address
    local network_int=$(( ip_int & mask ))
    
    # Convert back to dotted decimal
    local net_a=$(( (network_int >> 24) & 0xFF ))
    local net_b=$(( (network_int >> 16) & 0xFF ))
    local net_c=$(( (network_int >> 8) & 0xFF ))
    local net_d=$(( network_int & 0xFF ))
    
    echo "${net_a}.${net_b}.${net_c}.${net_d}"
}

# Check if IP is in subnet
ip_in_subnet() {
    local ip="$1"
    local subnet="$2"
    
    IFS='/' read -ra subnet_parts <<< "$subnet"
    local subnet_ip="${subnet_parts[0]}"
    local cidr="${subnet_parts[1]}"
    
    local ip_network
    local subnet_network
    
    ip_network=$(get_network_address "$ip" "$cidr")
    subnet_network=$(get_network_address "$subnet_ip" "$cidr")
    
    [[ "$ip_network" == "$subnet_network" ]]
}

# Generate IP range for subnet
generate_ip_range() {
    local subnet="$1"
    local start_host="${2:-1}"
    local end_host="${3:-254}"
    
    IFS='/' read -ra subnet_parts <<< "$subnet"
    local subnet_ip="${subnet_parts[0]}"
    local cidr="${subnet_parts[1]}"
    
    # Calculate number of host bits
    local host_bits=$((32 - cidr))
    local max_hosts=$(( (1 << host_bits) - 2 ))  # Subtract network and broadcast
    
    # Adjust end_host if it exceeds maximum
    [[ $end_host -gt $max_hosts ]] && end_host=$max_hosts
    
    # Generate IPs
    local network_addr
    network_addr=$(get_network_address "$subnet_ip" "$cidr")
    
    IFS='.' read -ra net_octets <<< "$network_addr"
    local base_int=$(( (net_octets[0] << 24) + (net_octets[1] << 16) + (net_octets[2] << 8) + net_octets[3] ))
    
    for ((i = start_host; i <= end_host; i++)); do
        local ip_int=$((base_int + i))
        local a=$(( (ip_int >> 24) & 0xFF ))
        local b=$(( (ip_int >> 16) & 0xFF ))
        local c=$(( (ip_int >> 8) & 0xFF ))
        local d=$(( ip_int & 0xFF ))
        echo "${a}.${b}.${c}.${d}"
    done
}

# Get subnet information
get_subnet_info() {
    local subnet="$1"
    
    IFS='/' read -ra subnet_parts <<< "$subnet"
    local subnet_ip="${subnet_parts[0]}"
    local cidr="${subnet_parts[1]}"
    
    local host_bits=$((32 - cidr))
    local total_addresses=$((1 << host_bits))
    local usable_addresses=$((total_addresses - 2))
    
    local network_addr broadcast_addr
    network_addr=$(get_network_address "$subnet_ip" "$cidr")
    
    # Calculate broadcast address
    local net_int
    IFS='.' read -ra octets <<< "$network_addr"
    net_int=$(( (octets[0] << 24) + (octets[1] << 16) + (octets[2] << 8) + octets[3] ))
    local broadcast_int=$((net_int + total_addresses - 1))
    
    local ba=$(( (broadcast_int >> 24) & 0xFF ))
    local bb=$(( (broadcast_int >> 16) & 0xFF ))
    local bc=$(( (broadcast_int >> 8) & 0xFF ))
    local bd=$(( broadcast_int & 0xFF ))
    broadcast_addr="${ba}.${bb}.${bc}.${bd}"
    
    cat << EOF
Subnet: $subnet
Network Address: $network_addr
Broadcast Address: $broadcast_addr
Total Addresses: $total_addresses
Usable Addresses: $usable_addresses
Host Bits: $host_bits
EOF
}