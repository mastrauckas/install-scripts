# --- Windows-Compatible Environment Installer Script ---
# Works in both Windows PowerShell 5.1 and PowerShell 7+
# Run `iex "& { $(Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/mastrauckas/install-scripts/main/windows/install.ps1') }"`

# -------------------------------
# Windows Bootstrap Script (Modular)
# -------------------------------
# -------------------------------
# Windows Bootstrap Script (Modular)
# -------------------------------

function Prompt-Paths {
   $defaultProjectsPath = "C:\Projects"
   $projectsPath = Read-Host "Enter the PROJECTS_PATH (default: $defaultProjectsPath)"
   if ([string]::IsNullOrWhiteSpace($projectsPath)) { $projectsPath = $defaultProjectsPath }

   $defaultConfigPath = Join-Path $projectsPath "configurations"
   $configPath = Read-Host "Enter the CONFIGURATION_REPOSITORY_PATH (default: $defaultConfigPath)"
   if ([string]::IsNullOrWhiteSpace($configPath)) { $configPath = $defaultConfigPath }

   # Ensure projects directory exists
   if (-not (Test-Path $projectsPath)) {
      Write-Host "Creating projects directory at $projectsPath..."
      New-Item -ItemType Directory -Force -Path $projectsPath | Out-Null
   }

   return @{ ProjectsPath = $projectsPath; ConfigPath = $configPath }
}

function Install-PackageWinget {
   param (
      [string]$packageId,
      [string]$packageName
   )

   if (-not (Get-Command $packageName -ErrorAction SilentlyContinue)) {
      Write-Host "Installing $packageName via winget..."
      winget install --id $packageId -e --accept-source-agreements --accept-package-agreements
      if ($LASTEXITCODE -eq 0) {
         Write-Host "✅ $packageName installed successfully."
      }
      else {
         Write-Host "❌ Failed to install $packageName via winget."
         exit 1
      }
   }
   else {
      Write-Host "$packageName is already installed."
   }
}

function Install-Git {
   if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Write-Host "Installing Git..."
      choco install git -y
   }
   else {
      Write-Host "Git is already installed."
   }
}

function Generate-SSHKey {
   param ([string]$githubEmail)
   $sshDir = "$env:USERPROFILE\.ssh"
   if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Force -Path $sshDir | Out-Null }

   $keyName = "github_mastrauckas"
   $privateKey = Join-Path $sshDir $keyName
   $publicKey = "$privateKey.pub"

   if (-not (Test-Path $publicKey)) {
      Write-Host "`nSSH key not found. Generating now..."
      Write-Host "You’ll be prompted for file location and passphrase (press Enter for defaults).`n"
      ssh-keygen -t ed25519 -C $githubEmail -f $privateKey
   }
   else {
      Write-Host "SSH key already exists at $privateKey"
   }

   if (Test-Path $publicKey) {
      Write-Host "`n✅ Public key ready at: $publicKey"
      Write-Host "Copy this key to GitHub if using manual method:`n"
      Get-Content $publicKey
   }
   else {
      Write-Host "❌ Error: Public key not found at $publicKey"
      exit 1
   }

   return $publicKey
}

function Prompt-SSHKeyAddition {
   param ([string]$publicKeyPath)

   Write-Host "`nYour SSH public key is located at: $publicKeyPath"
   Write-Host "Choose how to add it to GitHub:"
   Write-Host "1) Add manually (copy-paste)"
   Write-Host "2) Use GitHub CLI (gh)"

   do {
      $choice = Read-Host "Enter 1 or 2"
   } while ($choice -ne '1' -and $choice -ne '2')

   if ($choice -eq '1') {
      Write-Host "`nPlease add the key manually to GitHub (Settings → SSH and GPG Keys)."
      Write-Host "Press Enter when done..."
      Read-Host
   }
   elseif ($choice -eq '2') {
      if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
         Write-Host "GitHub CLI not installed. Installing..."
         choco install gh -y
      }
      gh auth login
      gh ssh-key add $publicKeyPath -t "bootstrap key"
      Write-Host "✅ SSH key added to GitHub using CLI."
   }
}

function Clone-Repository {
   param (
      [string]$repoUrl,
      [string]$destinationPath
   )

   if (Test-Path $destinationPath) {
      Write-Host "Repository already exists at $destinationPath. Skipping clone."
      return
   }

   Write-Host "`nCloning repository into $destinationPath..."
   try { ssh -o StrictHostKeyChecking=no -T git@github.com 2>$null } catch { }

   git clone $repoUrl $destinationPath
   if ($LASTEXITCODE -eq 0) {
      Write-Host "✅ Repository cloned successfully."
   }
   else {
      Write-Host "❌ Failed to clone repository. Check SSH key and access rights."
      exit 1
   }
}

function Set-EnvironmentVariables {
   param (
      [string]$projectsPath,
      [string]$configPath
   )

   Write-Host "`nSetting environment variables..."
   [Environment]::SetEnvironmentVariable("PROJECTS_PATH", $projectsPath, [System.EnvironmentVariableTarget]::User)
   [Environment]::SetEnvironmentVariable("CONFIGURATION_REPOSITORY_PATH", $configPath, [System.EnvironmentVariableTarget]::User)
   Write-Host "PROJECTS_PATH = $projectsPath"
   Write-Host "CONFIGURATION_REPOSITORY_PATH = $configPath"
}

function Update-PowerShellProfile {
   param ([string]$configPath)
   $profileLine = "Import-Module '$configPath\powershell\main_script.ps1'"
   if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force -Path $PROFILE | Out-Null }
   $profileContent = Get-Content $PROFILE -Raw
   if (-not $profileContent.Contains($profileLine)) {
      Write-Host "`nUpdating PowerShell profile to import main_script.ps1..."
      $newContent = $profileLine + "`r`n" + $profileContent
      Set-Content -Path $PROFILE -Value $newContent
   }
   else {
      Write-Host "Import line already exists in PowerShell profile."
   }
}

# -------------------------------
# Main Script
# -------------------------------

# Prompt for paths
$paths = Prompt-Paths
$ProjectsPath = $paths.ProjectsPath
$ConfigRepoPath = $paths.ConfigPath

# Install required components
Install-Chocolatey
Install-Git
Write-Host "Skipping sudo installation (unsupported Windows version)."

# SSH key
$githubEmail = Read-Host "Enter your GitHub email (used for SSH key comment)"
$publicKeyPath = Generate-SSHKey -githubEmail $githubEmail

# Prompt user to add key before cloning
Prompt-SSHKeyAddition -publicKeyPath $publicKeyPath

# Clone repository
$repoUrl = "git@github.com:mastrauckas/configurations.git"
Clone-Repository -repoUrl $repoUrl -destinationPath $ConfigRepoPath

# Set environment variables
Set-EnvironmentVariables -projectsPath $ProjectsPath -configPath $ConfigRepoPath

# Update PowerShell profile
Update-PowerShellProfile -configPath $ConfigRepoPath

Write-Host "`n🎉 Setup completed successfully!"
