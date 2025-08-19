#!/bin/bash

# #############################################################################
# #                                                                           #
# # R3C0N - A Simple & Effective Reconnaissance Script                        #
# # Author: Your Name Here                                                    #
# # Version: 1.0                                                              #
# #                                                                           #
# #############################################################################
# #                                                                           #
# # This script automates the initial phase of reconnaissance for a given     #
# # domain. It performs the following steps:                                  #
# # 1. Checks for required tools.                                             #
# # 2. Sets up a structured directory for the target.                         #
# # 3. Finds subdomains using subfinder.                                      #
# # 4. Probes for live web hosts using httpx.                                 #
# # 5. Scans live hosts for vulnerabilities using nuclei.                     #
# #                                                                           #
# # Usage: ./recon.sh <domain>                                                #
# # Example: ./recon.sh example.com                                           #
# #                                                                           #
# #############################################################################

# --- Color Codes for Better Output ---
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[1;31m"
RESET="\033[0m"

# --- Function to Display Banners ---
print_banner() {
    echo -e "${BLUE}=======================================================${RESET}"
    echo -e "${GREEN}$1${RESET}"
    echo -e "${BLUE}=======================================================${RESET}"
}

# --- Check for Root ---
# Some tools might not work well as root, so it's good practice to check.
if [[ $(id -u) -eq 0 ]]; then
    echo -e "${RED}[!] This script is not meant to be run as root. Please run as a normal user.${RESET}"
    exit 1
fi

# --- Check for Target Argument ---
if [ -z "$1" ]; then
    echo -e "${RED}[!] Usage: $0 <domain.com>${RESET}"
    exit 1
fi

TARGET=$1
# Create a dedicated directory for the target to keep results organized.
RECON_DIR="reconData/$TARGET"
mkdir -p "$RECON_DIR"

# --- Dependency Check ---
# Check if all required tools are installed before starting.
print_banner "Checking for required tools..."
dependencies=("subfinder" "httpx-toolkit" "nuclei" "amass")
missing_deps=()

for tool in "${dependencies[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        missing_deps+=("$tool")
    fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${RED}[!] The following tools are not installed:${RESET}"
    for dep in "${missing_deps[@]}"; do
        echo -e "${YELLOW}- $dep${RESET}"
    done
    echo -e "${BLUE}[*] Please install them to proceed. You can use Go:${RESET}"
    echo -e "go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    echo -e "go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
    echo -e "go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    echo -e "go install -v github.com/owasp-amass/amass/v4/cmd/amass@latest"
    exit 1
else
    echo -e "${GREEN}[+] All tools are installed. Let's begin!${RESET}"
fi

# --- Reconnaissance Functions ---

# 1. Subdomain Enumeration with subfinder (Quick Passive Scan with subfinder)
run_subfinder() {
    print_banner "Step 1: Running subfinder for subdomain enumeration"
    subfinder -d "$TARGET" -o "$RECON_DIR/subdomains.txt" -all -silent
    SUB_COUNT=$(wc -l < "$RECON_DIR/subdomains.txt")
    if [ "$SUB_COUNT" -gt 0 ]; then
        echo -e "${GREEN}[+] Found $SUB_COUNT subdomains. Saved to $RECON_DIR/subdomains.txt${RESET}"
    else
        echo -e "${RED}[!] No subdomains found for $TARGET.${RESET}"
        exit 1 # Exit if no subdomains are found, as subsequent steps would fail.
    fi
}

# # 2. Deep Passive Scan with Amass
# run_amass_passive() {
#     print_banner "Step 2: Running Amass for deep passive enumeration"
#     amass enum -passive -d "$TARGET" -o "$RECON_DIR/amass_passive.txt" -silent
    
#     AMASS_PASSIVE_COUNT=$(wc -l < "$RECON_DIR/amass_passive.txt")
#     if [ "$AMASS_PASSIVE_COUNT" -gt 0 ]; then
#         echo -e "${GREEN}[+] Amass (Passive) found $AMASS_PASSIVE_COUNT subdomains. Saved to $RECON_DIR/amass_passive.txt${RESET}"
#     else
#         echo -e "${YELLOW}[!] Amass (Passive) found no new subdomains.${RESET}"
#     fi
# }

# 3. Active Enumeration with Amass (it will take the subdomain from subfinder)
run_amass_active() {
    print_banner "Step 3: Running Amass for ACTIVE enumeration"
    echo -e "${YELLOW}[!] This may take a long time. Active scans are deep and thorough.${RESET}"
    amass enum -active -nf "$RECON_DIR/subdomains.txt" -d "$TARGET" -o "$RECON_DIR/amass_active.txt" -config "$RECON_DIR/config.yaml" -silent
    
    AMASS_ACTIVE_COUNT=$(wc -l < "$RECON_DIR/amass_active.txt")
    if [ "$AMASS_ACTIVE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}[+] Amass (Active) found $AMASS_ACTIVE_COUNT subdomains. Saved to $RECON_DIR/amass_active.txt${RESET}"
    else
        echo -e "${YELLOW}[!] Amass (Active) found no additional subdomains.${RESET}"
    fi
}

# 4. Combine, Unify, and Finalize Results
combine_results() {
    print_banner "Step 4: Combining and sorting all results"
    # Combine all three files, sort them, and remove duplicates
    cat "$RECON_DIR/subfinder.txt" "$RECON_DIR/amass_active.txt" | sort -u > "$RECON_DIR/unique_subdomains.txt"

    FINAL_COUNT=$(wc -l < "$RECON_DIR/unique_subdomains.txt")
    echo -e "${GREEN}[+] Final combined list created with $FINAL_COUNT unique subdomains: $RECON_DIR/unique_subdomains.txt${RESET}"
}





# 5. Live Host Probing with httpx
run_httpx() {
    print_banner "Step 5: Probing for live web servers with httpx"
    cat "$RECON_DIR/subdomains.txt" | httpx -o "$RECON_DIR/live_hosts.txt" -silent -threads 100
    LIVE_COUNT=$(wc -l < "$RECON_DIR/live_hosts.txt")
    if [ "$LIVE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}[+] Found $LIVE_COUNT live hosts. Saved to $RECON_DIR/live_hosts.txt${RESET}"
    else
        echo -e "${RED}[!] No live hosts found from the list of subdomains.${RESET}"
        exit 1 # Exit if no live hosts are found.
    fi
}

# 6. Vulnerability Scanning with Nuclei
run_nuclei() {
    print_banner "Step 6: Running nuclei for vulnerability scanning"
    echo -e "${YELLOW}[*] This may take a while depending on the number of hosts...${RESET}"
    # Using a curated list of templates for speed: common vulnerabilities, misconfigs, and tech detection.
    nuclei -l "$RECON_DIR/live_hosts.txt" -t cves/ -t technologies/ -t vulnerabilities/ -t misconfiguration/ -o "$RECON_DIR/nuclei_findings.txt" -stats
    FINDINGS_COUNT=$(wc -l < "$RECON_DIR/nuclei_findings.txt")
    echo -e "${GREEN}[+] Nuclei scan complete. Found $FINDINGS_COUNT potential findings. Saved to $RECON_DIR/nuclei_findings.txt${RESET}"
}

# --- Main Execution Flow ---
main() {
    print_banner "Starting Reconnaissance on: $TARGET"
    echo -e "${YELLOW}[*] Results will be saved in: $RECON_DIR/${RESET}"

    run_subfinder
    run_httpx
    run_nuclei

    print_banner "Reconnaissance Complete for $TARGET"
    echo -e "${GREEN}All results are stored in the '$RECON_DIR' directory.${RESET}"
    echo -e "${BLUE}Next steps:${RESET}"
    echo -e "1. Manually review ${YELLOW}$RECON_DIR/nuclei_findings.txt${RESET} for high-impact vulnerabilities."
    echo -e "2. Explore the live websites listed in ${YELLOW}$RECON_DIR/live_hosts.txt${RESET}."
    echo -e "Happy Hacking!${RESET}"
}

# Execute the main function with the provided arguments
main "$@"
