#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Flutter Setup Script v2.0 for Windows - Enhanced Edition
.DESCRIPTION
This advanced script sets up a complete Flutter development environment on Windows with:
- Enhanced progress tracking and visual feedback
- Better error handling and fault tolerance
- Silent background operations with progress bars
- Automatic retry logic for failed operations
- Comprehensive logging and debugging
- Cross-architecture support (x64/ARM64)
- Hyper-V and WSL2 optimization
- Multiple Java distribution support

.PARAMETER FlutterVersion
The version of Flutter to install (default: 3.24.3)

.PARAMETER ToolsDir
The directory where tools will be installed (default: C:\dev\tools)

.PARAMETER JavaVersion
The Java version to install (default: 17)

.PARAMETER UseChocolatey
Whether to use Chocolatey for package management (default: true)

.PARAMETER LogLevel
Logging level: Silent, Normal, Verbose (default: Normal)

.EXAMPLE
.\flutter_setup_v2.ps1
.\flutter_setup_v2.ps1 -FlutterVersion "3.24.3" -ToolsDir "C:\dev\tools" -LogLevel Verbose
.\flutter_setup_v2.ps1 -JavaVersion 21 -UseChocolatey $false
#>

param(
    [string]$FlutterVersion = "3.24.3",
    [string]$ToolsDir = "C:\dev\tools",
    [string]$JavaVersion = "17",
    [bool]$UseChocolatey = $true,
    [ValidateSet("Silent", "Normal", "Verbose")]
    [string]$LogLevel = "Normal"
)

# Enhanced error handling and execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$VerbosePreference = if ($LogLevel -eq "Verbose") { "Continue" } else { "SilentlyContinue" }

# Constants and Configuration
$Script:Config = @{
    AndroidSdkDir = "$ToolsDir\android-sdk"
    FlutterDir = "$ToolsDir\flutter"
    JavaDir = "$ToolsDir\java\jdk$JavaVersion"
    CmdlineToolsDir = "$ToolsDir\android-sdk\cmdline-tools\latest"
    LogFile = "$env:TEMP\flutter_setup_v2.log"
    MaxRetries = 3
    RetryDelaySeconds = 2
}

# Enhanced Color Scheme
$Script:Colors = @{
    Primary = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Blue"
    Progress = "Magenta"
    Highlight = "White"
    Dim = "DarkGray"
}

# Unicode Icons for better visual feedback
$Script:Icons = @{
    Success = "✅"
    Error = "❌"
    Warning = "⚠️"
    Info = "ℹ️"
    Progress = "⚙️"
    Download = "📥"
    Install = "📦"
    Configure = "🔧"
    Check = "🔍"
    Launch = "🚀"
    Java = "☕"
    Android = "📱"
    Flutter = "🎯"
    Folder = "📁"
    Network = "🌐"
    Security = "🔐"
    Performance = "⚡"
}

# Global Progress Tracking
$Script:Progress = @{
    Current = 0
    Total = 16
    StartTime = Get-Date
}

#region Logging and Output Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $Script:Config.LogFile -Value $logEntry -Encoding UTF8
    
    # Write to console if not suppressed
    if (-not $NoConsole -and $LogLevel -ne "Silent") {
        $color = switch ($Level) {
            "ERROR" { $Script:Colors.Error }
            "WARN" { $Script:Colors.Warning }
            "DEBUG" { $Script:Colors.Dim }
            default { $Script:Colors.Info }
        }
        
        if ($LogLevel -eq "Verbose" -or $Level -ne "DEBUG") {
            Write-Host $logEntry -ForegroundColor $color
        }
    }
}

function Write-Header {
    param([string]$Title)
    
    $border = "═" * 80
    $padding = " " * ((80 - $Title.Length) / 2)
    
    Write-Host ""
    Write-Host $border -ForegroundColor $Script:Colors.Primary
    Write-Host "$padding$Title$padding" -ForegroundColor $Script:Colors.Highlight
    Write-Host $border -ForegroundColor $Script:Colors.Primary
    Write-Host ""
}

function Write-Step {
    param(
        [string]$Message,
        [string]$Icon = $Script:Icons.Progress
    )
    
    $Script:Progress.Current++
    $percentage = [math]::Round(($Script:Progress.Current / $Script:Progress.Total) * 100, 1)
    
    $stepInfo = "[$($Script:Progress.Current)/$($Script:Progress.Total)] ($percentage%)"
    Write-Host "$stepInfo $Icon $Message" -ForegroundColor $Script:Colors.Primary
    Write-Log -Message "STEP $($Script:Progress.Current): $Message" -Level "INFO"
}

function Write-Success {
    param([string]$Message)
    Write-Host "$($Script:Icons.Success) $Message" -ForegroundColor $Script:Colors.Success
    Write-Log -Message $Message -Level "INFO"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$($Script:Icons.Warning) $Message" -ForegroundColor $Script:Colors.Warning
    Write-Log -Message $Message -Level "WARN"
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "$($Script:Icons.Error) $Message" -ForegroundColor $Script:Colors.Error
    Write-Log -Message $Message -Level "ERROR"
}

function Write-Info {
    param([string]$Message)
    if ($LogLevel -ne "Silent") {
        Write-Host "$($Script:Icons.Info) $Message" -ForegroundColor $Script:Colors.Info
    }
    Write-Log -Message $Message -Level "INFO"
}

#endregion

#region Progress and Animation Functions

function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity,
        [string]$Status = "Processing..."
    )
    
    $percentComplete = [math]::Round(($Current / $Total) * 100, 1)
    
    Write-Progress -Activity $Activity -Status "$Status ($percentComplete%)" -PercentComplete $percentComplete
}

function Show-EnhancedSpinner {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Message,
        [int]$MaxRetries = $Script:Config.MaxRetries
    )
    
    $attempt = 1
    
    while ($attempt -le $MaxRetries) {
        try {
            $statusMsg = if ($attempt -gt 1) { "$Message (Attempt $attempt/$MaxRetries)" } else { $Message }
            
            Write-Host "   " -NoNewline
            Write-Host $statusMsg -NoNewline -ForegroundColor $Script:Colors.Progress
            
            # Create background job for the operation
            $job = Start-Job -ScriptBlock $ScriptBlock
            
            # Enhanced spinner characters
            $spinChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
            $i = 0
            
            # Show spinner while job is running
            while ($job.State -eq "Running") {
                Write-Host "`b`b`b$($spinChars[$i % $spinChars.Length]) " -NoNewline -ForegroundColor $Script:Colors.Progress
                Start-Sleep -Milliseconds 150
                $i++
            }
            
            # Get job results
            $result = Receive-Job $job -Wait -ErrorAction Stop
            $jobState = $job.State
            Remove-Job $job
            
            if ($jobState -eq "Completed") {
                Write-Host "`b`b`b$($Script:Icons.Success)" -ForegroundColor $Script:Colors.Success
                Write-Log -Message "SUCCESS: $Message" -Level "INFO"
                return $result
            } else {
                throw "Job completed with state: $jobState"
            }
            
        } catch {
            Write-Host "`b`b`b$($Script:Icons.Error)" -ForegroundColor $Script:Colors.Error
            Write-Log -Message "FAILED: $Message - $($_.Exception.Message)" -Level "ERROR"
            
            if ($attempt -lt $MaxRetries) {
                Write-Warning "Retrying in $($Script:Config.RetryDelaySeconds) seconds..."
                Start-Sleep -Seconds $Script:Config.RetryDelaySeconds
                $attempt++
            } else {
                throw "Operation failed after $MaxRetries attempts: $($_.Exception.Message)"
            }
        }
    }
}

#endregion

#region System Check Functions

function Test-SystemRequirements {
    Write-Step "Checking system requirements" $Script:Icons.Check
    
    $requirements = @()
    
    # Check Windows version
    $winVersion = [System.Environment]::OSVersion.Version
    if ($winVersion.Major -lt 10) {
        $requirements += "Windows 10 or later required (found: $($winVersion.ToString()))"
    }
    
    # Check available disk space (minimum 10GB)
    $drive = (Get-Item $ToolsDir.Substring(0,1) -ErrorAction SilentlyContinue) ?? (Get-Item "C:")
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($drive.Name):'").FreeSpace
    $freeSpaceGB = [math]::Round($freeSpace / 1GB, 2)
    
    if ($freeSpaceGB -lt 10) {
        $requirements += "At least 10GB free disk space required (found: $freeSpaceGB GB)"
    }
    
    # Check memory (minimum 8GB recommended)
    $totalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
    $totalMemoryGB = [math]::Round($totalMemory / 1GB, 2)
    
    if ($totalMemoryGB -lt 8) {
        Write-Warning "Less than 8GB RAM detected ($totalMemoryGB GB). Performance may be affected."
    }
    
    # Check architecture
    $architecture = $env:PROCESSOR_ARCHITECTURE
    Write-Info "System Architecture: $architecture"
    
    if ($requirements.Count -gt 0) {
        throw "System requirements not met: $($requirements -join '; ')"
    }
    
    Write-Success "System requirements verified (Free Space: $freeSpaceGB GB, RAM: $totalMemoryGB GB)"
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-InternetConnection {
    Write-Step "Testing internet connectivity" $Script:Icons.Network
    
    $testUrls = @(
        "https://storage.googleapis.com",
        "https://dl.google.com",
        "https://github.com",
        "https://api.adoptium.net"
    )
    
    $failedConnections = @()
    
    foreach ($url in $testUrls) {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -UseBasicParsing
            Write-Log -Message "Connection test successful: $url" -Level "DEBUG"
        } catch {
            $failedConnections += $url
            Write-Log -Message "Connection test failed: $url - $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    if ($failedConnections.Count -eq $testUrls.Count) {
        throw "No internet connectivity detected. Please check your network connection."
    } elseif ($failedConnections.Count -gt 0) {
        Write-Warning "Some services may be unreachable: $($failedConnections -join ', ')"
    }
    
    Write-Success "Internet connectivity verified"
}

#endregion

#region Environment Management Functions

function Set-EnvironmentVariable {
    param(
        [string]$Name,
        [string]$Value,
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )
    
    try {
        [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        Set-Variable -Name "env:$Name" -Value $Value -Scope Global
        Write-Log -Message "Environment variable set: $Name = $Value (Scope: $Scope)" -Level "DEBUG"
    } catch {
        Write-Log -Message "Failed to set environment variable $Name : $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Add-ToPath {
    param(
        [string]$Path,
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", $Scope)
    
    if ($currentPath -notlike "*$Path*") {
        $newPath = if ($currentPath) { "$currentPath;$Path" } else { $Path }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, $Scope)
        
        # Update current session PATH
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        
        Write-Log -Message "Added to PATH: $Path" -Level "DEBUG"
    } else {
        Write-Log -Message "Path already exists: $Path" -Level "DEBUG"
    }
}

function Update-Environment {
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Log -Message "Environment variables refreshed" -Level "DEBUG"
}

#endregion

#region Package Management Functions

function Install-Chocolatey {
    if (!(Get-Command "choco" -ErrorAction SilentlyContinue)) {
        Write-Step "Installing Chocolatey package manager" $Script:Icons.Install
        
        Show-EnhancedSpinner -Message "Installing Chocolatey" -ScriptBlock {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        }
        
        Update-Environment
        Write-Success "Chocolatey installed successfully"
        return $true
    } else {
        Write-Info "Chocolatey already installed"
        return $false
    }
}

function Install-WingetIfAvailable {
    Write-Step "Checking for Windows Package Manager (winget)" $Script:Icons.Check
    
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-Success "Windows Package Manager (winget) is available"
        return $true
    } else {
        Write-Info "Windows Package Manager (winget) not available, using alternative methods"
        return $false
    }
}

#endregion

#region Java Installation Functions

function Get-JavaDistributions {
    return @{
        "Adoptium" = @{
            "17" = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"
            "21" = "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse"
        }
        "Microsoft" = @{
            "17" = "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip"
            "21" = "https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.zip"
        }
    }
}

function Install-Java {
    if (Test-Path "$($Script:Config.JavaDir)\bin\java.exe") {
        Write-Info "Java $JavaVersion already installed at $($Script:Config.JavaDir)"
        return $false
    }
    
    Write-Step "Installing Java $JavaVersion JDK" $Script:Icons.Java
    
    if ($UseChocolatey -and (Get-Command "choco" -ErrorAction SilentlyContinue)) {
        return Install-JavaViaChocolatey
    } else {
        return Install-JavaDirect
    }
}

function Install-JavaViaChocolatey {
    Show-EnhancedSpinner -Message "Installing Java $JavaVersion via Chocolatey" -ScriptBlock {
        $javaPackage = switch ($JavaVersion) {
            "17" { "openjdk17" }
            "21" { "openjdk21" }
            default { "openjdk" }
        }
        
        choco install $javaPackage -y --install-directory="$ToolsDir\java" --force
        
        if ($LASTEXITCODE -ne 0) {
            throw "Chocolatey Java installation failed with exit code $LASTEXITCODE"
        }
    }
    
    # Find and configure the installed JDK
    $installedJdk = Get-ChildItem -Path "$ToolsDir\java" -Directory -Recurse | 
                   Where-Object { $_.Name -like "*jdk*" -and (Test-Path "$($_.FullName)\bin\java.exe") } | 
                   Select-Object -First 1
    
    if ($installedJdk) {
        if ($installedJdk.FullName -ne $Script:Config.JavaDir) {
            if (Test-Path $Script:Config.JavaDir) {
                Remove-Item $Script:Config.JavaDir -Recurse -Force
            }
            Move-Item $installedJdk.FullName $Script:Config.JavaDir -Force
        }
        
        Set-JavaEnvironment
        Write-Success "Java $JavaVersion installed via Chocolatey"
        return $true
    } else {
        throw "Java installation via Chocolatey completed but JDK not found"
    }
}

function Install-JavaDirect {
    $distributions = Get-JavaDistributions
    $tempZip = "$env:TEMP\jdk-$JavaVersion.zip"
    
    foreach ($distName in $distributions.Keys) {
        try {
            $distUrls = $distributions[$distName]
            if (-not $distUrls.ContainsKey($JavaVersion)) {
                continue
            }
            
            $javaUrl = $distUrls[$JavaVersion]
            
            Show-EnhancedSpinner -Message "Downloading Java $JavaVersion from $distName" -ScriptBlock {
                Invoke-WebRequest -Uri $javaUrl -OutFile $tempZip -UseBasicParsing
            }
            
            Show-EnhancedSpinner -Message "Extracting Java JDK" -ScriptBlock {
                New-Item -ItemType Directory -Path $Script:Config.JavaDir -Force | Out-Null
                
                $tempExtract = "$env:TEMP\jdk-extract"
                if (Test-Path $tempExtract) {
                    Remove-Item $tempExtract -Recurse -Force
                }
                
                Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
                
                # Find the JDK directory
                $jdkFolder = Get-ChildItem -Path $tempExtract -Directory | 
                           Where-Object { $_.Name -like "*jdk*" -or (Test-Path "$($_.FullName)\bin\java.exe") } | 
                           Select-Object -First 1
                
                if ($jdkFolder) {
                    Get-ChildItem -Path $jdkFolder.FullName | Move-Item -Destination $Script:Config.JavaDir -Force
                } else {
                    # If no subdirectory, the archive might extract directly
                    Get-ChildItem -Path $tempExtract | Move-Item -Destination $Script:Config.JavaDir -Force
                }
                
                # Cleanup
                Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            Set-JavaEnvironment
            Write-Success "Java $JavaVersion installed from $distName"
            return $true
            
        } catch {
            Write-Warning "Failed to install Java from $distName : $($_.Exception.Message)"
            continue
        }
    }
    
    throw "Failed to install Java $JavaVersion from any distribution"
}

function Set-JavaEnvironment {
    Set-EnvironmentVariable -Name "JAVA_HOME" -Value $Script:Config.JavaDir
    Add-ToPath "$($Script:Config.JavaDir)\bin"
    Update-Environment
}

#endregion

#region Development Tools Installation

function Install-Git {
    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-Info "Git already installed"
        return $false
    }
    
    Write-Step "Installing Git version control" $Script:Icons.Install
    
    if ($UseChocolatey -and (Get-Command "choco" -ErrorAction SilentlyContinue)) {
        Show-EnhancedSpinner -Message "Installing Git via Chocolatey" -ScriptBlock {
            choco install git -y
            if ($LASTEXITCODE -ne 0) {
                throw "Git installation failed with exit code $LASTEXITCODE"
            }
        }
    } else {
        Show-EnhancedSpinner -Message "Installing Git via direct download" -ScriptBlock {
            $gitUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.42.0.2-64-bit.exe"
            $gitInstaller = "$env:TEMP\git-installer.exe"
            
            Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
            Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
            
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
        }
    }
    
    Update-Environment
    Write-Success "Git installed successfully"
    return $true
}

function New-ToolsDirectory {
    Write-Step "Creating development tools directory structure" $Script:Icons.Folder
    
    $directories = @(
        $ToolsDir,
        "$ToolsDir\java",
        "$ToolsDir\android-sdk",
        "$ToolsDir\flutter",
        "$ToolsDir\temp"
    )
    
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log -Message "Created directory: $dir" -Level "DEBUG"
        }
    }
    
    Write-Success "Tools directory structure created: $ToolsDir"
}

#endregion

#region Android SDK Functions

function Install-AndroidSdk {
    Write-Step "Setting up Android SDK" $Script:Icons.Android
    
    if (!(Test-Path "$($Script:Config.CmdlineToolsDir)\bin\sdkmanager.bat")) {
        Install-AndroidCmdlineTools
    } else {
        Write-Info "Android Command Line Tools already installed"
    }
    
    Set-AndroidEnvironment
    Install-AndroidSdkPackages
}

function Install-AndroidCmdlineTools {
    Show-EnhancedSpinner -Message "Downloading Android SDK Command Line Tools" -ScriptBlock {
        $cmdlineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-10406996_latest.zip"
        $tempZip = "$env:TEMP\cmdline-tools.zip"
        
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($cmdlineToolsUrl, $tempZip)
        
        # Create directory structure
        New-Item -ItemType Directory -Path $Script:Config.CmdlineToolsDir -Force | Out-Null
        
        # Extract
        Expand-Archive -Path $tempZip -DestinationPath "$($Script:Config.AndroidSdkDir)\cmdline-tools" -Force
        
        # Fix directory structure if needed
        if (Test-Path "$($Script:Config.AndroidSdkDir)\cmdline-tools\cmdline-tools") {
            $items = Get-ChildItem -Path "$($Script:Config.AndroidSdkDir)\cmdline-tools\cmdline-tools"
            $items | Move-Item -Destination $Script:Config.CmdlineToolsDir -Force
            Remove-Item "$($Script:Config.AndroidSdkDir)\cmdline-tools\cmdline-tools" -Recurse -Force
        }
        
        # Clean up
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        
        if (!(Test-Path "$($Script:Config.CmdlineToolsDir)\bin\sdkmanager.bat")) {
            throw "Android Command Line Tools installation failed - sdkmanager not found"
        }
    }
    
    Write-Success "Android Command Line Tools installed"
}

function Set-AndroidEnvironment {
    Write-Step "Configuring Android environment variables" $Script:Icons.Configure
    
    Set-EnvironmentVariable -Name "ANDROID_HOME" -Value $Script:Config.AndroidSdkDir
    Set-EnvironmentVariable -Name "ANDROID_SDK_ROOT" -Value $Script:Config.AndroidSdkDir
    
    # Add Android paths to PATH
    Add-ToPath "$($Script:Config.AndroidSdkDir)\emulator"
    Add-ToPath "$($Script:Config.AndroidSdkDir)\platform-tools"
    Add-ToPath "$($Script:Config.CmdlineToolsDir)\bin"
    
    Update-Environment
    Write-Success "Android environment configured"
}

function Install-AndroidSdkPackages {
    Show-EnhancedSpinner -Message "Installing Android SDK packages" -ScriptBlock {
        $sdkmanager = "$($Script:Config.CmdlineToolsDir)\bin\sdkmanager.bat"
        
        # Accept licenses first
        $acceptLicenses = "y" * 10
        $acceptLicenses | & $sdkmanager --licenses --sdk_root=$Script:Config.AndroidSdkDir
        
        # Install essential packages
        $packages = @(
            "platform-tools",
            "platforms;android-34",
            "build-tools;34.0.0",
            "emulator",
            "cmdline-tools;latest",
            "system-images;android-34;google_apis;x86_64"
        )
        
        foreach ($package in $packages) {
            & $sdkmanager --sdk_root=$Script:Config.AndroidSdkDir --install $package
            if ($LASTEXITCODE -ne 0) {
                Write-Log -Message "Warning: Failed to install package $package" -Level "WARN"
            }
        }
    }
    
    Write-Success "Android SDK packages installed"
}

#endregion

#region Flutter Installation Functions

function Install-Flutter {
    if (Test-Path "$($Script:Config.FlutterDir)\bin\flutter.bat") {
        Write-Info "Flutter already installed at $($Script:Config.FlutterDir)"
        return $false
    }
    
    Write-Step "Installing Flutter SDK v$FlutterVersion" $Script:Icons.Flutter
    
    Show-EnhancedSpinner -Message "Downloading Flutter SDK v$FlutterVersion" -ScriptBlock {
        $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"
        $tempZip = "$env:TEMP\flutter.zip"
        
        # Download with retry logic
        $maxRetries = 3
        $retryCount = 0
        
        do {
            try {
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($flutterUrl, $tempZip)
                break
            } catch {
                $retryCount++
                if ($retryCount -ge $maxRetries) {
                    throw "Failed to download Flutter after $maxRetries attempts: $($_.Exception.Message)"
                }
                Start-Sleep -Seconds $Script:Config.RetryDelaySeconds
            }
        } while ($retryCount -lt $maxRetries)
        
        # Extract Flutter
        Expand-Archive -Path $tempZip -DestinationPath $ToolsDir -Force
        
        # Clean up
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        
        if (!(Test-Path "$($Script:Config.FlutterDir)\bin\flutter.bat")) {
            throw "Flutter installation failed - flutter.bat not found"
        }
    }
    
    Set-FlutterEnvironment
    Write-Success "Flutter SDK v$FlutterVersion installed"
    return $true
}

function Set-FlutterEnvironment {
    Write-Step "Configuring Flutter environment" $Script:Icons.Configure
    
    # Add Flutter to PATH
    Add-ToPath "$($Script:Config.FlutterDir)\bin"
    Update-Environment
    
    Show-EnhancedSpinner -Message "Configuring Flutter with Android SDK" -ScriptBlock {
        & "$($Script:Config.FlutterDir)\bin\flutter.bat" config --android-sdk $Script:Config.AndroidSdkDir
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to configure Flutter with Android SDK"
        }
    }
    
    Write-Success "Flutter environment configured"
}

#endregion

#region Virtual Device and Performance Functions

function New-AndroidAVD {
    Write-Step "Creating Android Virtual Device (AVD)" $Script:Icons.Android
    
    $avdmanager = "$($Script:Config.CmdlineToolsDir)\bin\avdmanager.bat"
    
    # Check if AVD already exists
    $avdList = & $avdmanager list avd 2>$null
    if ($avdList -match "flutter_avd") {
        Write-Info "AVD 'flutter_avd' already exists"
        return $false
    }
    
    Show-EnhancedSpinner -Message "Creating Android Virtual Device 'flutter_avd'" -ScriptBlock {
        $createAvd = "no"
        $createAvd | & $avdmanager create avd -n flutter_avd -k "system-images;android-34;google_apis;x86_64" --device "pixel"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create Android Virtual Device"
        }
    }
    
    Write-Success "Android Virtual Device 'flutter_avd' created"
    return $true
}

function Test-HyperV {
    Write-Step "Checking virtualization capabilities" $Script:Icons.Performance
    
    try {
        $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        
        if ($hyperVFeature -and $hyperVFeature.State -eq "Enabled") {
            Write-Success "Hyper-V is enabled - optimal emulator performance available"
            return $true
        } else {
            Write-Warning "Hyper-V is not enabled. Consider enabling it for better emulator performance"
            Write-Info "To enable: Run as Administrator: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All"
            return $false
        }
    } catch {
        Write-Warning "Could not check Hyper-V status: $($_.Exception.Message)"
        return $false
    }
}

function Test-WSL2 {
    Write-Step "Checking WSL2 availability" $Script:Icons.Check
    
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
        
        if ($wslFeature -and $wslFeature.State -eq "Enabled") {
            Write-Success "WSL is available"
            
            # Check WSL2
            $wslVersion = wsl --status 2>$null
            if ($wslVersion -match "WSL 2") {
                Write-Success "WSL2 is configured - enhanced development environment available"
                return $true
            }
        }
        
        Write-Info "WSL2 not detected - Windows-only development environment"
        return $false
    } catch {
        Write-Log -Message "WSL2 check failed: $($_.Exception.Message)" -Level "DEBUG"
        return $false
    }
}

#endregion

#region Verification and Final Steps

function Invoke-FlutterDoctor {
    Write-Step "Running Flutter Doctor diagnostic" $Script:Icons.Check
    
    Show-EnhancedSpinner -Message "Analyzing Flutter installation" -ScriptBlock {
        $doctorOutput = & "$($Script:Config.FlutterDir)\bin\flutter.bat" doctor 2>&1
        
        # Log the full output
        Write-Log -Message "Flutter Doctor Output: $doctorOutput" -Level "DEBUG"
        
        # Check for critical issues
        if ($doctorOutput -match "\[✗\].*Android toolchain") {
            Write-Warning "Android toolchain issues detected"
        }
        
        if ($doctorOutput -match "\[✗\].*Flutter") {
            throw "Critical Flutter issues detected"
        }
    }
    
    # Display the actual flutter doctor output
    & "$($Script:Config.FlutterDir)\bin\flutter.bat" doctor
    
    Write-Success "Flutter Doctor diagnostic completed"
}

function Accept-AndroidLicenses {
    Write-Step "Accepting Android SDK licenses" $Script:Icons.Security
    
    Show-EnhancedSpinner -Message "Accepting all Android licenses" -ScriptBlock {
        $acceptAll = "y" * 20
        $acceptAll | & "$($Script:Config.FlutterDir)\bin\flutter.bat" doctor --android-licenses 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "Some Android licenses may not have been accepted" -Level "WARN"
        }
    }
    
    Write-Success "Android licenses processed"
}

function Start-EmulatorPrompt {
    Write-Host ""
    $launch = Read-Host "$($Script:Icons.Launch) Launch Android emulator now? (y/N)"
    
    if ($launch -match "^[Yy]$") {
        Write-Step "Starting Android emulator" $Script:Icons.Launch
        
        try {
            Start-Process -FilePath "$($Script:Config.AndroidSdkDir)\emulator\emulator.exe" `
                         -ArgumentList "-avd", "flutter_avd", "-netdelay", "none", "-netspeed", "full" `
                         -WindowStyle Hidden
            
            Write-Success "Android emulator launched in background"
            Write-Info "The emulator may take a few minutes to fully start up"
        } catch {
            Write-ErrorMessage "Failed to launch emulator: $($_.Exception.Message)"
        }
    } else {
        Write-Info "You can launch the emulator later with: emulator -avd flutter_avd"
    }
}

#endregion

#region Summary and Completion

function Show-InstallationSummary {
    $duration = (Get-Date) - $Script:Progress.StartTime
    
    Write-Header "Flutter Development Environment Setup Complete!"
    
    Write-Host "$($Script:Icons.Success) " -NoNewline -ForegroundColor $Script:Colors.Success
    Write-Host "Installation completed in " -NoNewline -ForegroundColor $Script:Colors.Info
    Write-Host "$([math]::Round($duration.TotalMinutes, 1)) minutes" -ForegroundColor $Script:Colors.Highlight
    Write-Host ""
    
    Write-Host "📋 " -NoNewline -ForegroundColor $Script:Colors.Info
    Write-Host "Installation Summary:" -ForegroundColor $Script:Colors.Info
    
    $components = @(
        "Java $JavaVersion JDK",
        "Git version control",
        "Android SDK with API 34",
        "Flutter SDK v$FlutterVersion",
        "Android Virtual Device (flutter_avd)",
        "Environment variables and PATH"
    )
    
    foreach ($component in $components) {
        Write-Host "   $($Script:Icons.Success) $component" -ForegroundColor $Script:Colors.Success
    }
    
    Write-Host ""
    Write-Host "🔧 " -NoNewline -ForegroundColor $Script:Colors.Info
    Write-Host "Environment Variables:" -ForegroundColor $Script:Colors.Info
    Write-Host "   JAVA_HOME = $($Script:Config.JavaDir)" -ForegroundColor $Script:Colors.Dim
    Write-Host "   ANDROID_HOME = $($Script:Config.AndroidSdkDir)" -ForegroundColor $Script:Colors.Dim
    Write-Host "   ANDROID_SDK_ROOT = $($Script:Config.AndroidSdkDir)" -ForegroundColor $Script:Colors.Dim
    
    Write-Host ""
    Write-Host "🚀 " -NoNewline -ForegroundColor $Script:Colors.Primary
    Write-Host "Quick Start Commands:" -ForegroundColor $Script:Colors.Primary
    Write-Host "   flutter doctor               $($Script:Icons.Check) Verify installation" -ForegroundColor $Script:Colors.Highlight
    Write-Host "   flutter create my_app        $($Script:Icons.Flutter) Create new project" -ForegroundColor $Script:Colors.Highlight
    Write-Host "   emulator -avd flutter_avd    $($Script:Icons.Android) Start emulator" -ForegroundColor $Script:Colors.Highlight
    
    Write-Host ""
    Write-Host "📝 " -NoNewline -ForegroundColor $Script:Colors.Info
    Write-Host "Log file saved to: " -NoNewline -ForegroundColor $Script:Colors.Info
    Write-Host "$($Script:Config.LogFile)" -ForegroundColor $Script:Colors.Dim
    
    Write-Host ""
    Write-Host "💡 " -NoNewline -ForegroundColor $Script:Colors.Warning
    Write-Host "Next Steps:" -ForegroundColor $Script:Colors.Warning
    Write-Host "   1. Restart your terminal or PowerShell" -ForegroundColor $Script:Colors.Info
    Write-Host "   2. Run 'flutter doctor' to verify everything works" -ForegroundColor $Script:Colors.Info
    Write-Host "   3. Create your first Flutter app!" -ForegroundColor $Script:Colors.Info
    
    Write-Host ""
}

#endregion

#region Main Execution

function Start-FlutterSetup {
    try {
        # Initialize logging
        New-Item -ItemType File -Path $Script:Config.LogFile -Force | Out-Null
        Write-Log -Message "Flutter Setup v2.0 started" -Level "INFO"
        Write-Log -Message "Parameters: FlutterVersion=$FlutterVersion, ToolsDir=$ToolsDir, JavaVersion=$JavaVersion, UseChocolatey=$UseChocolatey, LogLevel=$LogLevel" -Level "INFO"
        
        # Display header
        Write-Header "Flutter Development Environment Setup v2.0"
        
        Write-Host "🎯 Target Configuration:" -ForegroundColor $Script:Colors.Primary
        Write-Host "   Flutter Version: $FlutterVersion" -ForegroundColor $Script:Colors.Info
        Write-Host "   Tools Directory: $ToolsDir" -ForegroundColor $Script:Colors.Info
        Write-Host "   Java Version: $JavaVersion" -ForegroundColor $Script:Colors.Info
        Write-Host "   Package Manager: $(if ($UseChocolatey) { 'Chocolatey + Direct' } else { 'Direct Download' })" -ForegroundColor $Script:Colors.Info
        Write-Host ""
        
        # Check admin privileges
        if (!(Test-AdminPrivileges)) {
            Write-Warning "Running without administrator privileges"
            Write-Info "Some features may require manual configuration"
        } else {
            Write-Success "Running with administrator privileges"
        }
        
        # System checks
        Test-SystemRequirements
        Test-InternetConnection
        
        # Package managers
        if ($UseChocolatey) {
            Install-Chocolatey
        }
        Install-WingetIfAvailable
        
        # Core development tools
        Install-Java
        Install-Git
        New-ToolsDirectory
        
        # Android development environment
        Install-AndroidSdk
        Accept-AndroidLicenses
        
        # Flutter SDK
        Install-Flutter
        
        # Virtual device setup
        New-AndroidAVD
        
        # Performance optimizations
        Test-HyperV
        Test-WSL2
        
        # Final verification
        Invoke-FlutterDoctor
        
        # Display summary
        Show-InstallationSummary
        
        # Optional emulator launch
        Start-EmulatorPrompt
        
        Write-Log -Message "Flutter Setup v2.0 completed successfully" -Level "INFO"
        
    } catch {
        Write-ErrorMessage "Setup failed: $($_.Exception.Message)"
        Write-Log -Message "Setup failed: $($_.Exception.Message)" -Level "ERROR"
        Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        
        Write-Host ""
        Write-Host "🔍 Troubleshooting:" -ForegroundColor $Script:Colors.Warning
        Write-Host "   1. Check the log file: $($Script:Config.LogFile)" -ForegroundColor $Script:Colors.Info
        Write-Host "   2. Ensure stable internet connection" -ForegroundColor $Script:Colors.Info
        Write-Host "   3. Try running as Administrator" -ForegroundColor $Script:Colors.Info
        Write-Host "   4. Check available disk space (minimum 10GB)" -ForegroundColor $Script:Colors.Info
        
        exit 1
    }
}

# Execute main function
Start-FlutterSetup

#endregion
