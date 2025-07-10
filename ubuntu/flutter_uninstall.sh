#!/bin/bash

# Flutter Development Environment Uninstaller for Ubuntu
# This script removes all components installed by flutter_setup.sh

set -e

TOOLS_DIR="$HOME/tools"
FLUTTER_DIR="$TOOLS_DIR/flutter"
ANDROID_SDK_DIR="$TOOLS_DIR/android-sdk"
SDKMAN_DIR="$HOME/.sdkman"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to print colored output
print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Helper function to remove lines from shell config files
remove_from_shell_config() {
    local pattern="$1"
    local file="$2"
    
    if [ -f "$file" ]; then
        # Create a backup
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        # Remove lines matching the pattern
        grep -v "$pattern" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        print_success "Removed Flutter/Android/SDKMAN entries from $file"
    fi
}

echo -e "${BLUE}🗑️ Flutter Development Environment Uninstaller${NC}"
echo ""
print_warning "This script will remove:"
echo "   - Flutter SDK (~/$TOOLS_DIR/flutter)"
echo "   - Android SDK (~/$TOOLS_DIR/android-sdk)"
echo "   - SDKMAN! and all Java versions installed via SDKMAN (~/.sdkman)"
echo "   - Environment variables from ~/.bashrc and ~/.zshrc"
echo "   - Android Virtual Devices (AVDs)"
echo ""

read -p "Are you sure you want to proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
print_step "🚀 Starting uninstall process..."

# 1. Stop any running emulators
print_step "🛑 Stopping Android emulators..."
if command -v adb &> /dev/null; then
    adb devices | grep emulator | cut -f1 | while read line; do adb -s $line emu kill; done 2>/dev/null || true
    print_success "Stopped running emulators"
else
    print_warning "ADB not found, skipping emulator shutdown"
fi

# 2. Remove Flutter directory
if [ -d "$FLUTTER_DIR" ]; then
    print_step "🗑️ Removing Flutter SDK..."
    rm -rf "$FLUTTER_DIR"
    print_success "Flutter SDK removed"
else
    print_warning "Flutter SDK directory not found"
fi

# 3. Remove Android SDK directory
if [ -d "$ANDROID_SDK_DIR" ]; then
    print_step "🗑️ Removing Android SDK..."
    rm -rf "$ANDROID_SDK_DIR"
    print_success "Android SDK removed"
else
    print_warning "Android SDK directory not found"
fi

# 4. Remove entire tools directory if empty
if [ -d "$TOOLS_DIR" ] && [ -z "$(ls -A "$TOOLS_DIR")" ]; then
    print_step "🗑️ Removing empty tools directory..."
    rmdir "$TOOLS_DIR"
    print_success "Tools directory removed"
elif [ -d "$TOOLS_DIR" ]; then
    print_warning "Tools directory not empty, leaving other contents intact"
fi

# 5. Remove SDKMAN! and all Java installations
if [ -d "$SDKMAN_DIR" ]; then
    print_step "🗑️ Removing SDKMAN! and all Java installations..."
    rm -rf "$SDKMAN_DIR"
    print_success "SDKMAN! and Java installations removed"
else
    print_warning "SDKMAN! directory not found"
fi

# 5.1. Remove system-installed Java packages (if any)
if command -v java &> /dev/null || dpkg -l | grep -q openjdk; then
    print_step "☕ Removing system-installed Java packages..."
    sudo apt remove --autoremove -y openjdk-*-jdk openjdk-*-jre openjdk-*-jre-headless 2>/dev/null || true
    print_success "System Java packages removed"
else
    print_warning "No system Java packages found"
fi

# 6. Remove Android AVD directory
AVD_DIR="$HOME/.android"
if [ -d "$AVD_DIR" ]; then
    print_step "🗑️ Removing Android Virtual Devices..."
    rm -rf "$AVD_DIR"
    print_success "Android AVDs removed"
else
    print_warning "Android AVD directory not found"
fi

# 7. Remove Flutter configuration directory
FLUTTER_CONFIG_DIR="$HOME/.flutter"
if [ -d "$FLUTTER_CONFIG_DIR" ]; then
    print_step "🗑️ Removing Flutter configuration..."
    rm -rf "$FLUTTER_CONFIG_DIR"
    print_success "Flutter configuration removed"
else
    print_warning "Flutter configuration directory not found"
fi

# 8. Remove Dart Pub cache
DART_PUB_CACHE="$HOME/.pub-cache"
if [ -d "$DART_PUB_CACHE" ]; then
    print_step "🗑️ Removing Dart Pub cache..."
    rm -rf "$DART_PUB_CACHE"
    print_success "Dart Pub cache removed"
else
    print_warning "Dart Pub cache directory not found"
fi

# 9. Remove environment variables from shell configuration files
print_step "🗑️ Cleaning up shell configuration files..."

# Remove Flutter paths
remove_from_shell_config "export PATH.*flutter.*bin" ~/.bashrc
remove_from_shell_config "export PATH.*flutter.*bin" ~/.zshrc

# Remove Android environment variables
remove_from_shell_config "export ANDROID_HOME" ~/.bashrc
remove_from_shell_config "export ANDROID_HOME" ~/.zshrc
remove_from_shell_config "export PATH.*ANDROID_HOME" ~/.bashrc
remove_from_shell_config "export PATH.*ANDROID_HOME" ~/.zshrc

# Remove SDKMAN configuration
remove_from_shell_config "export SDKMAN_DIR" ~/.bashrc
remove_from_shell_config "export SDKMAN_DIR" ~/.zshrc
remove_from_shell_config "sdkman-init.sh" ~/.bashrc
remove_from_shell_config "sdkman-init.sh" ~/.zshrc

# 10. Clean up temporary files
print_step "🧹 Cleaning up temporary files..."
rm -f /tmp/flutter.tar.xz /tmp/cmdline-tools.zip 2>/dev/null || true
print_success "Temporary files cleaned"

# 11. Optional: Remove system packages that were installed
echo ""
print_step "📦 System packages cleanup (optional)..."
echo "The following system packages were installed during Flutter setup:"
echo "   - curl, wget, unzip, xz-utils, zip, libglu1-mesa"
echo "   - qemu-kvm, libvirt-daemon-system, libvirt-clients, bridge-utils"
echo ""
read -p "Do you want to remove these system packages? (y/N): " remove_packages
if [[ "$remove_packages" =~ ^[Yy]$ ]]; then
    print_step "🗑️ Removing system packages..."
    sudo apt remove --autoremove -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils xz-utils zip libglu1-mesa 2>/dev/null || true
    print_success "System packages removed"
    print_warning "Note: curl, wget, unzip were kept as they are commonly used by other applications"
else
    print_warning "System packages kept (recommended for other applications)"
fi

echo ""
print_success "🎉 Flutter development environment uninstall completed!"
echo ""
print_step "📋 Summary of actions taken:"
echo "   ✅ Flutter SDK removed"
echo "   ✅ Android SDK removed"
echo "   ✅ SDKMAN! and Java installations removed"
echo "   ✅ Android Virtual Devices removed"
echo "   ✅ Flutter and Dart configuration removed"
echo "   ✅ Environment variables cleaned from shell configs"
echo ""
print_warning "⚠️ Important notes:"
echo "   - Shell configuration backups created with timestamp"
echo "   - You may need to restart your terminal or reload shell configs"
echo "   - If you removed system packages, some other applications might be affected"
echo ""
print_step "🔄 To reload your shell configuration:"
if [ -n "$ZSH_VERSION" ]; then
    echo "   source ~/.zshrc"
else
    echo "   source ~/.bashrc"
fi
echo ""
