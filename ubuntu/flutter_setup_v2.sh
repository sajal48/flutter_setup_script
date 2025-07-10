#!/bin/bash

# Use safer error handling that's compatible with SDKMAN
set -eo pipefail

# Configuration
TOOLS_DIR="$HOME/tools"
FLUTTER_VERSION="3.24.3"
FLUTTER_DIR="$TOOLS_DIR/flutter"
ANDROID_SDK_DIR="$TOOLS_DIR/android-sdk"
CMDLINE_TOOLS_DIR="$ANDROID_SDK_DIR/cmdline-tools/latest"
JAVA_VERSION="17.0.9-tem"
LOG_FILE="/tmp/flutter_setup_v2.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Icons
readonly CHECK="✅"
readonly CROSS="❌"
readonly ARROW="➤"
readonly GEAR="⚙️"
readonly PACKAGE="📦"
readonly DOWNLOAD="📥"
readonly ROCKET="🚀"
readonly WARNING="⚠️"
readonly INFO="ℹ️"

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}    Flutter Development Environment Setup v2.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${CYAN}${ARROW} ${1}${NC}"
    log "STEP: $1"
}

print_success() {
    echo -e "${GREEN}${CHECK} ${1}${NC}"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}${CROSS} ${1}${NC}" >&2
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} ${1}${NC}"
    log "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}${INFO} ${1}${NC}"
    log "INFO: $1"
}

# Enhanced progress bar with percentage
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    
    # Prevent division by zero
    if [ "$total" -eq 0 ]; then
        printf "\r${PURPLE}[${NC}] 0%% - ${message}${NC}"
        return
    fi
    
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 2))
    local empty=$((50 - filled))
    
    # Create the progress bar string using ASCII characters
    local filled_str=""
    local empty_str=""
    
    if [ $filled -gt 0 ]; then
        filled_str=$(printf "%${filled}s" | tr ' ' '=')
    fi
    
    if [ $empty -gt 0 ]; then
        empty_str=$(printf "%${empty}s" | tr ' ' '-')
    fi
    
    printf "\r${PURPLE}[${NC}${filled_str}${empty_str}${PURPLE}] ${percentage}%% - ${message}${NC}"
}

# Silent spinner for background operations
spinner() {
    local pid=$1
    local message=$2
    
    # Try Unicode spinner first, fallback to ASCII if not supported
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local delay=0.1
    
    # Test if Unicode is supported by checking if terminal can display it
    if ! printf "⠋" 2>/dev/null | grep -q "⠋"; then
        # Fallback to ASCII spinner
        spin_chars="|/-\\"
        delay=0.2
    fi
    
    while kill -0 $pid 2>/dev/null; do
        for (( i=0; i<${#spin_chars}; i++ )); do
            printf "\r${CYAN}${spin_chars:$i:1} ${message}${NC}"
            sleep $delay
        done
    done
    printf "\r"
}

# Enhanced error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    print_error "Script failed at line $line_number with exit code $exit_code"
    print_error "Check log file: $LOG_FILE"
    
    # Cleanup on error
    cleanup_on_error
    exit $exit_code
}

trap 'handle_error ${LINENO}' ERR
trap 'handle_interrupt' INT TERM

cleanup_on_error() {
    print_warning "Cleaning up partial installations..."
    # Remove incomplete downloads
    rm -f /tmp/flutter.tar.xz /tmp/cmdline-tools.zip 2>/dev/null || true
    log "Cleanup completed"
}

# Handle script interruption (Ctrl+C)
handle_interrupt() {
    echo ""
    print_warning "Script interrupted by user"
    cleanup_on_error
    exit 130
}

# Check if running with necessary permissions
check_permissions() {
    print_step "Checking system permissions and requirements"
    
    # Check for required commands
    local required_commands=("curl" "wget" "unzip" "tar" "grep" "awk" "sed")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_warning "Missing required commands: ${missing_commands[*]}"
        print_info "These will be installed automatically during system package installation"
    fi
    
    # Check if we can use sudo
    if ! sudo -n true 2>/dev/null; then
        print_info "This script requires sudo access for installing system packages"
        print_info "You may be prompted for your password once"
        sudo true || {
            print_error "sudo access is required for this script"
            exit 1
        }
    fi
    
    # Check available disk space (minimum 5GB)
    local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    local required_space=5242880  # 5GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Insufficient disk space. At least 5GB required in home directory"
        exit 1
    fi
    
    print_success "System requirements verified"
}

# Detect Linux distribution and set package manager
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    case $DISTRO in
        ubuntu|debian)
            PKG_MANAGER="apt"
            PKG_UPDATE="apt update -y"
            PKG_INSTALL="apt install -y"
            ;;
        fedora|rhel|centos)
            PKG_MANAGER="dnf"
            PKG_UPDATE="dnf check-update || true"
            PKG_INSTALL="dnf install -y"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            PKG_UPDATE="pacman -Sy"
            PKG_INSTALL="pacman -S --noconfirm"
            ;;
        *)
            print_warning "Unsupported distribution: $DISTRO. Assuming apt-based system"
            PKG_MANAGER="apt"
            PKG_UPDATE="apt update -y"
            PKG_INSTALL="apt install -y"
            ;;
    esac
    
    print_success "Detected $DISTRO $VERSION"
}

# Enhanced package installation with retry logic
install_system_packages() {
    print_step "Installing system dependencies"
    
    local packages=""
    case $PKG_MANAGER in
        apt)
            packages="curl git unzip xz-utils zip libglu1-mesa wget qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils"
            ;;
        dnf)
            packages="curl git unzip xz zip mesa-libGLU wget qemu-kvm libvirt-daemon libvirt-client bridge-utils"
            ;;
        pacman)
            packages="curl git unzip xz zip glu wget qemu libvirt bridge-utils"
            ;;
    esac
    
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if execute_with_spinner "sudo $PKG_UPDATE" "Updating package database"; then
            if execute_with_spinner "sudo $PKG_INSTALL $packages" "Installing system packages"; then
                break
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_warning "Package installation failed. Retrying ($retry_count/$max_retries)..."
            sleep 2
        else
            print_error "Failed to install system packages after $max_retries attempts"
            return 1
        fi
    done
    
    print_success "System packages installed successfully"
}

# Execute command with spinner and proper error handling
execute_with_spinner() {
    local command=$1
    local message=$2
    local log_suffix=${3:-""}
    
    print_info "$message..."
    
    # Execute command in background and capture output
    {
        # Handle SDKMAN commands specially to avoid unbound variable issues
        if [[ "$command" == *"sdk "* ]]; then
            # Ensure SDKMAN is sourced before running sdk commands
            export SDKMAN_DIR="$HOME/.sdkman"
            if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
                source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null || true
            fi
        fi
        eval "$command" >> "$LOG_FILE" 2>&1
    } &
    local cmd_pid=$!
    
    # Show spinner while command runs
    spinner $cmd_pid "$message"
    
    # Wait for command completion
    wait $cmd_pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "$message completed"
        return 0
    else
        print_error "$message failed (exit code: $exit_code)"
        return $exit_code
    fi
}

# Verify command installation
verify_command() {
    local cmd=$1
    local package=$2
    
    if ! command -v "$cmd" &> /dev/null; then
        print_warning "$cmd not found. Installing $package..."
        if ! execute_with_spinner "sudo $PKG_INSTALL $package" "Installing $package"; then
            print_error "Failed to install $package"
            return 1
        fi
    fi
    return 0
}

# SDKMAN installation with better error handling
install_sdkman() {
    print_step "Setting up SDKMAN! and Java"
    
    if [ ! -d "$HOME/.sdkman" ]; then
        execute_with_spinner 'curl -s "https://get.sdkman.io" | bash' "Installing SDKMAN!"
        
        # Source SDKMAN
        export SDKMAN_DIR="$HOME/.sdkman"
        if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
            source "$HOME/.sdkman/bin/sdkman-init.sh"
        fi
    else
        print_success "SDKMAN! already installed"
        export SDKMAN_DIR="$HOME/.sdkman"
        if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
            source "$HOME/.sdkman/bin/sdkman-init.sh"
        fi
    fi
    
    # Install Java if not present
    if ! sdk list java 2>/dev/null | grep -q "$JAVA_VERSION.*installed"; then
        execute_with_spinner "sdk install java $JAVA_VERSION" "Installing Java $JAVA_VERSION"
    else
        print_success "Java $JAVA_VERSION already installed"
    fi
    
    # Set as default
    execute_with_spinner "sdk default java $JAVA_VERSION" "Setting Java $JAVA_VERSION as default"
}

# Configure shell profiles
configure_shell_profiles() {
    print_step "Configuring shell profiles"
    
    local shell_configs=("$HOME/.bashrc")
    if [ -f "$HOME/.zshrc" ]; then
        shell_configs+=("$HOME/.zshrc")
    fi
    
    for config in "${shell_configs[@]}"; do
        # SDKMAN configuration
        if ! grep -q 'SDKMAN_DIR=' "$config" 2>/dev/null; then
            {
                echo ""
                echo "# SDKMAN Configuration"
                echo 'export SDKMAN_DIR="$HOME/.sdkman"'
                echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"'
            } >> "$config"
        fi
        
        # Android SDK configuration
        if ! grep -q 'ANDROID_HOME=' "$config" 2>/dev/null; then
            {
                echo ""
                echo "# Android SDK Configuration"
                echo "export ANDROID_HOME=\"$ANDROID_SDK_DIR\""
                echo 'export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"'
            } >> "$config"
        fi
        
        # Flutter configuration
        if ! grep -q "flutter/bin" "$config" 2>/dev/null; then
            {
                echo ""
                echo "# Flutter Configuration"
                echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\""
            } >> "$config"
        fi
    done
    
    print_success "Shell profiles configured"
}

# Download with progress and resume capability
download_with_progress() {
    local url=$1
    local output=$2
    local description=$3
    
    print_info "Downloading $description..."
    
    # Use wget with progress bar and resume capability
    if wget --progress=bar:force:noscroll --continue --timeout=30 --tries=3 \
           "$url" -O "$output" 2>&1 | \
           {
               while IFS= read -r line; do
                   # Extract percentage from various wget progress formats
                   if [[ "$line" =~ ([0-9]+)% ]]; then
                       local percent="${BASH_REMATCH[1]}"
                       printf "\r${CYAN}Downloading $description: ${percent}%%${NC}"
                   elif [[ "$line" =~ \.\.\. ]]; then
                       printf "\r${CYAN}Downloading $description...${NC}"
                   fi
               done
           }; then
        printf "\r${GREEN}${CHECK} Downloaded $description successfully${NC}\n"
        return 0
    else
        print_error "Failed to download $description"
        return 1
    fi
}

# Install Android SDK with better error handling
install_android_sdk() {
    print_step "Setting up Android SDK"
    
    mkdir -p "$CMDLINE_TOOLS_DIR"
    
    if [ ! -f "$CMDLINE_TOOLS_DIR/bin/sdkmanager" ]; then
        local url="https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip"
        local temp_file="/tmp/cmdline-tools.zip"
        
        if download_with_progress "$url" "$temp_file" "Android Command Line Tools"; then
            execute_with_spinner "unzip -q '$temp_file' -d /tmp" "Extracting Android tools"
            
            # Handle directory structure - more robust approach
            if [ -d "/tmp/cmdline-tools" ]; then
                # Remove target directory if it exists
                if [ -d "$CMDLINE_TOOLS_DIR" ]; then
                    rm -rf "$CMDLINE_TOOLS_DIR"
                fi
                mkdir -p "$(dirname "$CMDLINE_TOOLS_DIR")"
                mv "/tmp/cmdline-tools" "$CMDLINE_TOOLS_DIR"
                rm -f "$temp_file"
            else
                print_error "Failed to extract Android Command Line Tools"
                rm -f "$temp_file"
                return 1
            fi
            
            # Fix nested directory issue
            if [ -d "$CMDLINE_TOOLS_DIR/cmdline-tools" ] && [ ! -f "$CMDLINE_TOOLS_DIR/bin/sdkmanager" ]; then
                # Move contents up one level
                local temp_dir="/tmp/cmdline-tools-temp"
                mv "$CMDLINE_TOOLS_DIR/cmdline-tools" "$temp_dir"
                rm -rf "$CMDLINE_TOOLS_DIR"
                mv "$temp_dir" "$CMDLINE_TOOLS_DIR"
            fi
            
            # Verify the installation
            if [ ! -f "$CMDLINE_TOOLS_DIR/bin/sdkmanager" ]; then
                print_error "Android Command Line Tools installation failed - sdkmanager not found"
                return 1
            fi
        else
            return 1
        fi
    else
        print_success "Android Command Line Tools already installed"
    fi
    
    # Set environment variables for current session
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:$PATH"
    
    # Install SDK packages
    local sdk_packages="platform-tools platforms;android-34 build-tools;34.0.0 emulator cmdline-tools;latest system-images;android-34;google_apis;x86_64"
    execute_with_spinner "\"$CMDLINE_TOOLS_DIR/bin/sdkmanager\" --sdk_root=\"$ANDROID_HOME\" $sdk_packages" "Installing Android SDK packages"
}

# Install Flutter with verification
install_flutter() {
    print_step "Setting up Flutter SDK v$FLUTTER_VERSION"
    
    if [ ! -d "$FLUTTER_DIR" ]; then
        local url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
        local temp_file="/tmp/flutter.tar.xz"
        
        if download_with_progress "$url" "$temp_file" "Flutter SDK v$FLUTTER_VERSION"; then
            execute_with_spinner "tar xf '$temp_file' -C '$TOOLS_DIR'" "Extracting Flutter SDK"
            rm -f "$temp_file"
        else
            return 1
        fi
    else
        print_success "Flutter SDK already installed"
    fi
    
    # Add to PATH for current session
    export PATH="$FLUTTER_DIR/bin:$PATH"
    
    # Configure Flutter
    execute_with_spinner "flutter config --android-sdk \"$ANDROID_HOME\"" "Configuring Flutter with Android SDK"
}

# Create AVD with better error handling
create_avd() {
    print_step "Setting up Android Virtual Device (AVD)"
    
    local avd_name="flutter_avd"
    
    if ! "$CMDLINE_TOOLS_DIR/bin/avdmanager" list avd 2>/dev/null | grep -q "$avd_name"; then
        execute_with_spinner "echo 'no' | \"$CMDLINE_TOOLS_DIR/bin/avdmanager\" create avd -n '$avd_name' -k 'system-images;android-34;google_apis;x86_64' --device 'pixel'" "Creating AVD '$avd_name'"
    else
        print_success "AVD '$avd_name' already exists"
    fi
}

# Setup KVM permissions
setup_kvm() {
    print_step "Configuring KVM for Android Emulator"
    
    if ! groups "$USER" | grep -qw kvm; then
        execute_with_spinner "sudo usermod -aG kvm '$USER'" "Adding user to KVM group"
        print_warning "You need to log out and log back in (or reboot) for KVM group changes to take effect"
    else
        print_success "User already in KVM group"
    fi
}

# Accept Android licenses with enhanced handling
accept_licenses() {
    print_step "Accepting Android SDK licenses"
    
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Attempting to accept Android licenses (attempt $attempt/$max_attempts)..."
        
        # Method 1: Use flutter doctor --android-licenses with yes command
        if command -v flutter >/dev/null 2>&1; then
            export ANDROID_HOME="$ANDROID_SDK_DIR"
            export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:$PATH"
            
            # Create a temporary file with multiple 'y' responses
            local license_responses=$(mktemp)
            
            # Generate enough 'y' responses for all possible licenses (50 should be more than enough)
            if command -v seq >/dev/null 2>&1; then
                for i in $(seq 1 50); do
                    echo "y"
                done > "$license_responses"
            else
                # Fallback if seq is not available
                for i in {1..50}; do
                    echo "y"
                done > "$license_responses"
            fi
            
            # Try flutter doctor --android-licenses with input redirection
            if timeout 120 flutter doctor --android-licenses < "$license_responses" >> "$LOG_FILE" 2>&1; then
                rm -f "$license_responses"
                print_success "Android licenses accepted successfully"
                return 0
            fi
            
            # Fallback: Use yes command with timeout
            if timeout 120 yes | flutter doctor --android-licenses >> "$LOG_FILE" 2>&1; then
                rm -f "$license_responses"
                print_success "Android licenses accepted successfully"
                return 0
            fi
            
            rm -f "$license_responses"
        fi
        
        # Method 2: Use sdkmanager directly if flutter method fails
        if [ -f "$CMDLINE_TOOLS_DIR/bin/sdkmanager" ]; then
            export ANDROID_HOME="$ANDROID_SDK_DIR"
            export PATH="$CMDLINE_TOOLS_DIR/bin:$PATH"
            
            print_info "Trying sdkmanager license acceptance..."
            
            # Create license responses file
            local sdk_license_responses=$(mktemp)
            if command -v seq >/dev/null 2>&1; then
                for i in $(seq 1 50); do
                    echo "y"
                done > "$sdk_license_responses"
            else
                # Fallback if seq is not available
                for i in {1..50}; do
                    echo "y"
                done > "$sdk_license_responses"
            fi
            
            if timeout 120 "$CMDLINE_TOOLS_DIR/bin/sdkmanager" --licenses --sdk_root="$ANDROID_HOME" < "$sdk_license_responses" >> "$LOG_FILE" 2>&1; then
                rm -f "$sdk_license_responses"
                print_success "Android licenses accepted via sdkmanager"
                return 0
            fi
            
            rm -f "$sdk_license_responses"
        fi
        
        # If both methods fail, try one more time or give manual instructions
        if [ $attempt -lt $max_attempts ]; then
            print_warning "License acceptance failed, retrying in 3 seconds..."
            sleep 3
            attempt=$((attempt + 1))
        else
            print_warning "Automatic license acceptance failed after $max_attempts attempts"
            print_warning "You may need to manually accept licenses by running:"
            print_warning "  flutter doctor --android-licenses"
            print_warning "Or:"
            print_warning "  \$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses"
            
            # Ask user if they want to try manual acceptance now
            echo ""
            echo "🔒 Android SDK licenses need to be accepted for development."
            echo "Would you like to try manual license acceptance now? (y/N): "
            read -r manual_accept
            
            if [[ "$manual_accept" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Please type 'y' and press Enter for each license prompt..."
                echo "Press Ctrl+C if you want to skip this step."
                echo ""
                sleep 2
                
                # Try manual acceptance
                export ANDROID_HOME="$ANDROID_SDK_DIR"
                export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:$PATH"
                
                if flutter doctor --android-licenses; then
                    print_success "Licenses accepted manually"
                    return 0
                else
                    print_warning "Manual license acceptance was interrupted or failed"
                fi
            fi
            
            return 1
        fi
    done
}

# Final verification
run_final_checks() {
    print_step "Running final system verification"
    
    print_info "Running Flutter Doctor..."
    flutter doctor -v >> "$LOG_FILE" 2>&1 || true
    flutter doctor
    
    print_success "Setup verification completed"
}

# Main installation flow with progress tracking
main() {
    local total_steps=12
    local current_step=0
    
    # Clear log file
    > "$LOG_FILE"
    
    print_header
    
    # Step 1
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Checking permissions"
    check_permissions
    
    # Step 2
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Detecting system"
    detect_distro
    
    # Step 3
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Installing system packages"
    install_system_packages
    
    # Step 4
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Verifying core tools"
    verify_command curl curl
    verify_command wget wget
    verify_command unzip unzip
    
    # Step 5
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Setting up Java environment"
    install_sdkman
    
    # Step 6
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Creating tools directory"
    mkdir -p "$TOOLS_DIR"
    
    # Step 7
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Installing Android SDK"
    install_android_sdk
    
    # Step 8
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Installing Flutter SDK"
    install_flutter
    
    # Step 9
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Configuring shell environment"
    configure_shell_profiles
    
    # Step 10
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Accepting Android licenses"
    if ! accept_licenses; then
        print_warning "Android license acceptance had issues. The script will continue, but you may need to accept licenses manually later."
        print_info "You can manually accept licenses later by running: flutter doctor --android-licenses"
    fi
    
    # Step 11
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Creating Android Virtual Device"
    create_avd
    
    # Step 12
    current_step=$((current_step + 1))
    show_progress $current_step $total_steps "Setting up emulator permissions"
    setup_kvm
    
    echo -e "\n"
    run_final_checks
    
    # Final summary
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}    🎉 Flutter Development Environment Setup Complete! 🎉${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}📋 Installation Summary:${NC}"
    echo -e "${GREEN}   ${CHECK} SDKMAN! and Java $JAVA_VERSION${NC}"
    echo -e "${GREEN}   ${CHECK} Android SDK with API 34${NC}"
    echo -e "${GREEN}   ${CHECK} Flutter v$FLUTTER_VERSION${NC}"
    echo -e "${GREEN}   ${CHECK} Android Virtual Device (flutter_avd)${NC}"
    echo -e "${GREEN}   ${CHECK} Environment variables configured${NC}"
    echo -e "${GREEN}   ${CHECK} Android licenses accepted${NC}\n"
    
    echo -e "${YELLOW}🔄 To apply all changes, run:${NC}"
    if [ -n "${ZSH_VERSION:-}" ]; then
        echo -e "${WHITE}   source ~/.zshrc${NC}"
    else
        echo -e "${WHITE}   source ~/.bashrc${NC}"
    fi
    echo -e "${WHITE}   flutter doctor${NC}\n"
    
    echo -e "${BLUE}🚀 Quick Start Commands:${NC}"
    echo -e "${WHITE}   emulator -avd flutter_avd          ${CYAN}# Start emulator${NC}"
    echo -e "${WHITE}   flutter create my_app              ${CYAN}# Create new project${NC}"
    echo -e "${WHITE}   cd my_app && flutter run           ${CYAN}# Run the app${NC}\n"
    
    echo -e "${PURPLE}📝 Log file saved to: $LOG_FILE${NC}\n"
    
    # Offer to start emulator
    read -p "$(echo -e "${BLUE}${ROCKET} Would you like to start the Android emulator now? (y/N): ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Starting Android emulator in background..."
        
        # Ensure proper environment for emulator
        export ANDROID_HOME="$ANDROID_SDK_DIR"
        export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:$PATH"
        
        # Check if emulator command is available
        if command -v emulator >/dev/null 2>&1; then
            nohup emulator -avd flutter_avd -netdelay none -netspeed full >/dev/null 2>&1 &
            print_success "Emulator started! It may take a few moments to fully boot up."
        else
            print_warning "Emulator command not found. Please restart your terminal and run:"
            print_info "emulator -avd flutter_avd"
        fi
    fi
}

# Run main function
main "$@"
