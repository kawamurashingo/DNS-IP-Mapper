#!/bin/bash

# DNS utility functions for DNS-IP-Mapper

# Enhanced DNS lookup with multiple record types
dns_lookup() {
    local target="$1"
    local record_type="${2:-A}"
    local timeout="${3:-5}"
    
    timeout "$timeout" host -t "$record_type" "$target" 2>/dev/null
}

# Check if hostname has DNS record
has_dns_record() {
    local hostname="$1"
    local timeout="${2:-5}"
    
    # Check A record
    if dns_lookup "$hostname" "A" "$timeout" >/dev/null; then
        return 0
    fi
    
    # Check AAAA record
    if dns_lookup "$hostname" "AAAA" "$timeout" >/dev/null; then
        return 0
    fi
    
    # Check CNAME record
    if dns_lookup "$hostname" "CNAME" "$timeout" >/dev/null; then
        return 0
    fi
    
    return 1
}

# Reverse DNS lookup
reverse_dns_lookup() {
    local ip="$1"
    local timeout="${2:-5}"
    
    timeout "$timeout" host "$ip" 2>/dev/null | grep -v "not found"
}

# Check if IP has reverse DNS
has_reverse_dns() {
    local ip="$1"
    local timeout="${2:-5}"
    
    reverse_dns_lookup "$ip" "$timeout" >/dev/null
}

# Validate FQDN format
validate_fqdn() {
    local fqdn="$1"
    
    # Basic FQDN validation regex
    local regex='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    
    if [[ ! $fqdn =~ $regex ]]; then
        return 1
    fi
    
    # Check length (max 253 characters)
    if [[ ${#fqdn} -gt 253 ]]; then
        return 1
    fi
    
    # Check each label length (max 63 characters)
    IFS='.' read -ra labels <<< "$fqdn"
    for label in "${labels[@]}"; do
        if [[ ${#label} -gt 63 ]]; then
            return 1
        fi
    done
    
    return 0
}

# Get all DNS records for a hostname
get_all_dns_records() {
    local hostname="$1"
    local timeout="${2:-5}"
    
    echo "=== DNS Records for $hostname ==="
    
    for record_type in A AAAA CNAME MX TXT NS SOA; do
        echo "--- $record_type Records ---"
        if ! dns_lookup "$hostname" "$record_type" "$timeout"; then
            echo "No $record_type records found"
        fi
        echo
    done
}

# Check DNS propagation across multiple servers
check_dns_propagation() {
    local hostname="$1"
    local dns_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222" "9.9.9.9")
    
    echo "=== DNS Propagation Check for $hostname ==="
    
    for server in "${dns_servers[@]}"; do
        echo "Checking against $server:"
        if timeout 5 nslookup "$hostname" "$server" >/dev/null 2>&1; then
            echo "  ✓ Resolved"
        else
            echo "  ✗ Not resolved"
        fi
    done
}