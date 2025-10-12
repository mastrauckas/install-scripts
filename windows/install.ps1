# --- Windows-Compatible Environment Installer Script ---
# Works in both Windows PowerShell 5.1 and PowerShell 7+
# Run `iex "& { $(Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/mastrauckas/install-scripts/main/windows/install.ps1') }"`

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Step 1: Functions ---

function Show-Menu {
   param (
      [string]$Title = 'Choose how to add SSH key to GitHub'
   )

   $options = @(
      "1. I will add the SSH key manually",
      "2. Use GitHub CLI to upload the SSH key automatically"
   )

   $selected = 0
   $key = $null

   while ($true) {
      Clear-Host
      Write-Host "=== $Title ===`n"
      for ($i = 0; $i -lt $options.Length; $i++) {
         if ($i -eq $selected) {
            Write-Host "> $($options[$i])" -ForegroundColor Cyan
         }
         else {
            Write-Host "  $($options[$i])"
         }
      }

      $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      switch ($key.VirtualKeyCode) {
         38 { if ($selected -gt 0) { $selected-- } }   # Up arrow
         40 { if ($selected -lt $options.Length - 1) { $selected++ } }  # Down arrow
         13 { break }  # Enter
      }

      if ($key.VirtualKeyCode -eq 13) { break }
   }

   return $selected
}

function Install-Chocolatey {
   if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
      Write-Host "Installing Chocolatey..."
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
      Write-Host "Chocolatey installed successfully."
   }
   else {
      Write-Host "Chocolatey is already installed."
   }
}

function Install-Git {
   if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Write-Host "Installing Git via Chocolatey..."
      choco install git -y
      Write-Host "Git installed successfully."
   }
   else {
      Write-Host "Git is already installed."
   }
}

function Install-Sudo {
   try {
      $winVer = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ReleaseId
   }
   catch {
      $winVer = 0
   }
   if ([int]$winVer -ge 22000) {
      if (-not (Get-Command sudo -ErrorAction SilentlyContinue)) {
         Write-Host "Windows version supports sudo. Installing..."
         choco install sudo -y
         Write-Host "sudo installed successfully."
      }
      else {
         Write-Host "sudo is already installed."
      }
   }
   else {
      Write-Host "Skipping sudo installation (unsupported Windows version)."
   }
}

function Generate-SSHKey {
   param (
      [string]$sshKeyPath,
      [string]$githubEmail
   )

   if (-not (Test-Path "$sshKeyPath.pub")) {
      Write-Host "Generating new SSH key..."
      ssh-keygen -t ed25519 -C $githubEmail -f $sshKeyPath -N ''
      Write-Host "SSH key generated successfully at $sshKeyPath"
   }
   else {
      Write-Host "SSH key already exists at $sshKeyPath"
   }
}

function Add-Key-ToProfile {
   param (
      [string]$configRepoPath
   )

   Write-Host "Updating PowerShell profile to import main_script.ps1..."
   $profileContent = @()
   if (Test-Path $profile) {
      $profileContent = Get-Content $profile -ErrorAction SilentlyContinue
   }

   $importLine = "Import-Module `"$configRepoPath\powershell\main_script.ps1`""
   if ($profileContent -notcontains $importLine) {
      $newContent = @()
      $newContent += $importLine
      if ($profileContent.Count -gt 0) {
         $newContent += ""
         $newContent += $profileContent
      }
      $newContent | Set-Content -Path $profile -Encoding UTF8
      Write-Host "Added import line to PowerShell profile at top."
   }
   else {
      Write-Host "Import line already exists in PowerShell profile."
   }
}

# --- Step 2: Prompt for project and config paths ---

$ProjectsPath = Read-Host "Enter the PROJECTS_PATH (e.g., C:\Projects)"

if ([string]::IsNullOrWhiteSpace($ProjectsPath)) {
   Write-Host "Error: PROJECTS_PATH cannot be empty. Exiting script." -ForegroundColor Red
   exit 1
}

if (-not (Test-Path $ProjectsPath)) {
   Write-Host "Creating directory $ProjectsPath..."
   New-Item -ItemType Directory -Path $ProjectsPath | Out-Null
}

$defaultConfigRepoPath = Join-Path $ProjectsPath "configurations"
$ConfigRepoPathInput = Read-Host "Enter the CONFIGURATION_REPOSITORY_PATH (default: $defaultConfigRepoPath)"
$ConfigRepoPath = if ([string]::IsNullOrWhiteSpace($ConfigRepoPathInput)) {
   $defaultConfigRepoPath
}
else {
   $ConfigRepoPathInput
}

if (-not (Test-Path $ConfigRepoPath)) {
   Write-Host "Creating directory $ConfigRepoPath..."
   New-Item -ItemType Directory -Path $ConfigRepoPath | Out-Null
}

# --- Step 3: Install PowerShell, Chocolatey, Git, sudo ---

Write-Host "`nInstalling required components..."
Install-Chocolatey
Install-Git
Install-Sudo

# --- Step 4: SSH key setup ---

$sshFolder = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshFolder)) {
   New-Item -ItemType Directory -Path $sshFolder | Out-Null
}

$sshKeyPath = Join-Path $sshFolder "github_mastrauckas"

if (-not (Test-Path "$sshKeyPath.pub")) {
   $githubEmail = Read-Host "Enter your GitHub email (used for SSH key comment)"
   Generate-SSHKey -sshKeyPath $sshKeyPath -githubEmail $githubEmail

   $publicKey = Get-Content "$sshKeyPath.pub"
   Write-Host "`nYour SSH public key (copy to GitHub):`n"
   Write-Host $publicKey -ForegroundColor Cyan
   Write-Host "`nVisit https://github.com/settings/keys to add this key manually.`n"

   $choice = Show-Menu
   if ($choice -eq 1) {
      if (Get-Command gh -ErrorAction SilentlyContinue) {
         Write-Host "Adding key using GitHub CLI..."
         gh ssh-key add "$sshKeyPath.pub" --title "github_mastrauckas"
         Write-Host "Key added via GitHub CLI."
      }
      else {
         Write-Host "GitHub CLI not found. Please install GitHub CLI and rerun script if you want automatic setup."
      }
   }
   else {
      Read-Host "Press ENTER after you've added the key on GitHub"
   }
}
else {
   Write-Host "SSH key already exists. Skipping generation."
}

# --- Step 5: Clone the configuration repository ---

Write-Host "`nCloning repository into $ConfigRepoPath..."
try {
   git clone git@github.com:mastrauckas/configurations.git $ConfigRepoPath
   Write-Host "Repository cloned successfully."
}
catch {
   Write-Host "Failed to clone repository. Exiting script." -ForegroundColor Red
   exit 1
}

# --- Step 6: Set environment variables after successful clone ---

Write-Host "`nSetting environment variables..."
[Environment]::SetEnvironmentVariable("PROJECTS_PATH", $ProjectsPath, [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("CONFIGURATION_REPOSITORY_PATH", $ConfigRepoPath, [EnvironmentVariableTarget]::User)
Write-Host "PROJECTS_PATH = $ProjectsPath"
Write-Host "CONFIGURATION_REPOSITORY_PATH = $ConfigRepoPath"
Write-Host "Environment variables saved (user-level, persistent)."

# --- Step 7: Update PowerShell profile ---

Add-Key-ToProfile -configRepoPath $ConfigRepoPath

Write-Host "`nSetup completed successfully!" -ForegroundColor Green
