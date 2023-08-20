# IP Address Assignment Script

This script assigns unused IP addresses from specified CIDR subnets to a list of FQDNs.

## Features

1. **Expand FQDNs**: Converts range-based FQDNs into individual entries. E.g., `web[01-03].example.com` becomes:
    ```
    web01.example.com
    web02.example.com
    web03.example.com
    ```

2. **Generate IPs**: Generates a list of IP addresses for the given CIDR subnet. Currently, it supports `/2[2-4]` CIDR notation. 

3. **Check Unused IPs**: For each FQDN, the script attempts to find an unused IP by checking DNS and pinging the IP.

## Usage

To use the script, you'll need to provide a list of FQDNs and a list of CIDR subnets. You can set these directly in the script before executing.

### Step-by-Step:

1. Open the script using a text editor.

2. Locate the `fqdns` variable and set it to your list of FQDNs. Use line breaks for multiple entries. If you have range-based FQDNs, you can use the format like `web[01-03].example.com`.

   **Example:**
   ```bash
   export fqdns="web[01-03].example.com
   db01.example.com
   db02.example.com"
   ```

   This would represent the FQDNs:
   - web01.example.com
   - web02.example.com
   - web03.example.com
   - db01.example.com
   - db02.example.com

3. Locate the `subnets` variable and set it to your list of CIDR subnets. Use line breaks for multiple entries.

   **Example:**
   ```bash
   export subnets="192.168.1.0/24
   192.168.2.0/23"
   ```

   This would represent the CIDR subnets:
   - 192.168.1.0/24
   - 192.168.2.0/23

4. Save the changes and close the text editor.

5. Execute the script:

```bash
chmod 755 ./assign_ips.sh
./assign_ips.sh
```

Output:
```
web01.example.com,192.168.1.1
web02.example.com,192.168.1.2
...
```

## Notes

- The script uses both `host` and `ping` commands to verify if an IP address is unused. Ensure that these commands are available on your system.
- The script currently supports `/2[2-4]` CIDR notations. If you need more CIDR notations, you can extend the `generate_ips` function.

