param(
    [string]$CodexSkillsDir,
    [switch]$Force,
    [switch]$Backup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-OptionalPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($resolved) {
        return $resolved.Path
    }

    return $null
}

function Copy-OptionalShellScripts {
    param(
        [string]$SourceDir,
        [string]$DestinationDir
    )

    if ([string]::IsNullOrWhiteSpace($SourceDir)) {
        return
    }

    if (-not (Test-Path -LiteralPath $DestinationDir -PathType Container)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }

    $shellScripts = @(
        'check-creative-material.sh',
        'check-environment.sh',
        'process-reference-video-phase1.sh',
        'process-reference-videos-mix.sh',
        'start-reference-video.sh'
    )

    foreach ($scriptName in $shellScripts) {
        $scriptPath = Join-Path $SourceDir $scriptName
        if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
            Copy-Item -LiteralPath $scriptPath -Destination (Join-Path $DestinationDir $scriptName) -Force
        }
    }
}

$scriptParent = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$selfContainedSkill = Test-Path -LiteralPath (Join-Path $scriptParent.Path 'SKILL.md') -PathType Leaf
$source = if ($selfContainedSkill) {
    $scriptParent.Path
} else {
    Join-Path $scriptParent.Path 'skills\zk-creative-process'
}
$scriptsSource = Join-Path $source 'scripts'
$rootScriptsSource = if ($selfContainedSkill) {
    Resolve-OptionalPath (Join-Path $scriptParent.Path '..\..\scripts')
} else {
    Resolve-OptionalPath (Join-Path $scriptParent.Path 'scripts')
}
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Skill source not found: $source"
}
if (-not (Test-Path -LiteralPath $scriptsSource -PathType Container)) {
    $scriptsSource = Join-Path $scriptParent.Path 'scripts'
}
if (-not (Test-Path -LiteralPath $scriptsSource -PathType Container)) {
    throw "Bundled scripts not found. Expected scripts in the skill folder or repository root."
}

if ([string]::IsNullOrWhiteSpace($CodexSkillsDir)) {
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    if ([string]::IsNullOrWhiteSpace($homeDir)) {
        throw 'Cannot resolve home directory. Pass -CodexSkillsDir explicitly.'
    }
    $CodexSkillsDir = Join-Path (Join-Path $homeDir '.codex') 'skills'
}

New-Item -ItemType Directory -Path $CodexSkillsDir -Force | Out-Null
$destination = Join-Path $CodexSkillsDir 'zk-creative-process'
$sourceResolved = (Resolve-Path -LiteralPath $source).Path
$destinationResolved = if (Test-Path -LiteralPath $destination) {
    (Resolve-Path -LiteralPath $destination).Path
} else {
    [IO.Path]::GetFullPath($destination)
}

if ($sourceResolved -eq $destinationResolved) {
    "Skill is already installed at: $destinationResolved"
    exit 0
}

if (Test-Path -LiteralPath $destination) {
    if ($Backup) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$destination.backup-$stamp"
        Move-Item -LiteralPath $destination -Destination $backup
        "Existing skill backed up to: $backup"
    } elseif ($Force) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    } else {
        throw "Skill already exists: $destination. Rerun with -Backup to keep a backup, or -Force to replace it."
    }
}

Copy-Item -LiteralPath $source -Destination $destination -Recurse
$destinationScripts = Join-Path $destination 'scripts'
if (-not (Test-Path -LiteralPath $destinationScripts -PathType Container)) {
    Copy-Item -LiteralPath $scriptsSource -Destination $destinationScripts -Recurse
}
Copy-OptionalShellScripts -SourceDir $rootScriptsSource -DestinationDir $destinationScripts
"Installed zk-creative-process skill to: $destination"
"Bundled scripts copied to: $destinationScripts"
"Restart Codex or start a new session if the skill does not appear immediately."
