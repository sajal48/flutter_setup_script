#Requires -Version 5.1

<#
.SYNOPSIS
Flutter Setup Script for Windows
.DESCRIPTION
This script sets up Flutter development environment on Windows including:
- Java 17 (via Chocolatey)
- Android SDK and Command Line Tools
- Flutter SDK
- Android Virtual Device (AVD)
- Environment variables configuration

.PARAMETER FlutterVersion
The version of Flutter to install (default: 3.24.3)

.PARAMETER ToolsDir
The directory where tools will be installed (default: %USERPROFILE%\tools)

.PARAMETER JavaVersion
The Java version to install (default: 17)

.EXAMPLE
.\flutter_setup.ps1
.\flutter_setup.ps1 -FlutterVersion "3.24.3" -ToolsDir "C:\dev\tools"
#>

param(
    [string]$FlutterVersion = "3.24.3",
    [string]$ToolsDir = "C:\tools",
    [string]$JavaVersion = "17"
)

# Set execution policy and error handling
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Constants
$AndroidSdkDir = "$ToolsDir\android-sdk"
$FlutterDir = "$ToolsDir\flutter"
$JavaDir = "$ToolsDir\java\jdk$JavaVersion"
$CmdlineToolsDir = "$AndroidSdkDir\cmdline-tools\latest"

# Colors for output
$ColorGreen = "Green"
$ColorYellow = "Yellow"
$ColorRed = "Red"
$ColorBlue = "Blue"
$ColorCyan = "Cyan"

# Global variables for tracking
$StepCount = 0
$TotalSteps = 15

# Spinner function
function Show-Spinner {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Message
    )
    
    $global:StepCount++
    Write-Host "[$global:StepCount/$TotalSteps] $Message..." -NoNewline -ForegroundColor $ColorYellow
    
    $job = Start-Job -ScriptBlock $ScriptBlock
    $spinChars = @('|', '/', '-', '\')
    $i = 0
    
    while ($job.State -eq "Running") {
        Write-Host "`b$($spinChars[$i % 4])" -NoNewline -ForegroundColor $ColorYellow
        Start-Sleep -Milliseconds 200
        $i++
    }
    
    $result = Receive-Job $job -Wait
    $jobState = $job.State
    Remove-Job $job
    
    if ($jobState -eq "Completed") {
        Write-Host "`b✅ Done" -ForegroundColor $ColorGreen
        return $result
    } else {
        Write-Host "`b❌ Failed" -ForegroundColor $ColorRed
        if ($result) {
            Write-Host "Error: $result" -ForegroundColor $ColorRed
        }
        throw "Step failed: $Message"
    }
}

# Helper function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Helper function to add to PATH
function Add-ToPath {
    param([string]$Path)
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$Path*") {
        $newPath = if ($currentPath) { "$currentPath;$Path" } else { $Path }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
    }
}

# Helper function to clear and set environment variable
function Set-EnvironmentVariable {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Scope = "User"
    )
    
    [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
    Set-Variable -Name "env:$Name" -Value $Value -Scope Global
}

# Helper function to refresh environment variables
function Update-Environment {
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
}

# Helper function to test if a command exists
function Test-Command {
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Function to install Chocolatey
function Install-Chocolatey {
    if (!(Test-Command "choco")) {
        Write-Host "📦 Installing Chocolatey..." -ForegroundColor $ColorYellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Update-Environment
        return $true
    } else {
        Write-Host "📦 Chocolatey already installed." -ForegroundColor $ColorGreen
        return $false
    }
}

# Function to install Java
function Install-Java {
    if (Test-Path "$JavaDir\bin\java.exe") {
        Write-Host "☕ Java $JavaVersion already installed at $JavaDir" -ForegroundColor $ColorGreen
        return $false
    }
    
    Write-Host "☕ Installing Java $JavaVersion to $JavaDir..." -ForegroundColor $ColorYellow
    
    # Create Java directory
    New-Item -ItemType Directory -Path $JavaDir -Force | Out-Null
    
    # Download and install Java
    $javaUrl = "https://download.oracle.com/java/$JavaVersion/latest/jdk-$JavaVersion_windows-x64_bin.zip"
    $tempZip = "$env:TEMP\jdk-$JavaVersion.zip"
    
    try {
        # Try Oracle first, fallback to OpenJDK
        try {
            Invoke-WebRequest -Uri $javaUrl -OutFile $tempZip
        } catch {
            # Fallback to OpenJDK from Adoptium
            $javaUrl = "https://api.adoptium.net/v3/binary/latest/$JavaVersion/ga/windows/x64/jdk/hotspot/normal/eclipse"
            Invoke-WebRequest -Uri $javaUrl -OutFile $tempZip
        }
        
        # Extract Java
        $tempExtract = "$env:TEMP\jdk-extract"
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        
        # Find the actual JDK directory (it may have a version suffix)
        $jdkFolder = Get-ChildItem -Path $tempExtract -Directory | Where-Object { $_.Name -like "jdk*" } | Select-Object -First 1
        
        if ($jdkFolder) {
            # Move contents to our desired location
            Get-ChildItem -Path $jdkFolder.FullName | Move-Item -Destination $JavaDir -Force
        } else {
            throw "Could not find JDK folder in extracted files"
        }
        
        # Clean up
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        
        # Set JAVA_HOME and add to PATH
        Set-EnvironmentVariable -Name "JAVA_HOME" -Value $JavaDir
        Add-ToPath "$JavaDir\bin"
        Update-Environment
        
        return $true
    } catch {
        Write-Host "⚠️ Failed to download Java directly. Falling back to Chocolatey..." -ForegroundColor $ColorYellow
        
        # Fallback to Chocolatey installation
        choco install openjdk$JavaVersion -y --install-directory="$ToolsDir\java"
        
        # Find the installed JDK and move it to our desired location
        $chocoJavaDir = Get-ChildItem -Path "$ToolsDir\java" -Directory | Where-Object { $_.Name -like "*jdk*" } | Select-Object -First 1
        
        if ($chocoJavaDir -and (Test-Path "$chocoJavaDir\bin\java.exe")) {
            if ($chocoJavaDir.FullName -ne $JavaDir) {
                # Move to our desired location
                if (Test-Path $JavaDir) {
                    Remove-Item $JavaDir -Recurse -Force
                }
                Move-Item $chocoJavaDir.FullName $JavaDir -Force
            }
            
            # Set JAVA_HOME and add to PATH
            Set-EnvironmentVariable -Name "JAVA_HOME" -Value $JavaDir
            Add-ToPath "$JavaDir\bin"
            Update-Environment
            
            return $true
        } else {
            throw "Failed to install Java via Chocolatey"
        }
    }
}

# Function to install Git
function Install-Git {
    if (!(Test-Command "git")) {
        Write-Host "📥 Installing Git..." -ForegroundColor $ColorYellow
        choco install git -y
        Update-Environment
        return $true
    } else {
        Write-Host "📥 Git already installed." -ForegroundColor $ColorGreen
        return $false
    }
}

# Function to create tools directory
function New-ToolsDirectory {
    Write-Host "📁 Creating tools directory structure..." -ForegroundColor $ColorYellow
    
    # Create main tools directory
    if (!(Test-Path $ToolsDir)) {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }
    
    # Create subdirectories
    $subDirs = @(
        "$ToolsDir\java",
        "$ToolsDir\android-sdk",
        "$ToolsDir\flutter"
    )
    
    foreach ($dir in $subDirs) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Host "📁 Tools directory structure created: $ToolsDir" -ForegroundColor $ColorGreen
    return $true
}

# Function to install Android Command Line Tools
function Install-AndroidCmdlineTools {
    if (!(Test-Path "$CmdlineToolsDir\bin\sdkmanager.bat")) {
        Write-Host "📱 Downloading Android SDK CLI tools..." -ForegroundColor $ColorYellow
        
        $cmdlineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-10406996_latest.zip"
        $tempZip = "$env:TEMP\cmdline-tools.zip"
        
        # Download
        Invoke-WebRequest -Uri $cmdlineToolsUrl -OutFile $tempZip
        
        # Create directory structure
        New-Item -ItemType Directory -Path $CmdlineToolsDir -Force | Out-Null
        
        # Extract
        Expand-Archive -Path $tempZip -DestinationPath "$AndroidSdkDir\cmdline-tools" -Force
        
        # Fix directory structure if needed
        if (Test-Path "$AndroidSdkDir\cmdline-tools\cmdline-tools") {
            Move-Item "$AndroidSdkDir\cmdline-tools\cmdline-tools\*" $CmdlineToolsDir -Force
            Remove-Item "$AndroidSdkDir\cmdline-tools\cmdline-tools" -Recurse -Force
        }
        
        # Clean up
        Remove-Item $tempZip -Force
        
        return $true
    } else {
        Write-Host "📱 Android SDK CLI tools already exist." -ForegroundColor $ColorGreen
        return $false
    }
}

# Function to set Android environment variables
function Set-AndroidEnvironment {
    Write-Host "🔧 Setting Android environment variables..." -ForegroundColor $ColorYellow
    
    # Clear and set Android environment variables
    Set-EnvironmentVariable -Name "ANDROID_HOME" -Value $AndroidSdkDir
    Set-EnvironmentVariable -Name "ANDROID_SDK_ROOT" -Value $AndroidSdkDir
    
    # Add Android paths to PATH
    Add-ToPath "$AndroidSdkDir\emulator"
    Add-ToPath "$AndroidSdkDir\platform-tools"
    Add-ToPath "$AndroidSdkDir\cmdline-tools\latest\bin"
    
    # Update current session
    Update-Environment
}

# Function to install Android SDK packages
function Install-AndroidSdkPackages {
    Write-Host "📦 Installing Android SDK packages..." -ForegroundColor $ColorYellow
    
    $sdkmanager = "$CmdlineToolsDir\bin\sdkmanager.bat"
    
    # Accept licenses first
    Write-Host "📜 Accepting Android licenses..." -ForegroundColor $ColorYellow
    echo "y" | & $sdkmanager --licenses --sdk_root=$AndroidSdkDir
    
    # Install packages
    & $sdkmanager --sdk_root=$AndroidSdkDir --install "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator" "cmdline-tools;latest" "system-images;android-34;google_apis;x86_64"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Android SDK packages"
    }
}

# Function to install Flutter
function Install-Flutter {
    if (!(Test-Path "$FlutterDir\bin\flutter.bat")) {
        Write-Host "🎯 Downloading Flutter SDK v$FlutterVersion..." -ForegroundColor $ColorYellow
        
        $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"
        $tempZip = "$env:TEMP\flutter.zip"
        
        # Download
        Invoke-WebRequest -Uri $flutterUrl -OutFile $tempZip
        
        # Extract
        Expand-Archive -Path $tempZip -DestinationPath $ToolsDir -Force
        
        # Clean up
        Remove-Item $tempZip -Force
        
        return $true
    } else {
        Write-Host "🎯 Flutter already exists at $FlutterDir" -ForegroundColor $ColorGreen
        return $false
    }
}

# Function to configure Flutter
function Set-FlutterEnvironment {
    Write-Host "🔗 Configuring Flutter environment..." -ForegroundColor $ColorYellow
    
    # Add Flutter to PATH
    Add-ToPath "$FlutterDir\bin"
    Update-Environment
    
    # Configure Flutter to use Android SDK
    & "$FlutterDir\bin\flutter.bat" config --android-sdk $AndroidSdkDir
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure Flutter with Android SDK"
    }
}

# Function to run Flutter doctor
function Invoke-FlutterDoctor {
    Write-Host "🩺 Running Flutter doctor..." -ForegroundColor $ColorYellow
    
    & "$FlutterDir\bin\flutter.bat" doctor
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Flutter doctor reported issues, but continuing..." -ForegroundColor $ColorYellow
    }
}

# Function to accept Android licenses
function Accept-AndroidLicenses {
    Write-Host "📜 Accepting Android licenses..." -ForegroundColor $ColorYellow
    
    # Use flutter doctor to accept licenses
    echo "y" | & "$FlutterDir\bin\flutter.bat" doctor --android-licenses
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Some licenses may not have been accepted, but continuing..." -ForegroundColor $ColorYellow
    }
}

# Function to create AVD
function New-AndroidAVD {
    Write-Host "📱 Creating Android Virtual Device..." -ForegroundColor $ColorYellow
    
    $avdmanager = "$CmdlineToolsDir\bin\avdmanager.bat"
    
    # Check if AVD already exists
    $avdList = & $avdmanager list avd
    if ($avdList -match "flutter_avd") {
        Write-Host "📱 AVD 'flutter_avd' already exists." -ForegroundColor $ColorGreen
        return $false
    }
    
    # Create AVD
    echo "no" | & $avdmanager create avd -n flutter_avd -k "system-images;android-34;google_apis;x86_64" --device "pixel"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Android Virtual Device"
    }
    
    return $true
}

# Function to enable Hyper-V (Windows equivalent of KVM)
function Enable-HyperV {
    Write-Host "🔧 Checking virtualization support..." -ForegroundColor $ColorYellow
    
    $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
    
    if ($hyperVFeature.State -ne "Enabled") {
        Write-Host "⚠️ Hyper-V is not enabled. For better emulator performance, consider enabling it." -ForegroundColor $ColorYellow
        Write-Host "   Run as Administrator: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All" -ForegroundColor $ColorYellow
        return $false
    } else {
        Write-Host "🔧 Hyper-V is already enabled." -ForegroundColor $ColorGreen
        return $true
    }
}

# Function to final Flutter doctor check
function Invoke-FinalFlutterDoctor {
    Write-Host "🩺 Final Flutter doctor check..." -ForegroundColor $ColorYellow
    
    & "$FlutterDir\bin\flutter.bat" doctor
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Flutter doctor reported some issues. Check the output above." -ForegroundColor $ColorYellow
    }
}

# Function to prompt for emulator launch
function Start-EmulatorPrompt {
    Write-Host ""
    $launch = Read-Host "▶️ Do you want to launch the emulator now? (y/N)"
    
    if ($launch -match "^[Yy]$") {
        Write-Host "🚀 Launching emulator..." -ForegroundColor $ColorYellow
        
        Start-Process -FilePath "$AndroidSdkDir\emulator\emulator.exe" -ArgumentList "-avd", "flutter_avd", "-netdelay", "none", "-netspeed", "full" -WindowStyle Hidden
        
        Write-Host "✅ Emulator launched in background." -ForegroundColor $ColorGreen
    } else {
        Write-Host "ℹ️ You can manually run: emulator -avd flutter_avd" -ForegroundColor $ColorBlue
    }
}

# Function to display success summary
function Show-CompletionSummary {
    Write-Host ""
    Write-Host "🎉 Flutter setup completed successfully!" -ForegroundColor $ColorGreen
    Write-Host ""
    Write-Host "📋 Summary:" -ForegroundColor $ColorBlue
    Write-Host "   ✅ Chocolatey installed" -ForegroundColor $ColorGreen
    Write-Host "   ✅ Java $JavaVersion installed in $JavaDir" -ForegroundColor $ColorGreen
    Write-Host "   ✅ Git installed" -ForegroundColor $ColorGreen
    Write-Host "   ✅ Android SDK installed in $AndroidSdkDir" -ForegroundColor $ColorGreen
    Write-Host "   ✅ Flutter v$FlutterVersion installed in $FlutterDir" -ForegroundColor $ColorGreen
    Write-Host "   ✅ Android licenses accepted" -ForegroundColor $ColorGreen
    Write-Host "   ✅ AVD 'flutter_avd' created" -ForegroundColor $ColorGreen
    Write-Host "   ✅ Environment variables configured" -ForegroundColor $ColorGreen
    Write-Host ""
    Write-Host "🔧 Environment Variables Set:" -ForegroundColor $ColorBlue
    Write-Host "   JAVA_HOME = $JavaDir" -ForegroundColor $ColorYellow
    Write-Host "   ANDROID_HOME = $AndroidSdkDir" -ForegroundColor $ColorYellow
    Write-Host "   ANDROID_SDK_ROOT = $AndroidSdkDir" -ForegroundColor $ColorYellow
    Write-Host ""
    Write-Host "🔄 To use Flutter immediately:" -ForegroundColor $ColorBlue
    Write-Host "   Restart your terminal or VS Code" -ForegroundColor $ColorYellow
    Write-Host "   flutter doctor" -ForegroundColor $ColorYellow
    Write-Host ""
    Write-Host "🚀 To start the emulator later:" -ForegroundColor $ColorBlue
    Write-Host "   emulator -avd flutter_avd" -ForegroundColor $ColorYellow
    Write-Host ""
    Write-Host "📱 To create a new Flutter project:" -ForegroundColor $ColorBlue
    Write-Host "   flutter create my_app" -ForegroundColor $ColorYellow
    Write-Host "   cd my_app" -ForegroundColor $ColorYellow
    Write-Host "   flutter run" -ForegroundColor $ColorYellow
    Write-Host ""
    Write-Host "🛠️ Chocolatey commands:" -ForegroundColor $ColorBlue
    Write-Host "   choco list --local-only      # List installed packages" -ForegroundColor $ColorYellow
    Write-Host "   choco upgrade all            # Update all packages" -ForegroundColor $ColorYellow
    Write-Host "   choco install package-name   # Install new package" -ForegroundColor $ColorYellow
    Write-Host ""
}

# Main execution
try {
    Write-Host "⚙️ Setting up Flutter v$FlutterVersion for Windows..." -ForegroundColor $ColorCyan
    Write-Host "📁 All tools will be installed in: $ToolsDir" -ForegroundColor $ColorCyan
    Write-Host "☕ Java will be installed in: $JavaDir" -ForegroundColor $ColorCyan
    Write-Host "📱 Android SDK will be installed in: $AndroidSdkDir" -ForegroundColor $ColorCyan
    Write-Host "🎯 Flutter will be installed in: $FlutterDir" -ForegroundColor $ColorCyan
    Write-Host ""
    
    # Check if running as administrator for some operations
    if (!(Test-Administrator)) {
        Write-Host "⚠️ Running without administrator privileges. Some features may not work optimally." -ForegroundColor $ColorYellow
        Write-Host "   Consider running as Administrator for better Hyper-V support." -ForegroundColor $ColorYellow
        Write-Host ""
    }
    
    # Step 1: Install Chocolatey
    Show-Spinner -ScriptBlock { Install-Chocolatey } -Message "Installing Chocolatey"
    
    # Step 2: Install Java
    Show-Spinner -ScriptBlock { Install-Java } -Message "Installing Java $JavaVersion"
    
    # Step 3: Install Git
    Show-Spinner -ScriptBlock { Install-Git } -Message "Installing Git"
    
    # Step 4: Create tools directory
    Show-Spinner -ScriptBlock { New-ToolsDirectory } -Message "Creating tools directory"
    
    # Step 5: Install Android Command Line Tools
    Show-Spinner -ScriptBlock { Install-AndroidCmdlineTools } -Message "Installing Android SDK CLI tools"
    
    # Step 6: Set Android environment variables
    Show-Spinner -ScriptBlock { Set-AndroidEnvironment } -Message "Setting Android environment variables"
    
    # Step 7: Install Android SDK packages
    Show-Spinner -ScriptBlock { Install-AndroidSdkPackages } -Message "Installing Android SDK packages"
    
    # Step 8: Install Flutter
    Show-Spinner -ScriptBlock { Install-Flutter } -Message "Installing Flutter SDK v$FlutterVersion"
    
    # Step 9: Configure Flutter environment
    Show-Spinner -ScriptBlock { Set-FlutterEnvironment } -Message "Configuring Flutter environment"
    
    # Step 10: Run Flutter doctor
    Show-Spinner -ScriptBlock { Invoke-FlutterDoctor } -Message "Running Flutter doctor"
    
    # Step 11: Accept Android licenses
    Show-Spinner -ScriptBlock { Accept-AndroidLicenses } -Message "Accepting Android licenses"
    
    # Step 12: Create AVD
    Show-Spinner -ScriptBlock { New-AndroidAVD } -Message "Creating Android Virtual Device"
    
    # Step 13: Check Hyper-V
    Show-Spinner -ScriptBlock { Enable-HyperV } -Message "Checking virtualization support"
    
    # Step 14: Final Flutter doctor check
    Show-Spinner -ScriptBlock { Invoke-FinalFlutterDoctor } -Message "Final Flutter doctor check"
    
    # Step 15: Prompt for emulator launch
    $global:StepCount++
    Write-Host "[$global:StepCount/$TotalSteps] Emulator launch prompt..." -ForegroundColor $ColorYellow
    Start-EmulatorPrompt
    
    # Show completion summary
    Show-CompletionSummary
    
} catch {
    Write-Host ""
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor $ColorRed
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor $ColorRed
    exit 1
}
