# --- Windows-Compatible Environment Installer Script ---
# Works in both Windows PowerShell 5.1 and PowerShell 7+
# Run `iex "& { $(Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/mastrauckas/install-scripts/main/windows/install.ps1') }"`
$ErrorActionPreference = "Stop"

# --- Functions ---

function Install-PowerShell {
   if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
      Write-Host "Installing PowerShell via winget..."
      winget install --id Microsoft.PowerShell --source winget -e --accept-source-agreements --accept-package-agreements
      Write-Host "PowerShell installed successfully."
   }
   else {
      Write-Host "PowerShell is already installed."
   }
}

function Install-Chocolatey {
   if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
      Write-Host "Installing Chocolatey via PowerShell..."
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
      iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
      Write-Host "Chocolatey installed successfully."
   }
   else {
      Write-Host "Chocolatey is already installed."
   }
}

function Install-ChocoPackage {
   param([string]$packageName)
   if (-not (choco list --local-only | Select-String $packageName)) {
      Write-Host "Installing $packageName via Chocolatey..."
      choco install $packageName -y
      Write-Host "$packageName installed successfully."
   }
   else {
      Write-Host "$packageName is already installed."
   }
}

function Enable-NativeSudo {
   $winVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
   $major = [int]$winVersion.CurrentMajorVersionNumber
   $build = [int]$winVersion.CurrentBuildNumber

   Write-Host "`nDetected Windows Version: $major.$build"

   if ($major -ge 10 -and $build -ge 22631) {
      Write-Host "Windows version supports native sudo. Enabling feature..."
      try {
         Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Sudo -All -NoRestart
         Write-Host "Native sudo feature enabled successfully."
      }
      catch {
         Write-Host "Failed to enable native sudo feature. It might already be enabled or unavailable."
      }
   }
   else {
      Write-Host "Windows version does not support native sudo. Skipping."
   }
}

function Handle-SSHKey {
   param([string]$sshKeyName)

   $sshDir = Join-Path $env:USERPROFILE ".ssh"
   if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

   $privateKey = Join-Path $sshDir $sshKeyName
   $publicKey = "$privateKey.pub"

   if (-not (Test-Path $privateKey)) {
      $githubEmail = Read-Host "Enter your GitHub email (used for SSH key comment)"
      Write-Host "`nGenerating new SSH key..."
      ssh-keygen -t ed25519 -C $githubEmail -f $privateKey -q
      if (-not (Test-Path $publicKey)) {
         Write-Error "❌ SSH key generation failed — public key not found at $publicKey"
         exit 1
      }
      Write-Host "SSH key generated successfully at $privateKey"
   }
   else {
      Write-Host "SSH key already exists at $privateKey. Skipping generation."
   }

   # Ensure SSH config exists and is correct
   Ensure-SSHConfig -privateKey $privateKey

   # Ask user how to add key
   $choice = $null
   while ($choice -notin @("1", "2")) {
      Write-Host "`nChoose how to add your SSH public key to GitHub:"
      Write-Host "1) Add it yourself manually (copied to clipboard)"
      Write-Host "2) Use GitHub CLI"
      $choice = Read-Host "Enter 1 or 2"
   }

   if ($choice -eq "1") {
      Get-Content $publicKey | Set-Clipboard
      Write-Host "`n✅ The public key has been copied to your clipboard."
      Write-Host "Paste it into GitHub (Settings → SSH and GPG keys → New SSH key)."
      Read-Host "Press Enter once you have added the key to GitHub"
   }
   elseif ($choice -eq "2") {
      Write-Host "Using GitHub CLI to add key..."
      gh auth login
      gh ssh-key add $publicKey -t "bootstrap-key"
      Write-Host "Key added via GitHub CLI."
   }
}

function Ensure-SSHConfig {
   param([string]$privateKey)

   $sshDir = Join-Path $env:USERPROFILE ".ssh"
   $configFile = Join-Path $sshDir "config"

   if (-not (Test-Path $configFile)) {
      Write-Host "SSH config file not found. Creating new one..."
      New-Item -Path $configFile -ItemType File | Out-Null
   }

   # Check if an entry for github.com already exists
   $existing = Get-Content $configFile | Select-String "Host github.com"
   if (-not $existing) {
      Write-Host "Adding GitHub entry to SSH config..."
      @"
Host github.com
    HostName github.com
    User git
    IdentityFile $privateKey
"@ | Add-Content $configFile
      Write-Host "SSH config updated: $configFile"
   }
   else {
      Write-Host "GitHub entry already exists in SSH config. Skipping."
   }
}


function Clone-ConfigRepo {
   param([string]$repoUrl, [string]$destination)
   if (-not (Test-Path $destination)) {
      Write-Host "Cloning repository into $destination..."
      try {
         git clone $repoUrl $destination
         Write-Host "Repository cloned successfully."
      }
      catch {
         Write-Error "❌ Failed to clone repository. Please check your SSH key and access rights."
         exit 1
      }
   }
   else {
      Write-Host "Repository path already exists: $destination"
   }
}

function Set-EnvironmentVariables {
   param([string]$projectsPath, [string]$configRepoPath)
   Write-Host "`nSetting environment variables..."
   [Environment]::SetEnvironmentVariable("PROJECTS_PATH", $projectsPath, [EnvironmentVariableTarget]::User)
   [Environment]::SetEnvironmentVariable("CONFIGURATION_REPOSITORY_PATH", $configRepoPath, [EnvironmentVariableTarget]::User)
   Write-Host "PROJECTS_PATH = $projectsPath"
   Write-Host "CONFIGURATION_REPOSITORY_PATH = $configRepoPath"
}

function Update-Pwsh7Profile {
   param([string]$configRepoPath)

   # Define the path to the PowerShell 7 profile
   $pwsh7Profile = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

   # Create the profile if it does not exist
   if (-not (Test-Path $pwsh7Profile)) {
      Write-Host "PowerShell 7 profile not found. Creating profile at $pwsh7Profile..."
      New-Item -ItemType File -Path $pwsh7Profile -Force | Out-Null
   }

   # Define the import line to add
   $importLine = @'
try {
    . "$env:CONFIGURATION_REPOSITORY_PATH\powershell\main_script.ps1"
}
catch {
    Write-Host "Error importing module: $_"
}
'@

   if (-not ($existing -contains $importLine)) {
      # Ensure new line if file already has content
      if ($existing.Count -gt 0) {
         Add-Content -Path $pwsh7Profile -Value "`n$importLine"
      }
      else {
         Add-Content -Path $pwsh7Profile -Value $importLine
      }
      Write-Host "Adding import line to PowerShell 7 profile..."
      Write-Host "Import line added successfully."
   }
   else {
      Write-Host "Import line already exists in PowerShell 7 profile. No changes made."
   }
}



# --- Main workflow ---
function Main {
   # Prompt for paths
   $ProjectsPath = Read-Host "Enter the PROJECTS_PATH (default: C:\Projects)"
   if ([string]::IsNullOrWhiteSpace($ProjectsPath)) { $ProjectsPath = "C:\Projects" }

   if (-not (Test-Path $ProjectsPath)) { New-Item -ItemType Directory -Path $ProjectsPath | Out-Null }

   $ConfigRepoPathDefault = Join-Path $ProjectsPath "configurations"
   $ConfigRepoPath = Read-Host "Enter the CONFIGURATION_REPOSITORY_PATH (default: $ConfigRepoPathDefault)"
   if ([string]::IsNullOrWhiteSpace($ConfigRepoPath)) { $ConfigRepoPath = $ConfigRepoPathDefault }

   # Install components
   Install-PowerShell
   Install-Chocolatey
   Install-ChocoPackage -packageName "git"
   Enable-NativeSudo

   # SSH key
   Handle-SSHKey -sshKeyName "github_mastrauckas"

   # Clone repository
   $repoUrl = "git@github.com:mastrauckas/configurations.git"
   Clone-ConfigRepo -repoUrl $repoUrl -destination $ConfigRepoPath

   Write-Debug "Line 1"
   # Set environment variables
   Set-EnvironmentVariables -projectsPath $ProjectsPath -configRepoPath $ConfigRepoPath
   Write-Debug "Line 2"

   # Update PowerShell profile
   Update-Pwsh7Profile -configRepoPath $ConfigRepoPath

   Write-Debug "Line 3"

   Write-Host "`n✅ Setup completed successfully!"
}

# --- Execute main workflow ---
Main
