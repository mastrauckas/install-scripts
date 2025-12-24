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

function Install-Git {
   if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Write-Host "Installing Git via winget..."
      winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
      Write-Host "Git installed successfully."
   }
   else {
      Write-Host "Git is already installed."
   }
}

# ==========================================================
# >>> Added Function: Configure-Git
# ==========================================================
function Set-GitConfig {
    $answer = Read-Host "Do you want to apply the recommended Git configuration? (y/n)"
    if ($answer -notin @("y","Y")) {
        Write-Host "Skipping Git configuration."
        return
    }

    $gitName = Read-Host "Enter your Git user.name"
    $gitEmail = Read-Host "Enter your Git user.email"

    if ([string]::IsNullOrWhiteSpace($gitName) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
        Write-Host "Git name/email cannot be empty. Skipping Git configuration."
        return
    }

    Write-Host "Applying Git configuration..."

    git config --global user.name "$gitName"
    git config --global user.email "$gitEmail"

    git config --global core.autocrlf input
    git config --global core.fscache true
    git config --global core.untrackedCache true
    git config --global core.preloadIndex true
    git config --system core.longpaths true
    git config --global credential.helper manager
    git config --global merge.ff only
    git config --global pull.ff only
    git config --global color.ui auto
    git config --global advice.detachedHead false
    git config --global fetch.prune true
    git config --global push.default simple

    git config --global alias.st "status -sb"
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.last "log -1 HEAD"
    git config --global alias.lg "log --oneline --decorate --graph --all"

    $globalGitIgnore = "$HOME\.gitignore_global"

@"
.vscode/
.vs/
bin/
obj/
node_modules/
*.user
*.suo
*.swp
*.tmp
Thumbs.db
"@ | Out-File -Encoding utf8 $globalGitIgnore

    git config --global core.excludesfile "$globalGitIgnore"

    Write-Host "`nGit configuration applied successfully." -ForegroundColor Green
    git config --global --list
}

function Install-VSCodeInsiders {
   if (-not (Get-Command code-insiders -ErrorAction SilentlyContinue)) {
      Write-Host "Installing VS Code Insiders via winget..."
      winget install --id Microsoft.VisualStudioCode.Insiders -e --source winget --accept-package-agreements --accept-source-agreements
      Write-Host "VS Code Insiders installed successfully."
   }
   else {
      Write-Host "VS Code Insiders is already installed."
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

# ==========================================================
# >>> Time/Date Configuration Functions
# ==========================================================

function Get-WindowsVersionInfo {
   # Retrieves Windows version information for OS-specific features
   $winVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
   return @{
      Major = [int]$winVersion.CurrentMajorVersionNumber
      Build = [int]$winVersion.CurrentBuildNumber
      IsWin11_22H2OrLater = ([int]$winVersion.CurrentBuildNumber -ge 22621)
      IsWin11 = ([int]$winVersion.CurrentBuildNumber -ge 22000)
      IsWin10 = ([int]$winVersion.CurrentMajorVersionNumber -eq 10)
   }
}

function Set-InternationalSettings {
   # Configure calendar type, first day of week, and date/time formats
   Write-Host "`nConfiguring international settings..."

   $path = "HKCU:\Control Panel\International"

   # Define target settings
   $settings = @{
      iCalendarType = "1"              # 1=Gregorian Calendar
      iFirstDayOfWeek = "6"            # 6=Sunday, 0=Monday
      sShortDate = "MM/dd/yyyy"        # Short date format (e.g., 04/05/2017)
      sLongDate = "dddd, MMMM d, yyyy" # Long date format (e.g., Wednesday, April 5, 2017)
      sShortTime = "h:mm tt"           # Short time format (e.g., 9:40 AM)
   }

   try {
      foreach ($key in $settings.Keys) {
         $targetValue = $settings[$key]
         $currentValue = (Get-ItemProperty -Path $path -Name $key -ErrorAction SilentlyContinue).$key

         if ($currentValue -ne $targetValue) {
            Set-ItemProperty -Path $path -Name $key -Value $targetValue -Type String -Force
            Write-Host "  Set $key to '$targetValue'"
         }
         else {
            Write-Host "  $key already set to '$targetValue' (skipped)"
         }
      }
      Write-Host "  International settings applied." -ForegroundColor Green
   }
   catch {
      Write-Host "  Failed to apply international settings: $_" -ForegroundColor Red
   }
}

function Enable-TrayClockSeconds {
   # Enable "show seconds in system tray clock" (Windows 11 22H2+ only)
   param([hashtable]$versionInfo)

   Write-Host "`nConfiguring system tray clock..."

   if ($versionInfo.IsWin11_22H2OrLater) {
      $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
      $keyName = "ShowSecondsInSystemClock"
      $targetValue = 1

      try {
         $currentValue = (Get-ItemProperty -Path $path -Name $keyName -ErrorAction SilentlyContinue).$keyName

         if ($currentValue -ne $targetValue) {
            Set-ItemProperty -Path $path -Name $keyName -Value $targetValue -Type DWord -Force
            Write-Host "  Enabled 'Show seconds in system tray clock'"
         }
         else {
            Write-Host "  'Show seconds in system tray clock' already enabled (skipped)"
         }
         Write-Host "  System tray clock configured." -ForegroundColor Green
      }
      catch {
         Write-Host "  Failed to enable tray clock seconds: $_" -ForegroundColor Red
      }
   }
   else {
      Write-Host "  Show seconds in tray clock requires Windows 11 22H2+ (build 22621+). Skipping." -ForegroundColor Yellow
   }
}

function Set-SystemTimeZone {
   # Set system timezone to Eastern Time
   Write-Host "`nConfiguring system timezone..."

   $targetTimeZone = "Eastern Standard Time"

   try {
      $currentTimeZone = (Get-TimeZone).Id

      if ($currentTimeZone -ne $targetTimeZone) {
         Set-TimeZone -Id $targetTimeZone
         Write-Host "  Set system timezone to '$targetTimeZone'"
      }
      else {
         Write-Host "  System timezone already set to '$targetTimeZone' (skipped)"
      }
      Write-Host "  System timezone configured." -ForegroundColor Green
   }
   catch {
      Write-Host "  Failed to set system timezone: $_" -ForegroundColor Red
   }
}

function Add-AdditionalClockUTC {
   # Add UTC as additional clock in taskbar
   Write-Host "`nConfiguring additional clock (UTC)..."

   # Correct registry path for additional clocks
   $path = "HKCU:\Control Panel\TimeDate\AdditionalClocks\1"

   try {
      # Ensure the registry path exists
      if (-not (Test-Path $path)) {
         New-Item -Path $path -Force | Out-Null
      }

      # Enable additional clock 1
      $currentEnabled = (Get-ItemProperty -Path $path -Name "Enable" -ErrorAction SilentlyContinue).Enable
      if ($currentEnabled -ne 1) {
         Set-ItemProperty -Path $path -Name "Enable" -Value 1 -Type DWord -Force
         Write-Host "  Enabled additional clock 1"
      }
      else {
         Write-Host "  Additional clock 1 already enabled (skipped)"
      }

      # Set clock display name
      $currentName = (Get-ItemProperty -Path $path -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
      if ($currentName -ne "UTC") {
         Set-ItemProperty -Path $path -Name "DisplayName" -Value "UTC" -Type String -Force
         Write-Host "  Set additional clock display name to 'UTC'"
      }
      else {
         Write-Host "  Additional clock display name already set to 'UTC' (skipped)"
      }

      # Set timezone to UTC
      $currentTZ = (Get-ItemProperty -Path $path -Name "TzRegKeyName" -ErrorAction SilentlyContinue).TzRegKeyName
      if ($currentTZ -ne "UTC") {
         Set-ItemProperty -Path $path -Name "TzRegKeyName" -Value "UTC" -Type String -Force
         Write-Host "  Set additional clock timezone to UTC"
      }
      else {
         Write-Host "  Additional clock timezone already set to UTC (skipped)"
      }

      Write-Host "  Additional clock configured." -ForegroundColor Green
   }
   catch {
      Write-Host "  Failed to configure additional clock: $_" -ForegroundColor Red
   }
}

function Set-TimeDateSettings {
   # Main orchestrator for time/date configuration
   Write-Host "`nConfiguring time and date settings..." -ForegroundColor Cyan

   $versionInfo = Get-WindowsVersionInfo
   Write-Host "Detected Windows Version: $($versionInfo.Major) Build $($versionInfo.Build)"

   Set-SystemTimeZone
   Set-InternationalSettings
   Enable-TrayClockSeconds -versionInfo $versionInfo
   Add-AdditionalClockUTC

   Write-Host "`nTime/date settings applied successfully!" -ForegroundColor Green
   Write-Host "Note: Some changes may require logging out and back in to take effect." -ForegroundColor Yellow
}

function Set-SSHConfig {
   param([string]$privateKey)

   $sshDir = Join-Path $env:USERPROFILE ".ssh"
   $configFile = Join-Path $sshDir "config"

   if (-not (Test-Path $configFile)) {
      Write-Host "SSH config file not found. Creating new one..."
      New-Item -Path $configFile -ItemType File | Out-Null
   }

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

function Set-SSHKey {
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

   Set-SSHConfig -privateKey $privateKey

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

function Initialize-ConfigRepository {
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

   $pwsh7Profile = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

   if (-not (Test-Path $pwsh7Profile)) {
      Write-Host "PowerShell 7 profile not found. Creating profile at $pwsh7Profile..."
      New-Item -ItemType File -Path $pwsh7Profile -Force | Out-Null
   }

   $importLine = @'
try {
    . "$env:CONFIGURATION_REPOSITORY_PATH\powershell\main_script.ps1"
}
catch {
    Write-Host "Error importing module: $_"
}
'@

   $existing = Get-Content $pwsh7Profile
   if (-not ($existing -contains $importLine)) {
      if ($existing.Count -gt 0) {
         Add-Content -Path $pwsh7Profile -Value "`n$importLine"
      }
      else {
         Add-Content -Path $pwsh7Profile -Value $importLine
      }
      Write-Host "Import line added successfully."
   }
   else {
      Write-Host "Import line already exists in PowerShell 7 profile. No changes made."
   }
}

# --- Main workflow ---
function Main {
   $ProjectsPath = Read-Host "Enter the PROJECTS_PATH (default: C:\Projects)"
   if ([string]::IsNullOrWhiteSpace($ProjectsPath)) { $ProjectsPath = "C:\Projects" }

   if (-not (Test-Path $ProjectsPath)) { New-Item -ItemType Directory -Path $ProjectsPath | Out-Null }

   $ConfigRepoPathDefault = Join-Path $ProjectsPath "configurations"
   $ConfigRepoPath = Read-Host "Enter the CONFIGURATION_REPOSITORY_PATH (default: $ConfigRepoPathDefault)"
   if ([string]::IsNullOrWhiteSpace($ConfigRepoPath)) { $ConfigRepoPath = $ConfigRepoPathDefault }

   Install-PowerShell
   Install-Chocolatey
   Install-Git

   # ==========================================================
   # >>> Call added Configure-Git function
   # ==========================================================
   Set-GitConfig

   Install-VSCodeInsiders
   Enable-NativeSudo
   Set-TimeDateSettings

   Set-SSHKey -sshKeyName "github_mastrauckas"

   $repoUrl = "git@github.com:mastrauckas/configurations.git"
   Initialize-ConfigRepository -repoUrl $repoUrl -destination $ConfigRepoPath

   Write-Debug "Line 1"
   Set-EnvironmentVariables -projectsPath $ProjectsPath -configRepoPath $ConfigRepoPath
   Write-Debug "Line 2"

   Update-Pwsh7Profile -configRepoPath $ConfigRepoPath
   Write-Debug "Line 3"

   Write-Host "`n✅ Setup completed successfully!"
}

# --- Execute main workflow ---
Main
