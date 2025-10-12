$ErrorActionPreference = "Stop"

# --- Helper Functions ---

function Show-Menu {
   param([string[]]$Options)
   $selected = 0
   do {
      Clear-Host
      Write-Host "Use ↑ ↓ arrows to navigate and Enter to select:`n"
      for ($i = 0; $i -lt $Options.Length; $i++) {
         if ($i -eq $selected) { Write-Host "> $($Options[$i])" -ForegroundColor Cyan }
         else { Write-Host "  $($Options[$i])" }
      }
      $key = [System.Console]::ReadKey($true)
      switch ($key.Key) {
         "UpArrow" { if ($selected -gt 0) { $selected-- } }
         "DownArrow" { if ($selected -lt $Options.Length - 1) { $selected++ } }
         "Enter" { return $selected }
      }
   } while ($true)
}

function Prompt-Paths {
   $ProjectsPath = Read-Host "Enter the Projects path"
   $ConfigRepoPath = Read-Host "Enter the CONFIGURATION_REPOSITORY_PATH"
   Write-Host "Paths set successfully ✅`n"
   return @($ProjectsPath, $ConfigRepoPath)
}

function Ensure-SSHKey {
   param([string]$sshKeyPath)
   if (-not (Test-Path $sshKeyPath)) {
      $githubEmail = Read-Host "Enter your GitHub email (used as SSH key comment)"
      Write-Host "Generating SSH key..."
      ssh-keygen -t ed25519 -f $sshKeyPath -N "" -C $githubEmail
      Write-Host "SSH key created successfully ✅`n"
   }
   else {
      Write-Host "SSH key already exists at $sshKeyPath ✅`n"
   }
}

function Add-SSHKey-ToGitHub {
   param([string]$sshKeyPath)
   $options = @(
      "Manually copy and add via GitHub website",
      "Use GitHub CLI to add automatically"
   )
   $choiceIndex = Show-Menu -Options $options

   switch ($choiceIndex) {
      0 {
         Write-Host "`nAdd the following public key to your GitHub account manually:"
         Get-Content "$sshKeyPath.pub" | ForEach-Object { Write-Host $_ }
         Read-Host "`nPress Enter once you've added the public key"
         Write-Host "Public key added manually ✅`n"
      }
      1 {
         if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-Host "Installing GitHub CLI..."
            choco install gh -y
            Write-Host "GitHub CLI installed ✅`n"
         }
         Write-Host "Authenticating GitHub CLI..."
         gh auth login
         Write-Host "Adding SSH key via GitHub CLI..."
         gh ssh-key add "$sshKeyPath.pub" --title "mastrauckas-setup-key"
         Write-Host "Public key added via CLI ✅`n"
      }
   }
}

function Install-Chocolatey {
   if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
      Write-Host "Installing Chocolatey..."
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
      Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
      Write-Host "Chocolatey installed successfully ✅`n"
   }
   else {
      Write-Host "Chocolatey already installed ✅`n"
   }
}

function Install-Git {
   if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Write-Host "Installing Git..."
      choco install git -y
      Write-Host "Git installed successfully ✅`n"
   }
   else {
      Write-Host "Git already installed ✅`n"
   }
}

function Enable-WindowsSudo {
   try {
      $winVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
      $major = [int]$winVersion.CurrentMajorVersionNumber
      $build = [int]$winVersion.CurrentBuildNumber

      Write-Host "`nDetected Windows Version: $major.$build"

      if ($major -ge 10 -and $build -ge 22631) {
         Write-Host "Enabling native Windows sudo feature..."
         Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Sudo -All -NoRestart
         Write-Host "Windows sudo feature enabled successfully ✅`n"
      }
      else {
         Write-Host "Windows version does not support native sudo. Skipping ✅`n"
      }
   }
   catch {
      Write-Host "Failed to enable Windows feature. Terminating script."
      exit 1
   }
}

function Clone-ConfigRepo {
   param([string]$repoPath)
   if (-not (Test-Path $repoPath)) {
      Write-Host "Cloning configuration repository..."
      git clone git@github.com:mastrauckas/configurations.git $repoPath
      Write-Host "Repository cloned successfully ✅`n"
   }
   else {
      Write-Host "Configuration repository already exists at $repoPath ✅`n"
   }
}

function Set-EnvironmentVariables {
   param([string]$projectsPath, [string]$configRepoPath)
   Write-Host "Setting environment variables..."

   # Persistent for all future sessions (Windows user level)
   [Environment]::SetEnvironmentVariable("PROJECTS_PATH", $projectsPath, [System.EnvironmentVariableTarget]::User)
   [Environment]::SetEnvironmentVariable("CONFIGURATION_REPOSITORY_PATH", $configRepoPath, [System.EnvironmentVariableTarget]::User)

   # Immediate for current session
   $env:PROJECTS_PATH = $projectsPath
   $env:CONFIGURATION_REPOSITORY_PATH = $configRepoPath

   Write-Host "Environment variables set successfully ✅"
   Write-Host "PROJECTS_PATH = $env:PROJECTS_PATH"
   Write-Host "CONFIGURATION_REPOSITORY_PATH = $env:CONFIGURATION_REPOSITORY_PATH`n"
}

function Update-PowerShellProfile {
   param([string]$configRepoPath)
   $profilePath = $PROFILE
   $importLine = "Import-Module `$env:CONFIGURATION_REPOSITORY_PATH\powershell\main_script.ps1"

   if (-not (Test-Path $profilePath)) {
      New-Item -ItemType File -Path $profilePath -Force | Out-Null
   }

   $profileContent = Get-Content $profilePath -ErrorAction SilentlyContinue

   if (-not ($profileContent -contains $importLine)) {
      $newContent = @($importLine, "") + $profileContent
      Set-Content -Path $profilePath -Value $newContent
      Write-Host "PowerShell profile updated successfully ✅`n"
   }
   else {
      Write-Host "Import line already exists in PowerShell profile ✅`n"
   }
}

# --- Main Orchestration Function ---
function Run-Setup {
   $paths = Prompt-Paths
   $ProjectsPath = $paths[0]
   $ConfigRepoPath = $paths[1]

   $sshKeyName = "github_mastrauckas"
   $sshKeyPath = "$env:USERPROFILE\.ssh\$sshKeyName"

   Ensure-SSHKey -sshKeyPath $sshKeyPath
   Add-SSHKey-ToGitHub -sshKeyPath $sshKeyPath
   Install-Chocolatey
   Install-Git
   Enable-WindowsSudo
   Clone-ConfigRepo -repoPath $ConfigRepoPath
   Set-EnvironmentVariables -projectsPath $ProjectsPath -configRepoPath $ConfigRepoPath
   Update-PowerShellProfile -configRepoPath $ConfigRepoPath

   Write-Host "`n🎉 Setup completed successfully! All steps finished ✅"
}

# --- Execute Setup ---
Run-Setup
