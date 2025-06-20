# ros-lint

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![RouterOS](https://img.shields.io/badge/RouterOS-7.x-blue.svg)](https://mikrotik.com/software)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)

🔍 MikroTik RouterOS script validator and linter. Check RouterOS .rsc script syntax remotely via SSH without execution. Features line-by-line error detection, SSH key auth, and verbosity levels. Perfect for automating RouterOS/ROS script verification in CI/CD pipelines.

## 🌟 Features

- ✨ **Safe Validation**: Checks script syntax without executing it on the router
- 📍 **Precise Error Detection**: Shows exact line and column numbers for syntax errors
- 🔐 **Flexible Authentication**: Supports SSH keys, agent, and hardware tokens
- 📊 **Verbosity Control**: Three levels of output detail (0=minimal, 1=info, 2=debug)
- 🧹 **Clean Operation**: Automatic cleanup of temporary files on the router
- 🔄 **CI/CD Ready**: Perfect for automated script validation in deployment pipelines

## 🚀 Quick Start

```bash
# Download
curl -O https://raw.githubusercontent.com/tarikin/ros-lint/main/ros-lint.sh
chmod +x ros-lint.sh

# Basic usage
./ros-lint.sh admin@192.168.88.1 script.rsc

# With SSH key and verbose output
./ros-lint.sh -v 1 -i ~/.ssh/router_key 192.168.88.1 config.rsc
```

## 🌍 Global Installation

### One-liner Installation

Install `ros-lint` with a single command:

```bash
sudo curl -sSL https://raw.githubusercontent.com/tarikin/ros-lint/main/ros-lint.sh -o /usr/local/bin/ros-lint && sudo chmod +x /usr/local/bin/ros-lint
```

### Manual Installation

Alternatively, you can install it manually:

```bash
# Download the script
curl -O https://raw.githubusercontent.com/tarikin/ros-lint/main/ros-lint.sh

# Make the script executable
chmod +x ros-lint.sh

# Create the bin directory if it doesn't exist
sudo mkdir -p /usr/local/bin

# Copy the script to a directory in your PATH
sudo cp ros-lint.sh /usr/local/bin/ros-lint

# Verify installation
ros-lint --help
```

After installation, you can run `ros-lint` from anywhere on your system.

## 📖 Usage

```bash
./ros-lint.sh [-v 0|1|2] [-i identity_file] [user@]host[:port] <script.rsc>

Options:
  -v <level>        Verbosity level:
                    0 = Results only (default)
                    1 = Info messages
                    2 = Debug output
  -i <identity>     SSH identity file (private key)
  -h, --help        Show help message
```

## 🎯 Examples

### Basic Syntax Check
```bash
./ros-lint.sh admin@router.local backup.rsc
✓ Syntax OK
```

### With Custom Port and SSH Key
```bash
./ros-lint.sh -i ~/.ssh/mikrotik admin@192.168.1.1:2222 script.rsc
✓ Syntax OK
```

### Debug Output for Troubleshooting
```bash
./ros-lint.sh -v 2 admin@router.local script.rsc
[INFO] Uploading script to router.local:script.rsc
[DEBUG] Commands being executed on RouterOS:
[DEBUG] 1. Check if file exists...
...
✓ Syntax OK
[INFO] Cleaned up temporary file
```

### Error Detection
```bash
./ros-lint.sh admin@router script-with-error.rsc
✗ syntax error (line 14 column 60)
```

## 🔧 Requirements

- Bash 4.0 or newer
- SSH client (`ssh` and `scp` commands)
- RouterOS v6.x or v7.x on the target router
- SSH access to the router (password or key-based)

## 🔒 Security Notes

- The script uploads files to the router's root directory
- Files are automatically removed after syntax checking
- No script execution occurs, only syntax validation
- Uses SSH's StrictHostKeyChecking=accept-new for security

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

MIT © 2025 [Nikita Tarikin](https://github.com/tarikin)
