param (
    [Parameter(ParameterSetName = "Install")]
    [switch]
    $Install,

    [Parameter(ParameterSetName = "Install", Mandatory = $false)]
    [System.String]
    $InstallDir = [String]::Empty,

    [Parameter(ParameterSetName = "Install")]
    [switch]
    $Clean,

    [Parameter(ParameterSetName = "Update")]
    [switch]
    $Update,

    [Parameter(ParameterSetName = "Remove")]
    [switch]
    $Remove
)


$ErrorActionPreference = "Stop"
Import-Module -Name "$(Get-Item "$PSScriptRoot/Z-PsCoreFxs.ps1")" -Force -NoClobber
Write-InfoDarkGray "▶▶▶ Running: $PSCommandPath"

$EMSDK_EXE = Select-ValueByPlatform "emsdk.bat" "emsdk" "emsdk"
$EMSCRIPTEN_SDK_REPO_URL = "https://github.com/emscripten-core/emsdk.git"

function Test-Requirements {
    Write-InfoBlue "Test Emscripten - Dependency tools"
    Write-Host

    Write-InfoMagenta "== Python"
    $command = Get-Command "python"
    Write-Host "$($command.Source)"
    & "$($command.Source)" --version
    Write-Host

    Write-InfoMagenta "== Git"
    $command = Get-Command "git"
    Write-Host "$($command.Source)"
    & "$($command.Source)" --version
    Write-Host
}

function Set-EnvironmentVariables {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "Set")]
        [string]
        $Path,

        [Parameter(ParameterSetName = "Clean")]
        [switch]
        $Clean
    )

    Write-Host
    Write-InfoBlue "Setting environment variables for Emscripten SDK"
    
    if ($Clean.IsPresent) {
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_SDK" -Value "" -Verbose
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_ROOT" -Value "" -Verbose
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_COMPILER" -Value "" -Verbose
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMCC" -Value "" -Verbose
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMRUN" -Value "" -Verbose
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMMAKE" -Value "" -Verbose
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMAR" -Value "" -Verbose
        Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMCONFIGURE" -Value "" -Verbose
        return
    }

    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_SDK" -Value "$Path" -Verbose
    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_ROOT" -Value "$env:EMSCRIPTEN_SDK/upstream/emscripten" -Verbose
    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_COMPILER" -Value "$env:EMSCRIPTEN_ROOT/$(Select-ValueByPlatform "em++.bat" "em++" "em++")" -Verbose
    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMCC" -Value "$env:EMSCRIPTEN_ROOT/$(Select-ValueByPlatform "emcc.bat" "emcc" "emcc")" -Verbose
    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMRUN" -Value "$env:EMSCRIPTEN_ROOT/$(Select-ValueByPlatform "emrun.bat" "emrun" "emrun")" -Verbose
    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMMAKE" -Value "$env:EMSCRIPTEN_ROOT/$(Select-ValueByPlatform "emmake.bat" "emmake" "emmake")" -Verbose
    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMAR" -Value "$env:EMSCRIPTEN_ROOT/$(Select-ValueByPlatform "emar.bat" "emar" "emar")" -Verbose
    Set-PersistentEnvironmentVariable -Name "EMSCRIPTEN_EMCONFIGURE" -Value "$env:EMSCRIPTEN_ROOT/$(Select-ValueByPlatform "emconfigure.bat" "emconfigure" "emconfigure")" -Verbose
}

function Install-EmscriptenSDK {
    param (
        [Parameter()]
        [string]
        $InstallDir,

        [Parameter()]
        [switch]
        $Clean
    )
    Write-Host
    Write-InfoBlue "█ Installing Emscripten SDK"
    Write-Host
    
    Test-Requirements
    
    $InstallDir = [string]::IsNullOrWhiteSpace($InstallDir) ? "$(Get-UserHome)/.emsdk" : $InstallDir
    if ((($Clean.IsPresent) -or (($InstallDir -ne $env:EMSCRIPTEN_SDK))) -and (![string]::IsNullOrWhiteSpace($env:EMSCRIPTEN_SDK))) {
        Write-InfoYellow "Removing old SDK folder if exists! ""$env:EMSCRIPTEN_SDK""."
        Remove-Item "$env:EMSCRIPTEN_SDK" -Force -Recurse -ErrorAction Ignore
    }
    Set-EnvironmentVariables -Path "$InstallDir"
    
    Write-Host "Installing on ""$InstallDir"""
    Install-GitRepository -Url "$EMSCRIPTEN_SDK_REPO_URL" -Path "$InstallDir" -Force
    git -C "$InstallDir" pull
    
    if ($IsLinux -or $IsMacOS) {
        chmod +x "$env:EMSCRIPTEN_SDK/$EMSDK_EXE"
    }
    Write-InfoMagenta "Installing SDK..."
    $null = Test-ExternalCommand """$env:EMSCRIPTEN_SDK/$EMSDK_EXE"" install latest" -ThrowOnFailure -ShowExitCode
    Write-InfoMagenta "Activating SDK..."
    $null = Test-ExternalCommand "$env:EMSCRIPTEN_SDK/$EMSDK_EXE activate latest " -ThrowOnFailure -ShowExitCode
    
}

function Update-EmscriptenSDK {
    Write-Host
    Write-InfoBlue "█ Updating Emscripten SDK"
    Write-Host
    $null = Test-ExternalCommand """$env:EMSCRIPTEN_SDK/$EMSDK_EXE"" update" -ThrowOnFailure
    $null = Test-ExternalCommand """$env:EMSCRIPTEN_SDK/$EMSDK_EXE"" install latest" -ThrowOnFailure
    $null = Test-ExternalCommand """$env:EMSCRIPTEN_SDK/$EMSDK_EXE"" activate latest" -ThrowOnFailure
}

function Remove-EmscriptenSDK {
    Write-Host
    Write-InfoBlue "█ Removing Emscripten SDK"
    Write-Host
    if (![string]::IsNullOrWhiteSpace($env:EMSCRIPTEN_SDK)) {
        Write-Warning "Removing SDK folder if exists! ""$env:EMSCRIPTEN_SDK""."
        Remove-Item "$env:EMSCRIPTEN_SDK" -Force -Recurse -ErrorAction Ignore
    }
    Set-EnvironmentVariables -Clean
}

if ($Install.IsPresent) {
    Install-EmscriptenSDK -InstallDir $InstallDir -Clean:$Clean
}

if ($Update.IsPresent) {
    Update-EmscriptenSDK
}

if ($Remove.IsPresent) {
    Remove-EmscriptenSDK
}