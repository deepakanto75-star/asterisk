#!/bin/bash

# Check if the prefix argument is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <prefix>"
    exit 1
fi

# Function to display the key-value pairs
show_config_values() {
    local filter=$1
    local config_file="config.json"

    if [[ ! -f "$config_file" ]]; then
        echo "❌ Error: $config_file not found." >&2
        return 1
    fi

    # Use jq directly to filter keys and output a valid JSON object
    local result_json
    result_json=$(jq -c "to_entries 
        | map(select(.key | startswith(\"$filter\"))) 
        | from_entries" "$config_file")

    if [[ -z "$result_json" || "$result_json" == "null" ]]; then
        echo "❌ No matching keys found for filter '$filter'."
        return 1
    fi

    echo "$result_json"
}

# Function to check if port is available
is_port_available() {
    local port=$1

    # 1. Check with ss/netstat (host-level)
    if ss -tuln | grep -qE ":$port\s"; then
        return 1
    fi

    # 2. Check if any Docker container uses this port
    if docker ps --format '{{.Names}}: {{.Ports}}' | grep -qE ".*:$port->"; then
        return 1
    fi

    # 3. Check Kubernetes services (NodePort or exposed via hostPort)
    if command -v kubectl &>/dev/null; then
        # Check if kubectl can reach the cluster
        if kubectl version --short &>/dev/null; then
            # NodePort or ClusterPort check
            if kubectl get svc --all-namespaces -o json | jq -e --arg port "$port" '.items[]?.spec.ports[]? | select(.nodePort == ($port|tonumber) or .port == ($port|tonumber))' &>/dev/null; then
                return 1
            fi
            # hostPort check
            if kubectl get pods --all-namespaces -o json | jq -e --arg port "$port" '.items[]?.spec.containers[]?.ports[]? | select(.hostPort == ($port|tonumber))' &>/dev/null; then
                return 1
            fi
        fi
    fi
    return 0  # Port is available
}

# Function to get an available port from JSON, with an optional 'previous_port_user' parameter
get_available_port_from_json() {
    local json_data="$1"
    local key="$2"
    local previous_ports="$3"   # a space-separated list of previously used ports
    local max_tries="${4:-500}"

    # Get the base port from JSON
    local base_port
    base_port=$(echo "$json_data" | jq -r ".\"$key\"")

    if [[ -z "$base_port" || "$base_port" == "null" ]]; then
        echo "❌ Key '$key' not found or invalid."
        return 1
    fi

    local next_port=$base_port
    local attempts=0

    # Check the previous ports to avoid reuse
    while [[ $attempts -lt $max_tries ]]; do
        # Check if the port is available and not in the previous ports
        if is_port_available "$next_port" && ! echo "$previous_ports" | grep -q "$next_port"; then
            echo "$next_port"
            return 0
        fi
        ((next_port++))  # Increment port after checking availability
        ((attempts++))
    done

    echo "❌ No available port found for '$key' after $max_tries tries."
    return 1
}

# Function to check if a range of ports is available
is_range_available() {
    local start=$1
    local end=$2
    for ((port=start; port<=end; port++)); do
        if ! is_port_available "$port"; then
            return 1  # Not all ports are available
        fi
    done
    return 0  # All ports are available
}

# Assign the first argument to the prefix variable
prefix=$1
# Simulated previous ports
previous_ports=""


# Main logic to check arguments
if [[ $# -eq 1 && "$1" =~ ^(build|dev|uat|prod)$ ]]; then
    RESULT_JSON=$(show_config_values "$1")
    echo "$RESULT_JSON"
else
    echo "Usage: $0 [build|dev|uat|prod]"
    exit 1
fi

# {"build-port":"40033","build-ssh-port":"40032","build-ftp-port":"50003","build-no-of-port":"5","build-pasv-min-port":"21000"}


# STAGE 2
# Extract keys starting with "build"
# port_keys=($(echo "$RESULT_JSON" | jq -r 'to_entries | map(select(.key | test("^build"))) | .[].key'))
# port_keys=()
# port_keys=("${prefix}-port" "${prefix}-ssh-port" "${prefix}-ftp-port" "${prefix}-pasv-min-port")
port_keys=("${prefix}-port" "${prefix}-ssh-port" "${prefix}-ftp-port" "${prefix}-pasv-min-port")


NEW_JSON_RESULT_1="{"
previous_ports=""

for key in "${port_keys[@]}"; do
    new_port=$(get_available_port_from_json "$RESULT_JSON" "$key" "$previous_ports")
   
    if [[ -n "$new_port" ]]; then
        # echo "🔧 New $key: $new_port"
        previous_ports="$previous_ports $new_port"
        NEW_JSON_RESULT_1+="\"$key\":$new_port,"  # Append without quotes for numeric values
    else
        echo "❌ Could not find an available port for $key."
    fi
done

# Trim trailing comma and close JSON object
NEW_JSON_RESULT_1="${NEW_JSON_RESULT_1%,}}"

# Final Output
echo "🧾 Final NEW_JSON_RESULT_1: $NEW_JSON_RESULT_1"
# Final NEW_JSON_RESULT_1: {"build-port":40034,"build-ssh-port":40035,"build-ftp-port":40036,"build-pasv-min-port":21000}

# STAGE 3
# Extract values
no_of_ports=$(echo "$RESULT_JSON" | jq -r ".\"${prefix}-no-of-port\"")
pasv_min_port=$(echo "$NEW_JSON_RESULT_1" | jq -r ".\"${prefix}-pasv-min-port\"")

# Calculate end of the range
pasv_max_port=$((pasv_min_port + no_of_ports - 1))

echo "🔍 Checking PASV port range: $pasv_min_port to $pasv_max_port"

# Initial check
if is_range_available "$pasv_min_port" "$pasv_max_port"; then
    echo "✅ PASV port range is available: $pasv_min_port-$pasv_max_port"
else
    echo "⚠️ PASV port range $pasv_min_port-$pasv_max_port is NOT fully available. Searching for new range..."
    # Try next available block of ports
    search_start=$((pasv_min_port + 1))
    found_range=0

    while true; do
        candidate_start=$search_start
        candidate_end=$((candidate_start + no_of_ports - 1))

        if is_range_available "$candidate_start" "$candidate_end"; then
            echo "✅ Found new PASV port range: $candidate_start-$candidate_end"
            NEW_JSON_RESULT_1=$(echo "$NEW_JSON_RESULT_1" | jq ".\"${prefix}-pasv-min-port\" = $candidate_start")
            break
        fi

        ((search_start++))
        if ((search_start > 65535 - no_of_ports)); then
            echo "❌ No available PASV port range found."
            break
        fi
    done
fi

# Show updated NEW_JSON_RESULT_1
echo "🧾 Updated NEW_JSON_RESULT_1: $NEW_JSON_RESULT_1"

# 2. Add pasv-max-port to the NEW_JSON_RESULT_1
NEW_JSON_RESULT_FINAL=$(echo "$NEW_JSON_RESULT_1" | jq ".\"${prefix}-pasv-max-port\" = $pasv_max_port")

# 3. Print final JSON
echo "✅ NEW_JSON_RESULT_FINAL: $NEW_JSON_RESULT_FINAL"


# Run jq transformation and execute the sed commands
echo "$NEW_JSON_RESULT_FINAL" | jq -r --arg prefix "$prefix" '
  to_entries[]
  | select(.key | startswith($prefix))
  | "key=" + .key + " value=" + 
    (if (type == "string") then "\"" + .value + "\"" else (.value | tostring) end)
' | while read -r line; do
    key=$(echo "$line" | cut -d' ' -f1 | cut -d'=' -f2)
    value=$(echo "$line" | cut -d' ' -f2- | cut -d'=' -f2-)

    # Escape value for sed
    value_escaped=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')

    # Handle both numeric and quoted string values, with or without trailing comma
    sed -i -E "s/(\"$key\": )(\"[^\"]*\"|[0-9]+)(,?)/\1$value_escaped\3/" config.json
done

if [ $? -eq 0 ]; then
    echo "✅ Configuration updated successfully."
else
    echo "❌ Failed to update configuration."
    exit 1
fi



