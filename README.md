# Flutter Setup Scripts

This repository contains setup scripts for configuring a Flutter development environment on both **Windows** and **Ubuntu** systems.

## Prerequisites

### Windows
- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges (recommended for Hyper-V support)

### Ubuntu
- Ubuntu 20.04 or later
- Bash shell
- sudo privileges

## Usage

### Windows

1. Open PowerShell as Administrator.
2. Navigate to the `windows` directory:

   ```powershell
   cd path\to\flutter_setup_script\windows
   ```

3. Run the script:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\flutter_setup.ps1
   ```

4. Optionally, specify custom parameters:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\flutter_setup.ps1 -FlutterVersion "3.24.3" -ToolsDir "C:\dev\tools" -JavaVersion "17"
   ```

### Ubuntu

1. Open a terminal.
2. Navigate to the `ubuntu` directory:

   ```bash
   cd path/to/flutter_setup_script/ubuntu
   ```

3. Make the script executable:

   ```bash
   chmod +x flutter_setup.sh
   ```

4. Run the script:

   ```bash
   ./flutter_setup.sh
   ```

## Uninstalling (Ubuntu)

To completely remove the Flutter development environment:

1. Navigate to the `ubuntu` directory:

   ```bash
   cd path/to/flutter_setup_script/ubuntu
   ```

2. Run the uninstall script:

   ```bash
   ./flutter_uninstall.sh
   ```

This will remove:
- Flutter SDK
- Android SDK
- SDKMAN! and all Java versions installed via SDKMAN
- Android Virtual Devices (AVDs)
- Environment variables from shell configuration files
- Optionally: system packages installed during setup

## Features

- Installs Java 17 (via SDKMAN! on Ubuntu, Chocolatey on Windows)
- Installs Android SDK and Command Line Tools
- Installs Flutter SDK
- Configures environment variables
- Creates an Android Virtual Device (AVD)
- Runs `flutter doctor` to verify the setup

## Notes

- On Windows, ensure you run PowerShell as Administrator for optimal setup.
- On Ubuntu, you may need to log out and log back in to apply group changes (e.g., adding the user to the `kvm` group).

## Troubleshooting

- If the script fails, check the error message and ensure all prerequisites are met.
- For Windows, ensure Chocolatey is installed and accessible.

## License

This project is licensed under the MIT License.

Copyright (c) 2025 Sajal Halder <newtoh48@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
