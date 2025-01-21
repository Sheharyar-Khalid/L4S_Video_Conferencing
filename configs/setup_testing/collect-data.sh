#!/bin/bash

# =============================================================================
# Script: collect_tcp_data.sh
# Description: Collects TCP network statistics for all traffic destined for
#              11.0.0.1 using the 'ss' command.
#              Handles Ctrl+C interrupts to gracefully terminate data collection.
#              Outputs raw and processed data in TXT and CSV formats.
#              Runs indefinitely until interrupted by the user.
# Usage: ./collect_tcp_data.sh <FILENAME>
# Example: ./collect_tcp_data.sh experiment1
# =============================================================================

# -------------------------------
# 1. Argument Validation
# -------------------------------
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <FILENAME>"
    echo "Example: $0 experiment1"
    exit 1
fi

FILENAME=$1
DST="11.0.0.1"

# -------------------------------
# 2. Initialize Output Files
# -------------------------------
# Remove existing output files if they exist
rm -f "${FILENAME}.txt" "${FILENAME}.csv"

# Initialize the raw data file
touch "${FILENAME}.txt"

# -------------------------------
# 3. Define Helper Functions
# -------------------------------

# Function to convert data sizes to kilounits (K)
converttokilo() {
    echo "$1" | sed '
        s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)K/\1*1/g;
        s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)M/\1*1000/g;
        s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)G/\1*1000000/g;
        s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)T/\1*1000000000/g;
        s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)P/\1*1000000000000/g;
        s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)E/\1*1000000000000000/g
    ' | bc
}

# Cleanup function to process raw data and generate CSV
cleanup() {
    echo "Running cleanup to process data..."

    # Ensure the raw data file exists and is not empty
    if [ ! -s "${FILENAME}.txt" ]; then
        echo "No data collected in ${FILENAME}.txt. Skipping CSV generation."
        exit 0
    fi

    # Initialize CSV with headers
    echo "timestamp,protocol,state,recv_q,send_q,local_address,peer_address,timer,timeout,retransmits" > "${FILENAME}.csv"

    # Process each line of the raw data
    while read -r line; do
        # Extract relevant fields from the ss output
        # Adjust the parsing based on your specific ss output format
        timestamp=$(echo "$line" | awk '{print $1}')
        protocol=$(echo "$line" | awk '{print $2}')
        state=$(echo "$line" | awk '{print $3}')
        recv_q=$(echo "$line" | awk '{print $4}')
        send_q=$(echo "$line" | awk '{print $5}')
        local_address=$(echo "$line" | awk '{print $6}')
        peer_address=$(echo "$line" | awk '{print $7}')
        timer=$(echo "$line" | awk '{print $8}')
        timeout=$(echo "$line" | awk '{print $9}')
        retransmits=$(echo "$line" | awk '{print $10}')

        # Combine the extracted fields into a CSV line
        echo "${timestamp},${protocol},${state},${recv_q},${send_q},${local_address},${peer_address},${timer},${timeout},${retransmits}" >> "${FILENAME}.csv"
    done < "${FILENAME}.txt"

    echo "Data processing complete. CSV saved to ${FILENAME}.csv"
    exit 0
}

# -------------------------------
# 4. Define Termination Function
# -------------------------------
terminate() {
    echo ""
    echo "Interrupt received. Terminating data collection..."

    # Kill data collection process if running
    if ps -p "$COLLECT_PID" > /dev/null 2>&1; then
        echo "Killing data collection process with PID $COLLECT_PID"
        kill "$COLLECT_PID" 2>/dev/null
    fi

    # Run cleanup to process collected data
    cleanup
}

# -------------------------------
# 5. Trap Signals for Cleanup
# -------------------------------
trap terminate SIGINT SIGTERM

# -------------------------------
# 6. Start Data Collection in Background
# -------------------------------
echo "Starting TCP data collection for DST: $DST"

# Start the data collection loop in the background
(
    while true; do 
        # Suppress stderr to avoid "failed to open cgroup2 by ID." error
        ss --no-header -ein dst "$DST" 2>/dev/null | ts '%.s' >> "${FILENAME}.txt"
        sleep 1  # Adjust the interval as needed (e.g., 1 second)
    done
) &
COLLECT_PID=$!

echo "Data collection started with PID $COLLECT_PID"

# -------------------------------
# 7. Wait Indefinitely
# -------------------------------
echo "Data collection is running. Press Ctrl+C to stop and process data."

# Wait for the background data collection process
wait "$COLLECT_PID"

exit 0
