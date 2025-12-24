# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- **Time/Date Configuration** - Automated configuration of Windows time and date settings

  - System timezone set to Eastern Standard Time
  - Calendar set to Gregorian
  - First day of week set to Sunday
  - Short date format: MM/dd/yyyy (e.g., 04/05/2017)
  - Long date format: Windows style (e.g., Wednesday, April 5, 2017)
  - Short time format: hh:mm tt (e.g., 09:40 AM)
  - Show seconds in system tray clock (Windows 11 22H2+ build 22621+, gracefully skips on older versions)
  - Additional UTC clock in taskbar
  - OS version detection with feature gating for unsupported configurations
  - Check-and-apply pattern (only modifies values if they differ from target)

- **Development Tools Installation**

  - PowerShell 7+ installation via winget
  - Chocolatey package manager installation
  - Git installation via winget
  - VS Code Insiders installation via winget

- **Git Configuration**

  - User name and email setup with validation
  - Core settings optimization (autocrlf, fscache, untrackedCache, preloadIndex, longpaths)
  - Credential helper configuration (Windows Credential Manager)
  - Merge and pull strategies (fast-forward only)
  - Useful Git aliases (st, co, br, last, lg)
  - Global .gitignore file creation

- **SSH Key Management**

  - ed25519 SSH key generation
  - SSH config file creation and GitHub entry configuration
  - GitHub integration via manual clipboard copy or GitHub CLI

- **Windows Features**

  - Native sudo enablement (Windows 11 build 22631+)

- **Environment Setup**

  - User environment variables configuration (PROJECTS_PATH, CONFIGURATION_REPOSITORY_PATH)
  - PowerShell 7 profile updates for custom module loading
  - Configuration repository cloning via SSH

- **Interactive Prompts**
  - User confirmation before applying configurations
  - Customizable paths and settings
  - Clear skip messages for declined configurations

### Technical Details

- Idempotent design - safe to run multiple times
- OS version and build detection for feature compatibility
- Registry-based configuration using PowerShell providers
- Error handling with try-catch blocks and descriptive messages
- User-scoped registry changes (HKCU) for personalization settings
