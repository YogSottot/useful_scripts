#!/bin/bash

OUTPUT_DIR="/path/to/output/directory"
SUMMARY_FILE="$OUTPUT_DIR/ip_summary.txt"

# Process all pcap files and extract IP addresses
for file in $OUTPUT_DIR/*.pcap*; do
    tcpdump -r "$file" -nn -q 'ip' | awk '{print $3}' | cut -d. -f1-4 >> temp_ips.txt
    tcpdump -r "$file" -nn -q 'ip' | awk '{print $5}' | cut -d. -f1-4 >> temp_ips.txt
done

# Count occurrences, sort, and save to summary file
sort temp_ips.txt | uniq -c | sort -rn > "$SUMMARY_FILE"

# Clean up temporary file
rm temp_ips.txt

echo "IP summary has been saved to $SUMMARY_FILE"

# This script does the following:

# Iterates through all pcap files in the specified output directory.
# Uses tcpdump to extract source and destination IP addresses from each file.
# Combines all IP addresses into a temporary file.
# Sorts the IP addresses, counts occurrences, and sorts again by frequency.
# Saves the sorted summary to a file named 'ip_summary.txt' in the output directory.
# Cleans up the temporary file.
