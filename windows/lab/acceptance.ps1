<#
.SYNOPSIS
Prepares and finalizes Fuwa's Windows 11 ARM64 native acceptance run.

.DESCRIPTION
Run this script only from the signed-in, unlocked winlab desktop session. The
Prepare phase verifies and installs the exact CI artifact, launches Fuwa, creates
safe test sources, and records UI Automation evidence. It deliberately leaves
the app installed for host-observed interaction. The Finalize phase requires a
graceful Fuwa exit, runs the normal uninstaller, and fails on declared residue.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Prepare', 'Finalize')]
    [string]$Phase,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$RunId,

    [Parameter(Mandatory)]
    [string]$EvidenceDirectory,

    [Parameter(Mandatory)]
    [ValidateRange(1, 65535)]
    [int]$ExpectedInteractiveSessionId,

    [Parameter(Mandatory)]
    [switch]$ConfirmDesktopUnlocked,

    [Parameter()]
    [string]$InstallerPath,

    [Parameter()]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedInstallerSha256,

    [Parameter()]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedExecutableSha256,

    [Parameter()]
    [string]$WinAppPath,

    [Parameter()]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$SourceCommit,

    [Parameter()]
    [string]$WorkflowRunUrl,

    [Parameter()]
    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
    [string]$ExpectedVersion = '0.1.3.4',

    [Parameter()]
    [ValidateRange(10, 600)]
    [int]$TimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DesktopGate {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $process = Get-Process -Id $PID
    $logonUi = @(
        Get-Process -Name LogonUI -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionId -eq $process.SessionId }
    )
    $accepted = (
        -not $identity.IsSystem -and
        $process.SessionId -ne 0 -and
        [Environment]::UserInteractive -and
        $process.SessionId -eq $ExpectedInteractiveSessionId -and
        $logonUi.Count -eq 0 -and
        [bool]$ConfirmDesktopUnlocked
    )

    [ordered]@{
        userName = $identity.Name
        isSystem = $identity.IsSystem
        processId = $PID
        sessionId = $process.SessionId
        expectedSessionId = $ExpectedInteractiveSessionId
        userInteractive = [Environment]::UserInteractive
        logonUiDetectedInSession = $logonUi.Count -gt 0
        desktopUnlockedConfirmed = [bool]$ConfirmDesktopUnlocked
        accepted = $accepted
    }
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [int[]]$AcceptedExitCodes = @(0)
    )

    $stdoutPath = Join-Path $EvidenceDirectory ($Name + '.stdout.log')
    $stderrPath = Join-Path $EvidenceDirectory ($Name + '.stderr.log')
    $parameters = @{
        FilePath = $FilePath
        PassThru = $true
        RedirectStandardOutput = $stdoutPath
        RedirectStandardError = $stderrPath
    }
    if ($ArgumentList.Count -gt 0) {
        $parameters.ArgumentList = $ArgumentList
    }

    $startedAt = [DateTimeOffset]::UtcNow
    $process = Start-Process @parameters
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        $taskKillPath = Join-Path $env:SystemRoot 'System32\taskkill.exe'
        $cleanup = Start-Process -FilePath $taskKillPath -ArgumentList @(
            '/PID', [string]$process.Id, '/T', '/F'
        ) -PassThru -WindowStyle Hidden
        if (-not $cleanup.WaitForExit(30000) -or $cleanup.ExitCode -ne 0) {
            throw "$Name timed out and bounded process-tree cleanup was not verified. Stop automation and inspect the guest."
        }
        throw "$Name timed out after $TimeoutSeconds seconds; the process tree was terminated and the action was not retried."
    }

    $exitCode = $process.ExitCode
    $result = [ordered]@{
        startedAtUtc = $startedAt.ToString('o')
        completedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
        processId = $process.Id
        exitCode = $exitCode
        stdoutFile = Split-Path -Leaf $stdoutPath
        stderrFile = Split-Path -Leaf $stderrPath
        succeeded = $exitCode -in $AcceptedExitCodes
    }
    if (-not $result.succeeded) {
        throw "$Name exited with code $($result.exitCode)."
    }
    $result
}

function Get-PeArchitecture {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $reader = New-Object IO.BinaryReader($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) {
            throw 'Installed executable has no valid MZ header.'
        }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadUInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw 'Installed executable has no valid PE signature.'
        }
        $machine = $reader.ReadUInt16()
        switch ($machine) {
            0xAA64 { 'arm64' }
            0x8664 { 'x64' }
            default { 'unknown-0x{0:X4}' -f $machine }
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Write-Evidence {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [object]$Value
    )

    $destination = Join-Path $EvidenceDirectory $Name
    $temporary = $destination + '.tmp'
    if (Test-Path -LiteralPath $destination) {
        throw "Evidence file already exists; use a fresh disposable product slot: $destination"
    }
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $destination
}

function Wait-ForPathState {
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths,

        [Parameter(Mandatory)]
        [bool]$ShouldExist
    )

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(30)
    do {
        $mismatches = @(
            $Paths | Where-Object {
                (Test-Path -LiteralPath $_) -ne $ShouldExist
            }
        )
        if ($mismatches.Count -eq 0) {
            return @()
        }
        Start-Sleep -Seconds 1
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    @($mismatches)
}

$desktopGate = Get-DesktopGate
if (-not $desktopGate.accepted) {
    throw 'Interactive desktop gate failed. Run inside the signed-in, unlocked winlab session, never through SYSTEM/session 0.'
}

New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
$EvidenceDirectory = (Resolve-Path -LiteralPath $EvidenceDirectory).Path

$installDirectory = Join-Path $env:LOCALAPPDATA 'Programs\Fuwa'
$applicationPath = Join-Path $installDirectory 'Fuwa.exe'
$uninstallerPath = Join-Path $installDirectory 'unins000.exe'
$startMenuLink = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Fuwa\Fuwa.lnk'
$desktopLink = Join-Path `
    ([Environment]::GetFolderPath(
        [Environment+SpecialFolder]::DesktopDirectory
    )) `
    'Fuwa.lnk'
$uninstallRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\app.yuxino.fuwa.windows_is1'
$declaredArtifacts = @(
    $applicationPath,
    $uninstallerPath,
    $startMenuLink,
    $desktopLink,
    $uninstallRegistryPath
)

if ($Phase -eq 'Prepare') {
    foreach ($required in @(
            'InstallerPath',
            'ExpectedInstallerSha256',
            'ExpectedExecutableSha256',
            'WinAppPath',
            'SourceCommit',
            'WorkflowRunUrl'
        )) {
        if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $required -ValueOnly))) {
            throw "-$required is required for the Prepare phase."
        }
    }
    if (Get-Process -Name Fuwa -ErrorAction SilentlyContinue) {
        throw 'Fuwa is already running. Start from a clean disposable product slot.'
    }
    $preexistingArtifacts = @(
        $declaredArtifacts | Where-Object { Test-Path -LiteralPath $_ }
    )
    if ($preexistingArtifacts.Count -gt 0) {
        throw (
            'Fuwa installation residue already exists. Start from a clean ' `
                + 'disposable product slot: ' `
                + ($preexistingArtifacts -join ', ')
        )
    }
    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        throw "Installer not found: $InstallerPath"
    }
    if (-not (Test-Path -LiteralPath $WinAppPath -PathType Leaf)) {
        throw "WinApp CLI not found: $WinAppPath"
    }

    $actualInstallerSha256 = (Get-FileHash -LiteralPath $InstallerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualInstallerSha256 -ne $ExpectedInstallerSha256.ToLowerInvariant()) {
        throw 'Installer SHA-256 does not match the host-staged acceptance manifest.'
    }

    $installLog = Join-Path $EvidenceDirectory 'installer.log'
    $install = Invoke-BoundedProcess -FilePath $InstallerPath -Name 'installer' -ArgumentList @(
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CURRENTUSER',
        ('/LOG="{0}"' -f $installLog)
    )
    $missing = Wait-ForPathState -Paths $declaredArtifacts -ShouldExist $true
    if ($missing.Count -gt 0) {
        throw ('Installer did not create declared artifacts: ' + ($missing -join ', '))
    }

    $architecture = Get-PeArchitecture -Path $applicationPath
    if ($architecture -ne 'arm64') {
        throw "The installed executable is $architecture, not native ARM64."
    }
    $actualExecutableSha256 = (
        Get-FileHash -LiteralPath $applicationPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($actualExecutableSha256 -ne $ExpectedExecutableSha256.ToLowerInvariant()) {
        throw 'The installed executable does not match the CI-verified Fuwa.exe payload.'
    }
    $fileVersion = (Get-Item -LiteralPath $applicationPath).VersionInfo.FileVersion
    if ($fileVersion -ne $ExpectedVersion) {
        throw "Installed file version is $fileVersion, expected $ExpectedVersion."
    }

    $application = Start-Process -FilePath $applicationPath -PassThru
    Start-Sleep -Seconds 3
    $application.Refresh()
    if ($application.HasExited) {
        throw "Fuwa exited during launch with code $($application.ExitCode)."
    }
    if ($application.SessionId -ne $ExpectedInteractiveSessionId) {
        throw 'Fuwa launched outside the expected interactive session.'
    }

    $uiStatus = Invoke-BoundedProcess -FilePath $WinAppPath -Name 'fuwa-ui-status' -ArgumentList @(
        'ui', 'status', '-a', [string]$application.Id, '--json'
    )
    $uiTree = Invoke-BoundedProcess -FilePath $WinAppPath -Name 'fuwa-ui-tree' -ArgumentList @(
        'ui', 'inspect', '-a', [string]$application.Id, '--depth', '6', '--json'
    )
    $controlScreenshot = Join-Path $EvidenceDirectory '01-control-window.png'
    $screenshot = Invoke-BoundedProcess -FilePath $WinAppPath -Name 'fuwa-control-screenshot' -ArgumentList @(
        'ui', 'screenshot', '-a', [string]$application.Id,
        '--capture-screen', '--output', $controlScreenshot, '--json'
    )
    if (-not (Test-Path -LiteralPath $controlScreenshot -PathType Leaf)) {
        throw 'WinApp did not create the declared control-window screenshot.'
    }

    $safeSourceDirectory = Join-Path $env:TEMP ("FuwaNativeAcceptance-$RunId")
    if (Test-Path -LiteralPath $safeSourceDirectory) {
        throw 'The safe source directory already exists. Do not reuse a previous product attempt.'
    }
    New-Item -ItemType Directory -Path $safeSourceDirectory | Out-Null
    $safeSourceFile = Join-Path $safeSourceDirectory 'Fuwa acceptance source.txt'
    'Fuwa acceptance live frame A' | Set-Content -LiteralPath $safeSourceFile -Encoding UTF8
    $notepad = Start-Process -FilePath 'notepad.exe' -ArgumentList @(
        ('"{0}"' -f $safeSourceFile)
    ) -PassThru
    Start-Process -FilePath 'explorer.exe' -ArgumentList @(
        ('"{0}"' -f $safeSourceDirectory)
    ) | Out-Null
    Start-Sleep -Seconds 3
    $windowList = Invoke-BoundedProcess -FilePath $WinAppPath -Name 'visible-window-list' -ArgumentList @(
        'ui', 'list-windows', '--json'
    )

    $signature = Get-AuthenticodeSignature -LiteralPath $applicationPath
    $summary = [ordered]@{
        schemaVersion = 1
        phase = 'prepare'
        status = 'passed-awaiting-host-observed-interaction'
        runId = $RunId
        sourceCommit = $SourceCommit.ToLowerInvariant()
        workflowRunUrl = $WorkflowRunUrl
        completedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
        desktopGate = $desktopGate
        artifact = [ordered]@{
            fileName = Split-Path -Leaf $InstallerPath
            sha256 = $actualInstallerSha256
            expectedExecutableSha256 = $ExpectedExecutableSha256.ToLowerInvariant()
            installedExecutableSha256 = $actualExecutableSha256
            architecture = $architecture
            fileVersion = $fileVersion
            signatureStatus = [string]$signature.Status
        }
        install = $install
        launch = [ordered]@{
            processId = $application.Id
            sessionId = $application.SessionId
            running = -not $application.HasExited
        }
        safeSources = [ordered]@{
            directory = $safeSourceDirectory
            notepadFile = $safeSourceFile
            notepadProcessId = $notepad.Id
        }
        uiAutomation = [ordered]@{
            status = $uiStatus
            tree = $uiTree
            screenshot = $screenshot
            windowList = $windowList
        }
        nativeInteractionAccepted = $false
        note = 'Host-observed live mirror, topmost, taskbar, tray, source-loss, quit, and safe screenshots remain required.'
    }
    Write-Evidence -Name 'prepare-summary.json' -Value $summary
    $summary | ConvertTo-Json -Depth 12
    exit 0
}

$prepareSummaryPath = Join-Path $EvidenceDirectory 'prepare-summary.json'
if (-not (Test-Path -LiteralPath $prepareSummaryPath -PathType Leaf)) {
    throw 'prepare-summary.json is missing; Finalize cannot stand alone as acceptance evidence.'
}
$prepareSummary = Get-Content -LiteralPath $prepareSummaryPath -Raw |
    ConvertFrom-Json
if (
    $prepareSummary.schemaVersion -ne 1 -or
    $prepareSummary.phase -cne 'prepare' -or
    $prepareSummary.status -cne 'passed-awaiting-host-observed-interaction' -or
    $prepareSummary.runId -cne $RunId
) {
    throw 'prepare-summary.json does not belong to this accepted run and phase.'
}
if (Get-Process -Name Fuwa -ErrorAction SilentlyContinue) {
    throw 'Fuwa is still running. Exit through the observed tray Quit command before Finalize; this script will not force-kill acceptance evidence.'
}
if (-not (Test-Path -LiteralPath $uninstallerPath -PathType Leaf)) {
    throw "Uninstaller not found: $uninstallerPath"
}

$uninstall = Invoke-BoundedProcess -FilePath $uninstallerPath -Name 'uninstaller' -ArgumentList @(
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART'
)
$remaining = Wait-ForPathState -Paths $declaredArtifacts -ShouldExist $false
$remainingProcesses = @(Get-Process -Name Fuwa -ErrorAction SilentlyContinue)
$installDirectoryRemains = Test-Path -LiteralPath $installDirectory
$passed = (
    $remaining.Count -eq 0 -and
    $remainingProcesses.Count -eq 0 -and
    -not $installDirectoryRemains
)

$summary = [ordered]@{
    schemaVersion = 1
    phase = 'finalize'
    status = if ($passed) { 'passed' } else { 'failed' }
    runId = $RunId
    completedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    desktopGate = $desktopGate
    uninstall = $uninstall
    remainingDeclaredArtifacts = @($remaining)
    remainingProcesses = @($remainingProcesses | ForEach-Object {
        [ordered]@{ name = $_.ProcessName; processId = $_.Id; sessionId = $_.SessionId }
    })
    installDirectoryRemains = $installDirectoryRemains
}
Write-Evidence -Name 'finalize-summary.json' -Value $summary
if (-not $passed) {
    throw 'Uninstall left a declared process, executable, install directory, shortcut, or registry entry.'
}
$summary | ConvertTo-Json -Depth 12
