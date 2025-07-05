#!/bin/bash

set -e

TOOLS_DIR="$HOME/tools"
FLUTTER_VERSION="3.24.3"
FLUTTER_DIR="$TOOLS_DIR/flutter"
ANDROID_SDK_DIR="$TOOLS_DIR/android-sdk"
CMDLINE_TOOLS_DIR="$ANDROID_SDK_DIR/cmdline-tools/latest"

# Helper function to source appropriate shell configuration
source_shell_config() {
    local message="$1"
    if [ -n "$message" ]; then
        echo "$message"
    fi
    
    if [ -n "$ZSH_VERSION" ]; then
        source ~/.zshrc 2>/dev/null || true
    elif [ -n "$BASH_VERSION" ]; then
        source ~/.bashrc 2>/dev/null || true
    fi
}

# echo ""
echo "🎉 Flutter setup completed successfully!"
echo ""
echo "📋 Summary:"
echo "   ✅ SDKMAN! installed"
echo "   ✅ Java 17 installed via SDKMAN!"
echo "   ✅ Android SDK installed in ~/tools/android-sdk"
echo "   ✅ Flutter v$FLUTTER_VERSION installed in ~/tools/flutter"
echo "   ✅ Android licenses accepted"
echo "   ✅ AVD 'flutter_avd' created"
echo "   ✅ Environment variables configured"
echo ""
echo "🔄 To use Flutter immediately:"
if [ -n "$ZSH_VERSION" ]; then
    echo "   source ~/.zshrc"
else
    echo "   source ~/.bashrc"
fi
echo "   flutter doctor"on
spin() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\\'
    while ps -p $pid &> /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

run_step() {
    echo -n "$1..."
    shift
    ("$@") & spin
    if [ $? -ne 0 ]; then
        echo "❌ Failed: $1"
        exit 1
    else
        echo "✅ Done"
    fi
}

echo "⚙️ Setting up Flutter v$FLUTTER_VERSION in $TOOLS_DIR..."

# 1. Install system dependencies (without Java)
run_step "📦 Installing system packages" \
    sudo apt update -y && sudo apt install -y curl git unzip xz-utils zip libglu1-mesa wget qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Ensure required packages are installed
if ! command -v curl &> /dev/null; then
    echo "curl is not installed. Installing..."
    sudo apt update && sudo apt install -y curl
fi

if ! command -v wget &> /dev/null; then
    echo "wget is not installed. Installing..."
    sudo apt update && sudo apt install -y wget
fi

if ! command -v unzip &> /dev/null; then
    echo "unzip is not installed. Installing..."
    sudo apt update && sudo apt install -y unzip
fi

# 2. Install SDKMAN! and Java
if [ ! -d "$HOME/.sdkman" ]; then
    run_step "📥 Installing SDKMAN!" \
        bash -c "curl -s 'https://get.sdkman.io' | bash"
    
    echo "🔄 Sourcing SDKMAN!..."
    source "$HOME/.sdkman/bin/sdkman-init.sh"
else
    echo "📥 SDKMAN! already installed."
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Install Java 17 using SDKMAN!
if ! sdk list java | grep -q "17.*-tem.*installed"; then
    run_step "☕ Installing Java 17 via SDKMAN!" \
        bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && sdk install java 17.0.9-tem"
else
    echo "☕ Java 17 already installed via SDKMAN!."
fi

# Set Java 17 as default
run_step "🔧 Setting Java 17 as default" \
    bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && sdk default java 17.0.9-tem"

# Add SDKMAN! to shell profiles
grep -qxF 'export SDKMAN_DIR="$HOME/.sdkman"' ~/.bashrc || echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> ~/.bashrc
grep -qxF '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' ~/.bashrc || echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.bashrc

if [ -f ~/.zshrc ]; then
    grep -qxF 'export SDKMAN_DIR="$HOME/.sdkman"' ~/.zshrc || echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> ~/.zshrc
    grep -qxF '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' ~/.zshrc || echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.zshrc
fi

# Source shell profile to make SDKMAN! available
source_shell_config "🔄 Reloading shell configuration..."

# 3. Create tools directory
mkdir -p "$TOOLS_DIR"

# 4. Install Android Command Line Tools
mkdir -p "$CMDLINE_TOOLS_DIR"
if [ ! -f "$CMDLINE_TOOLS_DIR/bin/sdkmanager" ]; then
    run_step "📥 Downloading Android SDK CLI tools" \
        bash -c "wget -q https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip -O /tmp/cmdline-tools.zip && unzip -q /tmp/cmdline-tools.zip -d /tmp && mv /tmp/cmdline-tools $CMDLINE_TOOLS_DIR && rm /tmp/cmdline-tools.zip"
    
    # Fix directory structure if needed (cmdline-tools may extract to nested directory)
    if [ -d "$CMDLINE_TOOLS_DIR/cmdline-tools" ] && [ ! -f "$CMDLINE_TOOLS_DIR/bin/sdkmanager" ]; then
        echo "📁 Fixing cmdline-tools directory structure..."
        mv "$CMDLINE_TOOLS_DIR/cmdline-tools" "$CMDLINE_TOOLS_DIR-temp"
        rm -rf "$CMDLINE_TOOLS_DIR"
        mv "$CMDLINE_TOOLS_DIR-temp" "$CMDLINE_TOOLS_DIR"
    fi
else
    echo "📥 Android SDK CLI tools already exist."
fi

# 5. Set Android environment variables
# Add to both bashrc and zshrc for compatibility
grep -qxF "export ANDROID_HOME=\"$ANDROID_SDK_DIR\"" ~/.bashrc || echo "export ANDROID_HOME=\"$ANDROID_SDK_DIR\"" >> ~/.bashrc
grep -qxF 'export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' ~/.bashrc || echo 'export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' >> ~/.bashrc

if [ -f ~/.zshrc ]; then
    grep -qxF "export ANDROID_HOME=\"$ANDROID_SDK_DIR\"" ~/.zshrc || echo "export ANDROID_HOME=\"$ANDROID_SDK_DIR\"" >> ~/.zshrc
    grep -qxF 'export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' ~/.zshrc || echo 'export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' >> ~/.zshrc
fi

export ANDROID_HOME="$ANDROID_SDK_DIR"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:$PATH"

# Source shell profile to make Android SDK available
source_shell_config "🔄 Reloading shell configuration for Android SDK..."

# 6. Install Android SDK packages
run_step "📦 Installing Android SDK packages" \
    bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && \"$CMDLINE_TOOLS_DIR/bin/sdkmanager\" --sdk_root=\"$ANDROID_HOME\" --install \"platform-tools\" \"platforms;android-34\" \"build-tools;34.0.0\" \"emulator\" \"cmdline-tools;latest\" \"system-images;android-34;google_apis;x86_64\""

# 7. Download Flutter
if [ ! -d "$FLUTTER_DIR" ]; then
    run_step "📁 Downloading Flutter SDK v$FLUTTER_VERSION" \
        bash -c "wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_$FLUTTER_VERSION-stable.tar.xz -O /tmp/flutter.tar.xz && tar xf /tmp/flutter.tar.xz -C $TOOLS_DIR && rm /tmp/flutter.tar.xz"
else
    echo "📁 Flutter already exists at $FLUTTER_DIR"
fi

# 8. Add Flutter to PATH
# Add to both bashrc and zshrc for compatibility
grep -qxF "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" ~/.bashrc || echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> ~/.bashrc
if [ -f ~/.zshrc ]; then
    grep -qxF "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" ~/.zshrc || echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> ~/.zshrc
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

# Source shell profile to make Flutter available
source_shell_config "🔄 Reloading shell configuration for Flutter..."

# 9. Configure Flutter to use Android SDK
run_step "🔗 Configuring Flutter with Android SDK" \
    bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && flutter config --android-sdk \"$ANDROID_HOME\""

# 10. Run flutter doctor
run_step "🩺 Running flutter doctor" \
    bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && flutter doctor"

# 11. Accept Android licenses
run_step "📜 Accepting Android licenses" \
    bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && export ANDROID_HOME=\"$ANDROID_SDK_DIR\" && export PATH=\"$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:\$PATH\" && yes | flutter doctor --android-licenses"

# 11. Clean up any duplicate cmdline-tools directories
if [ -d "$ANDROID_SDK_DIR/cmdline-tools/latest-2" ]; then
    echo "🧹 Cleaning up duplicate cmdline-tools directories..."
    rm -rf "$ANDROID_SDK_DIR/cmdline-tools/latest-2"
fi

# 12. Create AVD
if ! "$CMDLINE_TOOLS_DIR/bin/avdmanager" list avd | grep -q flutter_avd; then
    run_step "📱 Creating AVD flutter_avd" \
        bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && export ANDROID_HOME=\"$ANDROID_SDK_DIR\" && export PATH=\"$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:\$PATH\" && echo 'no' | \"$CMDLINE_TOOLS_DIR/bin/avdmanager\" create avd -n flutter_avd -k 'system-images;android-34;google_apis;x86_64' --device 'pixel'"
else
    echo "📱 AVD flutter_avd already exists."
fi

# 13. KVM group setup
if ! groups $USER | grep -qw kvm; then
    run_step "🔐 Adding user to kvm group" \
        sudo usermod -aG kvm $USER
    echo "⚠️ Please reboot or log out/in to apply KVM group changes."
else
    echo "🔐 User is already in kvm group."
fi

# 14. Final Flutter doctor check
run_step "🩺 Final Flutter doctor check" \
    bash -c "source \"$HOME/.sdkman/bin/sdkman-init.sh\" && export ANDROID_HOME=\"$ANDROID_SDK_DIR\" && export PATH=\"$FLUTTER_DIR/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:\$PATH\" && flutter doctor"

# 15. Emulator launch
read -p "▶️ Do you want to launch the emulator now? (y/N): " launch_now
if [[ "$launch_now" =~ ^[Yy]$ ]]; then
    echo "🚀 Launching emulator..."
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:$PATH"
    nohup emulator -avd flutter_avd -netdelay none -netspeed full > /dev/null 2>&1 &
    echo "✅ Emulator launched in background."
else
    echo "ℹ️ You can manually run: emulator -avd flutter_avd"
fi

echo ""
echo "🎉 Flutter setup completed successfully!"
echo ""
echo "� Summary:"
echo "   ✅ Java 17 installed"
echo "   ✅ Android SDK installed in ~/tools/android-sdk"
echo "   ✅ Flutter v$FLUTTER_VERSION installed in ~/tools/flutter"
echo "   ✅ Android licenses accepted"
echo "   ✅ AVD 'flutter_avd' created"
echo "   ✅ Environment variables configured"
echo ""
echo "🔄 To use Flutter immediately:"
echo "   source ~/.zshrc"
echo "   flutter doctor"
echo ""
echo "🚀 To start the emulator later:"
echo "   emulator -avd flutter_avd"
echo ""
echo "📱 To create a new Flutter project:"
echo "   flutter create my_app"
echo "   cd my_app"
echo "   flutter run"
echo ""
echo "🛠️ SDKMAN! commands:"
echo "   sdk list java          # List available Java versions"
echo "   sdk install java X.Y.Z # Install specific Java version"
echo "   sdk use java X.Y.Z     # Use specific Java version for current session"
echo "   sdk default java X.Y.Z # Set default Java version"
