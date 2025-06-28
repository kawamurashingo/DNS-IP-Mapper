# DNS-IP-Mapper v2.0

DNS-IP-Mapper is an enhanced tool designed to automatically assign available IP addresses from specified subnets to a list of FQDNs (Fully Qualified Domain Names).

## ✨ New Features in v2.0

- **Enhanced Error Handling**: Comprehensive validation and error reporting
- **Multiple Output Formats**: CSV, JSON, and table formats
- **Parallel Processing**: Configurable parallel IP checking for better performance
- **Progress Tracking**: Visual progress indicators during processing
- **Verbose Logging**: Detailed logging with color-coded output
- **Extended CIDR Support**: Now supports /20, /21, /22, /23, and /24 networks
- **Configuration Files**: Centralized configuration management
- **Test Suite**: Comprehensive testing framework
- **Utility Functions**: Modular IP and DNS utility functions
- **Better FQDN Expansion**: Improved range expansion with padding support
- **Output to File**: Option to save results to a file

## 🚀 Quick Start

### Basic Usage

```bash
./assign_ips.sh -f fqdns.txt -n subnets.txt
```

### Advanced Usage

```bash
# With custom IP range and parallel processing
./assign_ips.sh -f fqdns.txt -n subnets.txt -s 10 -e 100 -j 20 -v

# Output to file in JSON format
./assign_ips.sh -f fqdns.txt -n subnets.txt -o results.json -F json

# Table format with verbose output
./assign_ips.sh -f fqdns.txt -n subnets.txt -F table -v
```

## 📋 Prerequisites

- Bash (version 4 or higher)
- `host` command (bind-utils package)
- `ping` command
- `timeout` command (coreutils)

## 🔧 Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd dns-ip-mapper
```

2. Make the script executable:
```bash
chmod +x assign_ips.sh
```

3. Run the test suite:
```bash
./tests/test_assign_ips.sh
```

## 📖 Usage

### Command Line Options

```
assign_ips.sh v2.0.0 - DNS-IP-Mapper

USAGE:
    assign_ips.sh -f <fqdn_file> -n <subnet_file> [OPTIONS]

REQUIRED:
    -f <file>       Path to file containing FQDNs
    -n <file>       Path to file containing subnets

OPTIONS:
    -s <num>        Starting IP range (default: 1)
    -e <num>        Ending IP range (default: 240)
    -t <seconds>    Timeout for network checks (default: 2)
    -j <num>        Number of parallel jobs (default: 10)
    -o <file>       Output file (default: stdout)
    -F <format>     Output format: csv, json, table (default: csv)
    -v              Verbose output
    -h              Show help message
```

### Input File Formats

#### FQDN File (`fqdns.txt`)
```
# Database servers
db01.example.com
db02.example.com

# Web servers with range expansion
web0[1-5].example.com

# Application servers
app[10-15].example.com
```

#### Subnet File (`subnets.txt`)
```
# Production network
192.168.1.0/24

# Development network
192.168.2.0/24

# Staging network
10.0.1.0/23
```

### Output Formats

#### CSV Format (default)
```
db01.example.com,192.168.1.10
web01.example.com,192.168.1.11
```

#### JSON Format
```json
{"fqdn":"db01.example.com","ip":"192.168.1.10"}
{"fqdn":"web01.example.com","ip":"192.168.1.11"}
```

#### Table Format
```
FQDN                                     | IP Address     
----------------------------------------------------------
db01.example.com                         | 192.168.1.10   
web01.example.com                        | 192.168.1.11   
```

## 🔍 How It Works

### IP Availability Checks

The script determines IP availability using multiple checks:

1. **DNS Check**: Verifies no existing DNS record (forward lookup)
2. **Ping Check**: Confirms the IP doesn't respond to ping
3. **ARP Check**: Checks local ARP table (if available)

An IP is considered available only if **all** checks indicate it's unused.

### FQDN Expansion

The script supports range expansion in FQDNs:
- `web[1-5].example.com` expands to `web1.example.com`, `web2.example.com`, etc.
- `server[01-10].example.com` maintains zero-padding: `server01.example.com`, `server02.example.com`, etc.

### Supported Networks

- `/24` - 254 usable addresses
- `/23` - 510 usable addresses  
- `/22` - 1022 usable addresses
- `/21` - 2046 usable addresses
- `/20` - 4094 usable addresses

## 🧪 Testing

Run the comprehensive test suite:

```bash
./tests/test_assign_ips.sh
```

The test suite validates:
- Command line argument parsing
- File validation
- Error handling
- Output format generation
- Basic functionality

## 🛠 Utilities

### IP Utilities (`utils/ip_utils.sh`)
- IP address validation
- Network calculations
- Subnet information
- IP range generation

### DNS Utilities (`utils/dns_utils.sh`)
- DNS record lookups
- FQDN validation
- Reverse DNS checks
- DNS propagation testing

## 📁 Project Structure

```
dns-ip-mapper/
├── assign_ips.sh          # Main script
├── config/
│   └── default.conf       # Default configuration
├── examples/
│   ├── fqdns.txt         # Example FQDN file
│   └── subnets.txt       # Example subnet file
├── tests/
│   └── test_assign_ips.sh # Test suite
├── utils/
│   ├── ip_utils.sh       # IP utility functions
│   └── dns_utils.sh      # DNS utility functions
├── LICENSE               # MIT License
└── README.md            # This file
```

## 🔧 Configuration

Default settings can be modified in `config/default.conf`:

```bash
# IP Range Configuration
DEFAULT_IP_START=1
DEFAULT_IP_END=240

# Network Check Configuration
DEFAULT_TIMEOUT=2
DEFAULT_PARALLEL_JOBS=10

# Output Configuration
DEFAULT_OUTPUT_FORMAT="csv"
```

## 🚨 Error Handling

The script includes comprehensive error handling for:
- Invalid file paths or permissions
- Malformed FQDN or subnet formats
- Network connectivity issues
- Invalid command line arguments
- Resource constraints

## 🔒 Security Considerations

- The script performs network scans which may trigger security alerts
- Use appropriate IP ranges to avoid scanning unauthorized networks
- Consider rate limiting in production environments
- Validate input files to prevent injection attacks

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆕 Changelog

### v2.0.0
- Complete rewrite with enhanced functionality
- Added parallel processing capabilities
- Multiple output formats (CSV, JSON, table)
- Comprehensive error handling and validation
- Extended CIDR support (/20-/24)
- Modular utility functions
- Test suite implementation
- Progress tracking and verbose logging
- Configuration file support

### v1.0.0
- Initial release
- Basic IP assignment functionality
- Support for /22, /23, /24 networks
- Simple CSV output