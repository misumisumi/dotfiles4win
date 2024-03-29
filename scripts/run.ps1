Param(
  [switch]$with_wsl,
  [switch]$with_komorebi
)

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
# DO NOT RUN ON ISE
# Set-ExecutionPolicy -Scope Process Unrestricted

$DOTFILES = "$env:USERPROFILE\.dotfiles"
$DOTFILES_GITURL = "https://github.com/misumisumi/dotfiles4win"
$NVIMDOTS_GITURL = "https://github.com/misumisumi/nvimdots"

# envs{{{
[System.Environment]::SetEnvironmentVariable("COURSIER_BIN_DIR", "$env:USERPROFILE\bin", "User")
[System.Environment]::SetEnvironmentVariable("GO111MODULE", "on", "User")
[System.Environment]::SetEnvironmentVariable("GOPATH", $env:USERPROFILE, "User")
[System.Environment]::SetEnvironmentVariable("PIPX_BIN_DIR", "$env:USERPROFILE\bin", "User")
[System.Environment]::SetEnvironmentVariable("PYTHONUSERBASE", "$env:USERPROFILE", "User")
[System.Environment]::SetEnvironmentVariable("JAVA_TOOL_OPTIONS", "-Dconsole.encoding=UTF-8 -Dfile.encoding=UTF-8", "User")
[System.Environment]::SetEnvironmentVariable("STARSHIP_CONFIG", "$env:USERPROFILE\.config\starship\starship.toml", "User")
[System.Environment]::SetEnvironmentVariable("KOMOREBI_CONFIG_HOME", "$env:USERPROFILE\.dotfiles\.config\komorebi", "User")
$newPath = @(
  "$env:USERPROFILE\.poetry\bin"
  "$env:USERPROFILE\.dotnet\tools"
  "$env:USERPROFILE\bin"
  "$env:USERPROFILE\scoop\shims"
  "$env:USERPROFILE\scoop\apps\python\current"
  "$env:USERPROFILE\scoop\apps\python\current\Scripts"
  "$env:USERPROFILE\scoop\apps\nodejs-lts\current\bin"
  "$env:USERPROFILE\scoop\apps\nodejs-lts\current"
  "$env:USERPROFILE\scoop\apps\ruby\current\gems\bin"
  "$env:USERPROFILE\scoop\apps\ruby\current\bin"
  "$env:USERPROFILE\scoop\apps\git\current\usr\bin"
  "$env:USERPROFILE\scoop\apps\git\current\mingw64\bin"
  "$env:USERPROFILE\scoop\apps\git\current\mingw64\libexec\git-core"
  "$env:LOCALAPPDATA\Programs\Python\Launcher"
  "$env:LOCALAPPDATA\Microsoft\WindowsApps"
  "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
) -join ";"

function Add-PathIfExists($Paths, $Path) {
  if (Test-Path -Path $Path) {
    $Paths += ";" + $Path
  }
  return $Paths
}

$newPath = Add-PathIfExists -Paths $newPath -Path "$env:ProgramFiles\Genymobile\Genymotion\tools"

$oldPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($oldPath -ne $newPath) {
  [System.Environment]::SetEnvironmentVariable("_PATH_" + (Get-Date -UFormat "%Y%m%d"), $oldPath, "User")
}
[System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
$env:PATH = $newPath + ";" + $env:PATH

switch ((Get-WmiObject -Class Win32_ComputerSystem).Model) {
  "Virtual Machine" {
    $isSandbox = $true
  }
  default {
    $isSandbox = $false
  }
}

# scoop
$ErrorActionPreference = "Stop"

try {
  Get-Command -Name scoop -ErrorAction Stop
}
catch [System.Management.Automation.CommandNotFoundException] {
  Invoke-Expression (new-object net.webclient).downloadstring("https://get.scoop.sh")
}

# git is required by `scoop bucket add *`
$UTILS = @(
  "aria2"
  "lessmsi"
  "dark"
  "7zip"
  "git"
)

scoop install $UTILS
scoop bucket add versions
scoop bucket add extras
scoop bucket add java
scoop bucket add my-bucket https://github.com/misumisumi/scoop-bucket
scoop update *

if (Test-Path ("$DOTFILES")) {
  Set-Location $DOTFILES
  git pull
}
else {
  git config --global core.autoCRLF false
  git clone --recursive $DOTFILES_GITURL $env:USERPROFILE\.dotfiles
  git clone --recursive $NVIMDOTS_GITURL $env:USERPROFILE\.config\nvim
}

scoop import $DOTFILES/pkgs/scoop.json
# scoop update --force "vscode-insiders"
scoop reset microsoft-lts-jdk

if ($isSandbox){
  iwr -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.3" -OutFile "$env:TEMP/ms_ui_xaml.zip"
  New-Item $env:TEMP/ms_ui_xaml -Force -ItemType Directory
  Expand-Archive "$env:TEMP/ms_ui_xaml.zip" -DestinationPath "$env:TEMP/ms_ui_xaml"
  Add-AppxPackage $env:TEMP/ms_ui_xaml/tools/AppX/x64/Release/Microsoft.UI.Xaml.2.7.appx
  del $env:TEMP/ms_ui_xaml.zip
  del -Recurse $env:TEMP/ms_ui_xaml
  @(
    "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx",
    "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
  )|foreach-object{
  [System.IO.Path]::GetTempFileName() | Tee  -Variable TempFile
  iwr -useb $_ -OutFile $TempFile
  Add-AppxPackage $TempFile
  del $TempFile
  }
}
else {
  wsl --install -d ubuntu
  wsl --update
}

# profile
$PSUSERHOME = $profile -replace "^(.*)\\.*$", "`$1" -replace "^(.*)\\.*$", "`$1"
## Windows Powershell
New-Item $PSUSERHOME\WindowsPowerShell -Force -ItemType Directory
## Powershell Core
New-Item $PSUSERHOME\PowerShell -Force -ItemType Directory
# Windows Terminal
New-Item -Path $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState -Force -ItemType Directory
# ssh
New-Item -Path $env:USERPROFILE\.ssh -Force -ItemType Directory
# chmod 600
icacls $env:USERPROFILE\.ssh /t /inheritance:r /grant $env:username":rw"
$DATE = Get-Date -Format "yyyy-MM-dd"
ssh-keygen -t ed25519 -C "$env:username@$env:computername-$DATE" -P "" -f $env:userprofile\.ssh\id_ed25519

# runas
Start-Process powershell.exe ("-NoProfile -Command cd " + $env:USERPROFILE + "\.dotfiles\scripts; .\run_admin.ps1 -with_wsl " + $with_wsl) -Verb runas

$env:PIPX_BIN_DIR = "$env:USERPROFILE\bin"
$env:PYTHONUSERBASE = "$env:USERPROFILE"
# pythonはscoopで入れるので`--user`をつける必要がない

# python3
python -m pip install --upgrade pip
$PIP3PACKAGES = @(
  "pipx"
  "pynvim"
)
foreach ($PIP3PACKAGE in $PIP3PACKAGES) {
  pip install $PIP3PACKAGE
}

$PIPXPACKAGES = @(
  # "docker-compose" Docker Desktopについてくる
  "httpie"
  "pipdeptree"
  "pipenv"
)

foreach ($PIPXPACKAGE in $PIPXPACKAGES) {
  pipx install --force $PIPXPACKAGE
}
pipx upgrade-all
(Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | py -

# ruby
$GEMPACKAGES = @(
  "neovim"
)
gem install $GEMPACKAGES

# nodejs
$NPMPACKAGES = @(
  "yarn"
  "npm-check-updates"
  "neovim"
)
npm install -g $NPMPACKAGES

# golang
$env:GO111MODULE = "on"
$env:GOPATH = $env:USERPROFILE

# security policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# add task scheduler
If($with_komorebi){
  $Trigger = New-ScheduledTaskTrigger -AtStartup
  $Action = New-ScheduledTaskAction -Execute "komorebi -a"
  Register-ScheduledTask -TaskName "Launch komorebi" -Action $Action -Trigger $Trigger
}

# install from local manifest
winget install -m ../manifests/f/FacebookTechnologies,LLC/OculusSetup/1.76.0.0
winget install -m ../manifests/p/Poineer/Rekordbox/6.7.6

# $GOPACKAGES = @(
#   "golang.org/x/tools/cmd/goimports"
#   "golang.org/x/tools/cmd/gopls"
#   "github.com/golangci/golangci-lint/cmd/golangci-lint@v1.14.1"
#   "github.com/boyter/scc"
# )
# Set-Location $env:USERPROFILE
# foreach ($GOPACKAGE in $GOPACKAGES) {
#   go get -u $GOPACKAGE
# }

# deprecated
# $deprecated_files = @(
#   "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json"
# )
# foreach ($deprecated_file in $deprecated_files) {
#   if (Test-Path -PathType Leaf $deprecated_file) {
#     Remove-Item -Force $deprecated_file
#   }
# }
# $deprecated_dirs = @(
#   "$env:APPDATA\Hyper"
# )
# foreach ($deprecated_dir in $deprecated_dirs) {
#   if (Test-Path -PathType Container $deprecated_dir) {
#     Remove-Item -Force -Recurse $deprecated_dir
#   }
# }
