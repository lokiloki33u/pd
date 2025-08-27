#!/bin/bash


# Check if a target domain (the first argument) was provided.
# -z "$1" checks if the first argument is null or empty.
if [ -z "$1" ]; then
    echo "Error: No target domain provided."
    echo "Usage: $0 <target_domain>"
    exit 1
fi



# --- Configuration ---
TARGET="$1"
SUBDOMAINS_FILE="reconData/$TARGET/subdomains.txt"
OUTPUT_FILE="active_subs.txt"
WORDLIST="wordlist.txt"
RESOLVERS="resolvers.txt"

# Clear the output file to start fresh
> "$OUTPUT_FILE"

echo "Scanning target: $TARGET"


# --- Dependency Check ---
echo "Checking if the required tools are installed before starting. If not installed, installing it."
if ! command -v "puredns" &> /dev/null; then
	echo "puredns not installed. Installing it..."
    go install -v github.com/d3mondev/puredns/v2@latest
    echo "puredns installed."
fi

if ! command -v "massdns" &> /dev/null; then
	echo "massdns not installed. Please install it..."
    echo "from source https://github.com/blechschmidt/massdns.git or use package manager to install it"
fi



echo "Fetching wordlist..."
# curl -sS "https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Discovery/DNS/subdomains-top1million-110000.txt" -o wordlist.txt
wget -q "https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Discovery/DNS/subdomains-top1million-110000.txt" -O wordlist.txt


echo "Fetching resolver list..."
# curl -sS "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" -o resolvers.txt
wget -q "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" -O resolvers.txt




# --- Script ---
echo "[-] Starting scan..."

# --- ADDED: Run on the root domain first ---
echo "[-] Now brute-forcing root domain: $TARGET"
puredns bruteforce "$WORDLIST" "$TARGET" -r "$RESOLVERS" --quiet >> "$OUTPUT_FILE"


# Loop through each line in the subdomains file
echo "[-] Starting subdomain loop..."
while IFS= read -r subdomain; do
    # Check to make sure the line is not empty
    if [ -n "$subdomain" ]; then
        echo "[-] Now brute-forcing: $subdomain"
        # Run the puredns command, using the subdomain from the file as the target
        puredns bruteforce "$WORDLIST" "$subdomain" -r "$RESOLVERS" --quiet >> "$OUTPUT_FILE"
    fi
done < "$SUBDOMAINS_FILE"
echo "[+] Scan complete. All results are in $OUTPUT_FILE"



echo "[-] Combining results..."
cat "$SUBDOMAINS_FILE" "$OUTPUT_FILE" | sort -u > "$RECON_DIR/all_subdomains.txt"
echo "[+] Done! Results saved to all_subdomains.txt"
