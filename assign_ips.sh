#!/bin/bash

# DNS-IP-Mapper - Improved Version
# Automatically assigns available IP addresses from specified subnets to FQDNs

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="2.0.0"
readonly DEFAULT_IP_START=1
readonly DEFAULT_IP_END=240
readonly DEFAULT_TIMEOUT=2
readonly DEFAULT_PARALLEL_JOBS=10

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
IP_START=${DEFAULT_IP_START}
IP_END=${DEFAULT_IP_END}
TIMEOUT=${DEFAULT_TIMEOUT}
PARALLEL_JOBS=${DEFAULT_PARALLEL_JOBS}
VERBOSE=false
OUTPUT_FORMAT="csv"
OUTPUT_FILE=""
FQDN_FILE=""
SUBNET_FILE=""

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_verbose() {
    [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[VERBOSE]${NC} $*" >&2
}

# Usage function
show_usage() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - DNS-IP-Mapper

USAGE:
    ${SCRIPT_NAME} -f <fqdn_file> -n <subnet_file> [OPTIONS]

REQUIRED:
    -f <file>       Path to file containing FQDNs
    -n <file>       Path to file containing subnets

OPTIONS:
    -s <num>        Starting IP range (default: ${DEFAULT_IP_START})
    -e <num>        Ending IP range (default: ${DEFAULT_IP_END})
    -t <seconds>    Timeout for network checks (default: ${DEFAULT_TIMEOUT})
    -j <num>        Number of parallel jobs (default: ${DEFAULT_PARALLEL_JOBS})
    -o <file>       Output file (default: stdout)
    -F <format>     Output format: csv, json, table (default: csv)
    -v              Verbose output
    -h              Show this help message

EXAMPLES:
    ${SCRIPT_NAME} -f fqdns.txt -n subnets.txt
    ${SCRIPT_NAME} -f fqdns.txt -n subnets.txt -s 10 -e 100 -v
    ${SCRIPT_NAME} -f fqdns.txt -n subnets.txt -o output.csv -F table

SUPPORTED CIDR:
    /24, /23, /22, /21, /20

EOF
}

# Validation functions
validate_file() {
    local file="$1"
    local description="$2"
    
    if [[ ! -f "$file" ]]; then
        log_error "${description} file '${file}' does not exist"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "${description} file '${file}' is not readable"
        return 1
    fi
    
    if [[ ! -s "$file" ]]; then
        log_error "${description} file '${file}' is empty"
        return 1
    fi
    
    return 0
}

validate_ip_range() {
    if [[ $IP_START -lt 1 || $IP_START -gt 254 ]]; then
        log_error "Invalid start IP range: ${IP_START} (must be 1-254)"
        return 1
    fi
    
    if [[ $IP_END -lt 1 || $IP_END -gt 254 ]]; then
        log_error "Invalid end IP range: ${IP_END} (must be 1-254)"
        return 1
    fi
    
    if [[ $IP_START -gt $IP_END ]]; then
        log_error "Start IP (${IP_START}) cannot be greater than end IP (${IP_END})"
        return 1
    fi
    
    return 0
}

validate_subnet() {
    local subnet="$1"
    
    # Basic CIDR validation
    if [[ ! $subnet =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        log_error "Invalid subnet format: ${subnet}"
        return 1
    fi
    
    local ip_part="${subnet%/*}"
    local cidr_part="${subnet#*/}"
    
    # Validate CIDR
    if [[ $cidr_part -lt 20 || $cidr_part -gt 24 ]]; then
        log_error "Unsupported CIDR: /${cidr_part} (supported: /20-/24)"
        return 1
    fi
    
    return 0
}

# Enhanced FQDN expansion function
expand_fqdn() {
    local input="$1"
    local final_output=""
    
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue  # Skip empty lines and comments
        
        local temp_input="$line"
        temp_input=$(echo "$temp_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # Trim whitespace
        
        # Handle multiple bracket expansions in one line
        while [[ $temp_input =~ \[([0-9]+)-([0-9]+)\] ]]; do
            local prefix="${temp_input%%\[*\]*}"
            local middle="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
            local suffix="${temp_input#*\]}"
            local expanded=""
            
            IFS=- read -r start end <<< "$middle"
            
            # Validate range
            if [[ $start -gt $end ]]; then
                log_warn "Invalid range in FQDN: ${line} (start > end)"
                continue 2
            fi
            
            # Determine padding
            local padding=${#start}
            [[ ${#end} -gt $padding ]] && padding=${#end}
            
            for num in $(seq -w "$start" "$end"); do
                # Apply padding if original had leading zeros
                if [[ ${start:0:1} == "0" && ${#start} -gt 1 ]]; then
                    num=$(printf "%0${padding}d" "$num")
                fi
                expanded+="${prefix}${num}${suffix}\n"
            done
            temp_input="$expanded"
        done
        final_output+="$temp_input"
    done <<< "$input"
    
    echo -e "$final_output" | grep -v '^$'  # Remove empty lines
}

# Enhanced IP generation function
generate_ips() {
    local subnet="$1"
    local ip_start="${2:-$IP_START}"
    local ip_end="${3:-$IP_END}"
    
    IFS='/' read -ra ADDR <<< "$subnet"
    local ip_parts
    IFS='.' read -ra ip_parts <<< "${ADDR[0]}"
    local cidr="${ADDR[1]}"
    
    case $cidr in
        24)
            for i in $(seq "$ip_start" "$ip_end"); do
                echo "${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.$i"
            done
            ;;
        23)
            for third in $(seq "${ip_parts[2]}" $((ip_parts[2] + 1))); do
                for i in $(seq "$ip_start" "$ip_end"); do
                    echo "${ip_parts[0]}.${ip_parts[1]}.$third.$i"
                done
            done
            ;;
        22)
            for third in $(seq "${ip_parts[2]}" $((ip_parts[2] + 3))); do
                for i in $(seq "$ip_start" "$ip_end"); do
                    echo "${ip_parts[0]}.${ip_parts[1]}.$third.$i"
                done
            done
            ;;
        21)
            for third in $(seq "${ip_parts[2]}" $((ip_parts[2] + 7))); do
                for i in $(seq "$ip_start" "$ip_end"); do
                    echo "${ip_parts[0]}.${ip_parts[1]}.$third.$i"
                done
            done
            ;;
        20)
            for third in $(seq "${ip_parts[2]}" $((ip_parts[2] + 15))); do
                for i in $(seq "$ip_start" "$ip_end"); do
                    echo "${ip_parts[0]}.${ip_parts[1]}.$third.$i"
                done
            done
            ;;
        *)
            log_error "CIDR /${cidr} is not supported"
            return 1
            ;;
    esac
}

# Enhanced IP availability check
check_ip_availability() {
    local ip="$1"
    local timeout="${2:-$TIMEOUT}"
    
    log_verbose "Checking availability of IP: ${ip}"
    
    # DNS check - look for both forward and reverse DNS
    if host "$ip" >/dev/null 2>&1; then
        log_verbose "IP ${ip} has DNS record"
        return 1
    fi
    
    # Ping check with timeout
    if ping -c 1 -W "$timeout" "$ip" >/dev/null 2>&1; then
        log_verbose "IP ${ip} responds to ping"
        return 1
    fi
    
    # Additional check: ARP table (if available)
    if command -v arp >/dev/null 2>&1; then
        if arp -n "$ip" 2>/dev/null | grep -q "ether"; then
            log_verbose "IP ${ip} found in ARP table"
            return 1
        fi
    fi
    
    log_verbose "IP ${ip} is available"
    return 0
}

# Output formatting functions
output_csv() {
    local fqdn="$1"
    local ip="$2"
    echo "${fqdn},${ip}"
}

output_json() {
    local fqdn="$1"
    local ip="$2"
    echo "{\"fqdn\":\"${fqdn}\",\"ip\":\"${ip}\"}"
}

output_table() {
    local fqdn="$1"
    local ip="$2"
    printf "%-40s | %-15s\n" "$fqdn" "$ip"
}

# Progress tracking
show_progress() {
    local current="$1"
    local total="$2"
    local percent=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percent * bar_length / 100))
    
    printf "\r["
    printf "%*s" $filled_length | tr ' ' '='
    printf "%*s" $((bar_length - filled_length)) | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percent $current $total
}

# Main assignment function
assign_ips() {
    local fqdns_content subnets_content
    
    # Read and validate input files
    fqdns_content=$(cat "$FQDN_FILE")
    subnets_content=$(cat "$SUBNET_FILE")
    
    # Expand FQDNs and remove duplicates
    log_info "Expanding FQDNs..."
    local expanded_fqdns
    expanded_fqdns=$(expand_fqdn "$fqdns_content")
    local unique_fqdns
    unique_fqdns=$(echo "$expanded_fqdns" | sort -u | grep -v '^$')
    
    local fqdn_count
    fqdn_count=$(echo "$unique_fqdns" | wc -l)
    log_info "Found ${fqdn_count} unique FQDNs to process"
    
    # Validate subnets
    log_info "Validating subnets..."
    while IFS= read -r subnet; do
        [[ -z "$subnet" || "$subnet" =~ ^[[:space:]]*# ]] && continue
        subnet=$(echo "$subnet" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        validate_subnet "$subnet" || exit 1
    done <<< "$subnets_content"
    
    # Initialize tracking arrays
    declare -A used_ips
    declare -A assigned_fqdns
    local assignments=()
    local current_fqdn=0
    
    # Output header for table format
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        printf "%-40s | %-15s\n" "FQDN" "IP Address"
        printf "%s\n" "$(printf '%.0s-' {1..58})"
    fi
    
    # Process each FQDN
    while IFS= read -r fqdn; do
        [[ -z "$fqdn" ]] && continue
        ((current_fqdn++))
        
        [[ "$VERBOSE" != true ]] && show_progress $current_fqdn $fqdn_count
        
        # Skip if already assigned
        [[ "${assigned_fqdns[$fqdn]:-}" == "1" ]] && continue
        
        log_verbose "Processing FQDN: ${fqdn}"
        
        local assigned=false
        
        # Try each subnet
        while IFS= read -r subnet && [[ "$assigned" == false ]]; do
            [[ -z "$subnet" || "$subnet" =~ ^[[:space:]]*# ]] && continue
            subnet=$(echo "$subnet" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            log_verbose "Trying subnet: ${subnet}"
            
            # Generate IPs for this subnet
            local ip_list
            ip_list=$(generate_ips "$subnet")
            
            # Check each IP in parallel batches
            local batch_count=0
            local batch_ips=()
            
            while IFS= read -r ip && [[ "$assigned" == false ]]; do
                [[ -z "${used_ips[$ip]:-}" ]] || continue
                
                batch_ips+=("$ip")
                ((batch_count++))
                
                # Process batch when full or at end
                if [[ $batch_count -ge $PARALLEL_JOBS ]] || [[ $(echo "$ip_list" | tail -1) == "$ip" ]]; then
                    local pids=()
                    local available_ip=""
                    
                    # Start parallel checks
                    for batch_ip in "${batch_ips[@]}"; do
                        (
                            if check_ip_availability "$batch_ip" "$TIMEOUT"; then
                                echo "$batch_ip"
                            fi
                        ) &
                        pids+=($!)
                    done
                    
                    # Wait for first available IP
                    for pid in "${pids[@]}"; do
                        if wait "$pid"; then
                            available_ip=$(jobs -p | head -1 | xargs ps -o args= -p 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
                            break
                        fi
                    done
                    
                    # Kill remaining jobs
                    for pid in "${pids[@]}"; do
                        kill "$pid" 2>/dev/null || true
                    done
                    wait 2>/dev/null || true
                    
                    # If we found an available IP, assign it
                    if [[ -n "$available_ip" ]] && check_ip_availability "$available_ip" "$TIMEOUT"; then
                        used_ips[$available_ip]=1
                        assigned_fqdns[$fqdn]=1
                        assigned=true
                        
                        # Output the assignment
                        local output
                        case "$OUTPUT_FORMAT" in
                            csv) output=$(output_csv "$fqdn" "$available_ip") ;;
                            json) output=$(output_json "$fqdn" "$available_ip") ;;
                            table) output=$(output_table "$fqdn" "$available_ip") ;;
                        esac
                        
                        if [[ -n "$OUTPUT_FILE" ]]; then
                            echo "$output" >> "$OUTPUT_FILE"
                        else
                            [[ "$VERBOSE" != true ]] && echo  # Clear progress line
                            echo "$output"
                        fi
                        
                        log_verbose "Assigned ${available_ip} to ${fqdn}"
                        break
                    fi
                    
                    # Reset batch
                    batch_ips=()
                    batch_count=0
                fi
            done <<< "$ip_list"
        done <<< "$subnets_content"
        
        if [[ "$assigned" == false ]]; then
            log_warn "Could not assign IP to: ${fqdn}"
        fi
    done <<< "$unique_fqdns"
    
    [[ "$VERBOSE" != true ]] && echo  # Clear progress line
    log_success "IP assignment completed"
}

# Parse command line arguments
parse_arguments() {
    while getopts "f:n:s:e:t:j:o:F:vh" opt; do
        case $opt in
            f) FQDN_FILE="$OPTARG" ;;
            n) SUBNET_FILE="$OPTARG" ;;
            s) IP_START="$OPTARG" ;;
            e) IP_END="$OPTARG" ;;
            t) TIMEOUT="$OPTARG" ;;
            j) PARALLEL_JOBS="$OPTARG" ;;
            o) OUTPUT_FILE="$OPTARG" ;;
            F) OUTPUT_FORMAT="$OPTARG" ;;
            v) VERBOSE=true ;;
            h) show_usage; exit 0 ;;
            *) log_error "Invalid option: -$OPTARG"; show_usage; exit 1 ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$FQDN_FILE" || -z "$SUBNET_FILE" ]]; then
        log_error "Both FQDN file (-f) and subnet file (-n) are required"
        show_usage
        exit 1
    fi
    
    # Validate output format
    case "$OUTPUT_FORMAT" in
        csv|json|table) ;;
        *) log_error "Invalid output format: $OUTPUT_FORMAT (supported: csv, json, table)"; exit 1 ;;
    esac
}

# Main function
main() {
    log_info "Starting ${SCRIPT_NAME} v${VERSION}"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate inputs
    validate_file "$FQDN_FILE" "FQDN" || exit 1
    validate_file "$SUBNET_FILE" "Subnet" || exit 1
    validate_ip_range || exit 1
    
    # Create output file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        : > "$OUTPUT_FILE"  # Create/truncate file
        log_info "Output will be written to: ${OUTPUT_FILE}"
    fi
    
    # Run the assignment
    assign_ips
    
    log_info "Process completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi