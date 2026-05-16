#!/bin/bash

# Define text styling colors
GREEN="\e[32m"
BLUE="\e[1;34m"
RED="\e[31m"
BOLD="\e[1m"
RESET="\e[0m"

# The direct raw link to your production script
URL_ALS_SCRIPT="https://github.com/CreeperNewGamer/als/raw/refs/heads/main/als.sh"

echo -e "${BLUE}Downloading and Installing als (Advanced List Files)...${RESET}\n"

# 1. Determine target directory ($PREFIX/bin for Termux, /usr/local/bin for standard Linux)
if [ -n "$PREFIX" ]; then
    TARGET_DIR="$PREFIX/bin"
else
    TARGET_DIR="/usr/local/bin"
fi

TARGET_FILE="$TARGET_DIR/als"

# 2. Safety check: Verify curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${RESET}"
    if [ -n "$PREFIX" ]; then
        echo "Run 'pkg install curl' first, then try again."
    else
        echo "Please install curl using your system package manager."
    fi
    exit 1
fi

# 3. Handle elevation permissions gracefully if outside Termux environment
USE_SUDO=""
if [ ! -w "$TARGET_DIR" ]; then
    echo -e "${BLUE}Root privileges required to write to $TARGET_DIR...${RESET}"
    USE_SUDO="sudo"
fi

# 4. Stream directly into the environment target path
echo -e "  [+] Fetching als from CreeperNewGamer/als repository..."
if $USE_SUDO curl -sSfL "$URL_ALS_SCRIPT" -o "$TARGET_FILE"; then
    
    # Apply global execution bits
    echo -e "  [+] Setting executable bits..."
    $USE_SUDO chmod +x "$TARGET_FILE"
    
    # 5. Print the 10+/10 confirmation box
    echo -e "\n${GREEN}╭──────────────────────────────────────────────────╮"
    echo -e "│       Installation Completed Successfully!       │"
    echo -e "╰──────────────────────────────────────────────────╯${RESET}"
    echo -e "\n${BOLD}Advanced List Files${RESET} is now available globally."
    echo -e "Simply execute ${GREEN}als${RESET} from anywhere in your environment to run it!\n"
    echo -e "Check your flags anytime with: ${BLUE}als -h${RESET}\n"

    # 6. Explicitly remove ./install.sh if it exists locally
    if [ -f "./install.sh" ]; then
        echo -e "  [+] Removing ./install.sh..."
        rm -f "./install.sh"
    fi
else
    echo -e "\n${RED}Error: Failed to fetch als.sh from the repository.${RESET}"
    echo "Please check your network connection and verify the repository state."
    exit 1
fi
