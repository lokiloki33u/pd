#!/bin/bash

# Check if a target domain (the first argument) was provided.
# -z "$1" checks if the first argument is null or empty.
if [ -z "$1" ]; then
    echo "Error: No target domain provided."
    echo "Usage: $0 <target_domain>"
    exit 1
fi

# Assign the first command-line argument to the TARGET variable.
TARGET="$1"
# ... rest of script now uses the TARGET variable as before.
echo "Scanning target: $TARGET"







# --- Dependency Check ---
echo "Checking if the required tools are installed before starting. If not installed, installing it."
if ! command -v "puredns" &> /dev/null; then
	echo "puredns not installed. Installing it..."
    go install -v github.com/d3mondev/puredns/v2@latest
    echo "puredns installed."
fi

if ! command -v "massdns" &> /dev/null; then
	echo "massdns not installed. Installing it..."
    git clone https://github.com/blechschmidt/massdns.git
	cd massdns
	make
	sudo make install
	echo "massdns installed."
fi


echo "Fetching wordlist and resolver list..."

# --- Wordlist installation and reference---
# curl -sS "https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Discovery/DNS/subdomains-top1million-110000.txt" -o wordlist.txt
wget -q "https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Discovery/DNS/subdomains-top1million-110000.txt" -O wordlist.txt


# --- Resolvers list ---
# curl -sS "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" -o resolvers.txt
wget -q "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" -O resolvers.txt



echo "[-] Starting active brute-force with puredns..."
puredns bruteforce wordlist.txt "$TARGET" -r resolvers.txt -w active_subs.txt

# echo "[-] Combining results..."
# cat passive_subs.txt active_subs.txt | sort -u > all_subdomains.txt

# echo "[+] Done! Results saved to all_subdomains.txt"
echo "[+] Done! Results saved to active_subs.txt"









