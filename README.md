# DNS-IP-Mapper

DNS-IP-Mapper is a tool designed to automatically assign available IP addresses from specified subnets to a list of FQDNs (Fully Qualified Domain Names).

## Prerequisites

- Bash (version 4 or higher is recommended)
- `host` command (typically included in the `bind-utils` package)

## Getting Started

### 1. Preparation

- **FQDN File**: Prepare a text file containing a list of FQDNs you wish to assign IP addresses to. Each FQDN should be on a new line.
  - Example: `fqdns.txt`
  
    ```
    db01.example.com
    db02.example.com
    web0[1-2].example.com
    ```

- **Subnet File**: Prepare another text file containing the subnets you want the IP addresses to be picked from. Each subnet should be on a new line.
  - Example: `subnets.txt`

    ```
    192.168.1.0/24
    192.168.2.0/24
    ```

### 2. Execute the Script

Run the script using the following command:

```bash
./assign_ips.sh -f <path_to_FQDN_file> -n <path_to_subnet_file> [-s <IP_start_range>] [-e <IP_end_range>]
```

### Options

- `-f` : Path to the file containing FQDNs.
- `-n` : Path to the file containing subnets.
- `-s` : Starting IP address range (default is 1).
- `-e` : Ending IP address range (default is 240).

### Example

```bash
./assign_ips.sh -f fqdns.txt -n subnets.txt -s 10 -e 100
```

This will attempt to assign IP addresses starting from `.10` to `.100` within the specified subnets to the FQDNs.

### Output

The script will display the assigned IP addresses for each FQDN in the following format:

```
<fqdn>,<assigned_ip>
```

For example, the output might look something like:

```
db01.example.com,192.168.1.10
db02.example.com,192.168.1.11
web01.example.com,192.168.1.12
web02.example.com,192.168.1.13
```

### IP Address Assignment Criteria

The script determines the availability of an IP address based on two checks:
1. **DNS Check**: The script checks if there's already a DNS record for the IP address using the `host` command. 
2. **Ping Check**: The script then checks if the IP address responds to a ping.

An IP address is considered available for assignment if **both** checks fail, i.e., if there's no DNS record for the IP and it doesn't respond to a ping.

## Note

- Currently, the script only supports CIDR values of 24, 23, and 22.
- In the current version, each FQDN is assigned a unique IP address from the provided subnets.
