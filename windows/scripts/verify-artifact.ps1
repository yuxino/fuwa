[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ExecutablePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InstallerPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('x64', 'arm64')]
    [string]$ExpectedArchitecture,

    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
    [string]$ExpectedVersion = '0.1.1.2',

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Resolve-RequiredFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    Assert-Condition `
        -Condition (Test-Path -LiteralPath $fullPath -PathType Leaf) `
        -Message "$Label does not exist as a file: $fullPath"

    return (Get-Item -LiteralPath $fullPath).FullName
}

function Get-Sha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-PeMachine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    Assert-Condition `
        -Condition ($bytes.LongLength -ge 64) `
        -Message "PE file is too small: $Path"
    Assert-Condition `
        -Condition ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) `
        -Message "PE file is missing the MZ signature: $Path"

    $peOffset = [System.BitConverter]::ToInt32($bytes, 0x3C)
    Assert-Condition `
        -Condition ($peOffset -ge 0) `
        -Message "PE header offset is negative: $Path"
    Assert-Condition `
        -Condition (([long]$peOffset + 6L) -le $bytes.LongLength) `
        -Message "PE header is outside the file: $Path"
    Assert-Condition `
        -Condition ([System.BitConverter]::ToUInt32($bytes, $peOffset) -eq 0x00004550) `
        -Message "PE file is missing the PE signature: $Path"

    $machine = [System.BitConverter]::ToUInt16($bytes, $peOffset + 4)
    $architecture = switch ([int]$machine) {
        0x014C { 'x86' }
        0x8664 { 'x64' }
        0xAA64 { 'arm64' }
        default { 'unknown' }
    }

    return [pscustomobject][ordered]@{
        value = [int]$machine
        hex = ('0x{0:X4}' -f $machine)
        architecture = $architecture
    }
}

function Get-FixedVersionEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $versionInfo = (Get-Item -LiteralPath $Path).VersionInfo
    $fileVersion = '{0}.{1}.{2}.{3}' -f `
        $versionInfo.FileMajorPart, `
        $versionInfo.FileMinorPart, `
        $versionInfo.FileBuildPart, `
        $versionInfo.FilePrivatePart
    $productVersion = '{0}.{1}.{2}.{3}' -f `
        $versionInfo.ProductMajorPart, `
        $versionInfo.ProductMinorPart, `
        $versionInfo.ProductBuildPart, `
        $versionInfo.ProductPrivatePart

    return [pscustomobject][ordered]@{
        fileVersion = $fileVersion
        productVersion = $productVersion
        fileVersionString = [string]$versionInfo.FileVersion
        productVersionString = [string]$versionInfo.ProductVersion
        originalFilename = [string]$versionInfo.OriginalFilename
    }
}

function Read-ManifestPolicy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null

    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    $document = New-Object System.Xml.XmlDocument
    $document.XmlResolver = $null
    try {
        $document.Load($reader)
    }
    finally {
        $reader.Dispose()
    }

    $privilegeNodes = $document.SelectNodes(
        "//*[local-name()='requestedExecutionLevel']"
    )
    Assert-Condition `
        -Condition ($privilegeNodes.Count -eq 1) `
        -Message 'Manifest must contain exactly one requestedExecutionLevel element.'

    $privilegeNode = $privilegeNodes.Item(0)
    $level = $privilegeNode.GetAttribute('level')
    $uiAccess = $privilegeNode.GetAttribute('uiAccess')
    Assert-Condition `
        -Condition ($level -ceq 'asInvoker') `
        -Message "Manifest execution level must be asInvoker, found: $level"
    Assert-Condition `
        -Condition ($uiAccess -ceq 'false') `
        -Message "Manifest uiAccess must be false, found: $uiAccess"

    $identityNodes = $document.SelectNodes(
        "/*[local-name()='assembly']/*[local-name()='assemblyIdentity']"
    )
    Assert-Condition `
        -Condition ($identityNodes.Count -eq 1) `
        -Message 'Manifest must contain exactly one root assemblyIdentity element.'

    $autoElevateNodes = $document.SelectNodes("//*[local-name()='autoElevate']")
    Assert-Condition `
        -Condition ($autoElevateNodes.Count -eq 0) `
        -Message 'Manifest must not contain an autoElevate element.'

    $identityNode = $identityNodes.Item(0)
    return [pscustomobject][ordered]@{
        requestedExecutionLevel = $level
        uiAccess = $uiAccess
        autoElevate = $false
        assemblyName = $identityNode.GetAttribute('name')
        assemblyVersion = $identityNode.GetAttribute('version')
    }
}

function Find-DumpBinPath {
    $commands = @(Get-Command dumpbin.exe -CommandType Application -ErrorAction SilentlyContinue)
    if ($commands.Count -gt 0) {
        return $commands[0].Path
    }

    $vcToolsInstallDirectory = [System.Environment]::GetEnvironmentVariable(
        'VCToolsInstallDir'
    )
    if (-not [string]::IsNullOrWhiteSpace($vcToolsInstallDirectory)) {
        $relativeCandidates = @(
            'bin\Hostx64\x64\dumpbin.exe',
            'bin\Hostx64\arm64\dumpbin.exe',
            'bin\Hostarm64\arm64\dumpbin.exe',
            'bin\Hostx86\x86\dumpbin.exe'
        )
        foreach ($relativePath in $relativeCandidates) {
            $candidate = Join-Path $vcToolsInstallDirectory $relativePath
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return (Get-Item -LiteralPath $candidate).FullName
            }
        }
    }

    $programFilesX86 = [System.Environment]::GetEnvironmentVariable(
        'ProgramFiles(x86)'
    )
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $vswherePath = Join-Path `
            $programFilesX86 `
            'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path -LiteralPath $vswherePath -PathType Leaf) {
            $installations = @(
                & $vswherePath `
                    -products '*' `
                    -latest `
                    -property installationPath
            )
            Assert-Condition `
                -Condition ($LASTEXITCODE -eq 0) `
                -Message "vswhere failed with exit code $LASTEXITCODE."

            foreach ($installation in $installations) {
                if ([string]::IsNullOrWhiteSpace([string]$installation)) {
                    continue
                }

                $msvcRoot = Join-Path ([string]$installation) 'VC\Tools\MSVC'
                if (-not (Test-Path -LiteralPath $msvcRoot -PathType Container)) {
                    continue
                }

                $toolVersions = @(
                    Get-ChildItem -LiteralPath $msvcRoot -Directory |
                        Sort-Object -Property Name -Descending
                )
                $relativeCandidates = @(
                    'bin\Hostx64\x64\dumpbin.exe',
                    'bin\Hostx64\arm64\dumpbin.exe',
                    'bin\Hostarm64\arm64\dumpbin.exe',
                    'bin\Hostx86\x86\dumpbin.exe'
                )
                foreach ($toolVersion in $toolVersions) {
                    foreach ($relativePath in $relativeCandidates) {
                        $candidate = Join-Path $toolVersion.FullName $relativePath
                        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                            return (Get-Item -LiteralPath $candidate).FullName
                        }
                    }
                }
            }
        }
    }

    throw 'dumpbin.exe was not found. Run the script from an MSVC developer environment or install the Visual C++ build tools.'
}

function Find-MtPath {
    $commands = @(Get-Command mt.exe -CommandType Application -ErrorAction SilentlyContinue)
    if ($commands.Count -gt 0) {
        return $commands[0].Path
    }

    $sdkBinDirectories = @()
    foreach ($environmentVariable in @(
            'WindowsSdkVerBinPath',
            'WindowsSdkBinPath'
        )) {
        $value = [System.Environment]::GetEnvironmentVariable(
            $environmentVariable
        )
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $sdkBinDirectories += [System.IO.Path]::GetFullPath($value)
        }
    }

    foreach ($sdkBinDirectory in $sdkBinDirectories) {
        foreach ($relativePath in @(
                'x64\mt.exe',
                'arm64\mt.exe',
                'x86\mt.exe',
                'mt.exe'
            )) {
            $candidate = Join-Path $sdkBinDirectory $relativePath
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return (Get-Item -LiteralPath $candidate).FullName
            }
        }
    }

    $programFilesX86 = [System.Environment]::GetEnvironmentVariable(
        'ProgramFiles(x86)'
    )
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $windowsKitsBin = Join-Path $programFilesX86 'Windows Kits\10\bin'
        if (Test-Path -LiteralPath $windowsKitsBin -PathType Container) {
            $sdkVersions = @(
                Get-ChildItem -LiteralPath $windowsKitsBin -Directory |
                    Sort-Object -Property Name -Descending
            )
            foreach ($sdkVersion in $sdkVersions) {
                foreach ($relativePath in @(
                        'x64\mt.exe',
                        'arm64\mt.exe',
                        'x86\mt.exe'
                    )) {
                    $candidate = Join-Path $sdkVersion.FullName $relativePath
                    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                        return (Get-Item -LiteralPath $candidate).FullName
                    }
                }
            }
        }
    }

    throw 'mt.exe was not found. Run the script from a Windows SDK developer environment or install the Windows SDK.'
}

function Extract-EmbeddedManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MtPath,

        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $inputResourceArgument = '-inputresource:{0};#1' -f $ExecutablePath
    $outputArgument = '-out:{0}' -f $DestinationPath
    $mtOutput = @(
        & $MtPath -nologo $inputResourceArgument $outputArgument 2>&1
    )
    $mtExitCode = $LASTEXITCODE
    if ($mtExitCode -ne 0) {
        $diagnostic = $mtOutput | Out-String -Width 4096
        throw (
            "mt.exe could not extract Fuwa.exe RT_MANIFEST #1 " `
                + "(exit $mtExitCode): $($diagnostic.Trim())"
        )
    }
    Assert-Condition `
        -Condition (Test-Path -LiteralPath $DestinationPath -PathType Leaf) `
        -Message 'mt.exe reported success without producing an embedded manifest.'
}

function Inspect-ExecutableImports {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DumpBinPath,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $dumpBinOutput = @(& $DumpBinPath /nologo /imports $Path 2>&1)
    $dumpBinExitCode = $LASTEXITCODE
    Assert-Condition `
        -Condition ($dumpBinExitCode -eq 0) `
        -Message "dumpbin /imports failed with exit code $dumpBinExitCode."
    $importsText = $dumpBinOutput | Out-String -Width 4096

    $libraryMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $importsText,
        '(?im)^\s*([A-Za-z0-9_.-]+\.dll)\s*$'
    )
    $importedLibraries = @(
        $libraryMatches |
            ForEach-Object { $_.Groups[1].Value.ToUpperInvariant() } |
            Sort-Object -Unique
    )

    $requiredLibraries = @(
        'COMCTL32.DLL',
        'DWMAPI.DLL',
        'SHELL32.DLL',
        'USER32.DLL',
        'WTSAPI32.DLL'
    )
    foreach ($library in $requiredLibraries) {
        Assert-Condition `
            -Condition ($importedLibraries -icontains $library) `
            -Message "Required public Windows library is not imported: $library"
    }

    $requiredApis = @(
        'DwmQueryThumbnailSourceSize',
        'DwmRegisterThumbnail',
        'DwmUnregisterThumbnail',
        'DwmUpdateThumbnailProperties',
        'EnumWindows',
        'GetWindowThreadProcessId',
        'InitCommonControlsEx',
        'RegisterHotKey',
        'SetWindowDisplayAffinity',
        'SetWindowPos',
        'Shell_NotifyIconW',
        'WTSRegisterSessionNotification'
    )
    foreach ($api in $requiredApis) {
        $pattern = '(?im)(?<![A-Za-z0-9_])' `
            + [System.Text.RegularExpressions.Regex]::Escape($api) `
            + '(?![A-Za-z0-9_])'
        Assert-Condition `
            -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $importsText,
                $pattern
            )) `
            -Message "Required public Windows API is not imported: $api"
    }

    $forbiddenApis = @(
        'AttachThreadInput',
        'CreateRemoteThread',
        'CreateRemoteThreadEx',
        'DebugActiveProcess',
        'keybd_event',
        'mouse_event',
        'NtCreateThreadEx',
        'NtQueueApcThread',
        'NtUnmapViewOfSection',
        'NtWriteVirtualMemory',
        'QueueUserAPC',
        'RtlCreateUserThread',
        'SendInput',
        'SetThreadContext',
        'SetWindowsHookExA',
        'SetWindowsHookExW',
        'VirtualAllocEx',
        'VirtualProtectEx',
        'WriteProcessMemory'
    )
    $forbiddenApiMatches = @()
    foreach ($api in $forbiddenApis) {
        $pattern = '(?im)(?<![A-Za-z0-9_])' `
            + [System.Text.RegularExpressions.Regex]::Escape($api) `
            + '(?![A-Za-z0-9_])'
        if ([System.Text.RegularExpressions.Regex]::IsMatch(
                $importsText,
                $pattern
            )) {
            $forbiddenApiMatches += $api
        }
    }
    Assert-Condition `
        -Condition ($forbiddenApiMatches.Count -eq 0) `
        -Message (
            'Forbidden injection or input-simulation imports found: ' `
                + ($forbiddenApiMatches -join ', ')
        )

    $dynamicRuntimeMatches = @(
        $importedLibraries | Where-Object {
            $_ -match '^(?:VCRUNTIME|MSVCP|MSVCR|CONCRT|UCRTBASE|MFC|ATL)[A-Z0-9_.-]*\.DLL$' `
                -or $_ -match '^API-MS-WIN-CRT-[A-Z0-9_.-]+\.DLL$'
        }
    )
    Assert-Condition `
        -Condition ($dynamicRuntimeMatches.Count -eq 0) `
        -Message (
            'Dynamic MSVC runtime dependencies found: ' `
                + ($dynamicRuntimeMatches -join ', ')
        )

    return [pscustomobject][ordered]@{
        tool = $DumpBinPath
        command = 'dumpbin /nologo /imports'
        scope = 'Static PE imports only; dynamic resolution remains covered by source review.'
        requiredLibraries = $requiredLibraries
        importedLibraries = $importedLibraries
        requiredApis = $requiredApis
        forbiddenApisChecked = $forbiddenApis
        forbiddenApiMatches = $forbiddenApiMatches
        dynamicRuntimeMatches = $dynamicRuntimeMatches
    }
}

function Write-JsonEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Evidence,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }

    $json = $Evidence | ConvertTo-Json -Depth 8
    $temporaryPath = Join-Path $directory ([System.IO.Path]::GetRandomFileName())
    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $json + "`n", $utf8NoBom)
        if ([System.IO.File]::Exists($Path)) {
            [System.IO.File]::Replace($temporaryPath, $Path, $null)
        }
        else {
            [System.IO.File]::Move($temporaryPath, $Path)
        }
    }
    finally {
        if ([System.IO.File]::Exists($temporaryPath)) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

$normalizedArchitecture = $ExpectedArchitecture.ToLowerInvariant()
# Output-path failures cannot safely write the requested JSON when the path is
# itself invalid or aliases an input artifact; those cases are stderr-only.
$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$candidateInputPaths = @(
    [System.IO.Path]::GetFullPath($ExecutablePath),
    [System.IO.Path]::GetFullPath($InstallerPath),
    [System.IO.Path]::GetFullPath($ManifestPath)
)
foreach ($candidateInputPath in $candidateInputPaths) {
    if ([System.String]::Equals(
            $resolvedOutputPath,
            $candidateInputPath,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        [Console]::Error.WriteLine(
            'OutputPath must not overwrite an input artifact: {0}',
            $resolvedOutputPath
        )
        exit 1
    }
}

$evidence = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = [System.DateTime]::UtcNow.ToString('o')
    completedAtUtc = $null
    success = $false
    error = $null
    expected = [ordered]@{
        architecture = $normalizedArchitecture
        version = $ExpectedVersion
    }
    artifacts = [ordered]@{
        executable = $null
        installer = $null
        manifest = $null
    }
    imports = $null
}
$embeddedManifestPath = $null

try {
    $versionParts = @($ExpectedVersion.Split('.') | ForEach-Object { [int]$_ })
    Assert-Condition `
        -Condition ($versionParts.Count -eq 4) `
        -Message 'ExpectedVersion must contain exactly four numeric components.'
    foreach ($versionPart in $versionParts) {
        Assert-Condition `
            -Condition ($versionPart -ge 0 -and $versionPart -le 65535) `
            -Message 'ExpectedVersion components must be between 0 and 65535.'
    }

    $resolvedExecutablePath = Resolve-RequiredFile `
        -Path $ExecutablePath `
        -Label 'ExecutablePath'
    $resolvedInstallerPath = Resolve-RequiredFile `
        -Path $InstallerPath `
        -Label 'InstallerPath'
    $resolvedManifestPath = Resolve-RequiredFile `
        -Path $ManifestPath `
        -Label 'ManifestPath'

    $initialExecutableSha256 = Get-Sha256 -Path $resolvedExecutablePath
    $initialInstallerSha256 = Get-Sha256 -Path $resolvedInstallerPath
    $initialManifestSha256 = Get-Sha256 -Path $resolvedManifestPath

    Assert-Condition `
        -Condition ([System.IO.Path]::GetFileName($resolvedExecutablePath) -ceq 'Fuwa.exe') `
        -Message 'Executable artifact must be named Fuwa.exe.'

    $expectedInstallerName = 'Fuwa-{0}-windows-{1}-setup.exe' -f `
        $ExpectedVersion, `
        $normalizedArchitecture
    $actualInstallerName = [System.IO.Path]::GetFileName($resolvedInstallerPath)
    Assert-Condition `
        -Condition ($actualInstallerName -ceq $expectedInstallerName) `
        -Message (
            "Installer must be named $expectedInstallerName, found: " `
                + $actualInstallerName
        )

    $executableMachine = Get-PeMachine -Path $resolvedExecutablePath
    $expectedMachine = switch ($normalizedArchitecture) {
        'x64' { 0x8664 }
        'arm64' { 0xAA64 }
        default { throw "Unsupported architecture: $normalizedArchitecture" }
    }
    $expectedMachineHex = '0x{0:X4}' -f $expectedMachine
    Assert-Condition `
        -Condition ($executableMachine.value -eq $expectedMachine) `
        -Message (
            "Fuwa.exe PE machine must be $normalizedArchitecture " `
                + "($expectedMachineHex), found: $($executableMachine.hex)"
        )

    $executableVersion = Get-FixedVersionEvidence `
        -Path $resolvedExecutablePath
    Assert-Condition `
        -Condition ($executableVersion.fileVersion -ceq $ExpectedVersion) `
        -Message (
            "Fuwa.exe file version must be $ExpectedVersion, found: " `
                + $executableVersion.fileVersion
        )
    Assert-Condition `
        -Condition ($executableVersion.productVersion -ceq $ExpectedVersion) `
        -Message (
            "Fuwa.exe product version must be $ExpectedVersion, found: " `
                + $executableVersion.productVersion
        )
    Assert-Condition `
        -Condition ($executableVersion.fileVersionString -ceq $ExpectedVersion) `
        -Message (
            "Fuwa.exe FileVersion string must be $ExpectedVersion, found: " `
                + $executableVersion.fileVersionString
        )
    Assert-Condition `
        -Condition ($executableVersion.productVersionString -ceq $ExpectedVersion) `
        -Message (
            "Fuwa.exe ProductVersion string must be $ExpectedVersion, found: " `
                + $executableVersion.productVersionString
        )
    Assert-Condition `
        -Condition ($executableVersion.originalFilename -ceq 'Fuwa.exe') `
        -Message (
            'Fuwa.exe OriginalFilename must be Fuwa.exe, found: ' `
                + $executableVersion.originalFilename
        )

    $sourceManifestPolicy = Read-ManifestPolicy -Path $resolvedManifestPath
    Assert-Condition `
        -Condition ($sourceManifestPolicy.assemblyVersion -ceq $ExpectedVersion) `
        -Message (
            "Manifest assembly version must be $ExpectedVersion, found: " `
                + $sourceManifestPolicy.assemblyVersion
        )

    $mtPath = Find-MtPath
    $manifestToken = ([System.Guid]::NewGuid()).ToString('N')
    $embeddedManifestPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        "fuwa-$manifestToken.manifest"
    Extract-EmbeddedManifest `
        -MtPath $mtPath `
        -ExecutablePath $resolvedExecutablePath `
        -DestinationPath $embeddedManifestPath
    $embeddedManifestSha256 = Get-Sha256 -Path $embeddedManifestPath
    Assert-Condition `
        -Condition ($embeddedManifestSha256 -ceq $initialManifestSha256) `
        -Message 'Embedded RT_MANIFEST #1 is not byte-identical to the source manifest.'
    $embeddedManifestPolicy = Read-ManifestPolicy -Path $embeddedManifestPath
    Assert-Condition `
        -Condition ($embeddedManifestPolicy.assemblyVersion -ceq $ExpectedVersion) `
        -Message (
            "Embedded manifest assembly version must be $ExpectedVersion, found: " `
                + $embeddedManifestPolicy.assemblyVersion
        )
    foreach ($policyField in @(
            'requestedExecutionLevel',
            'uiAccess',
            'autoElevate',
            'assemblyName',
            'assemblyVersion'
        )) {
        Assert-Condition `
            -Condition (
                $embeddedManifestPolicy.$policyField `
                    -ceq $sourceManifestPolicy.$policyField
            ) `
            -Message (
                "Embedded manifest differs from source policy field: " `
                    + $policyField
            )
    }

    $installerMachine = Get-PeMachine -Path $resolvedInstallerPath
    $dumpBinPath = Find-DumpBinPath
    $importEvidence = Inspect-ExecutableImports `
        -DumpBinPath $dumpBinPath `
        -Path $resolvedExecutablePath

    $finalExecutableSha256 = Get-Sha256 -Path $resolvedExecutablePath
    $finalInstallerSha256 = Get-Sha256 -Path $resolvedInstallerPath
    $finalManifestSha256 = Get-Sha256 -Path $resolvedManifestPath
    Assert-Condition `
        -Condition ($finalExecutableSha256 -ceq $initialExecutableSha256) `
        -Message 'Fuwa.exe changed while it was being verified.'
    Assert-Condition `
        -Condition ($finalInstallerSha256 -ceq $initialInstallerSha256) `
        -Message 'Installer changed while it was being verified.'
    Assert-Condition `
        -Condition ($finalManifestSha256 -ceq $initialManifestSha256) `
        -Message 'Source manifest changed while it was being verified.'

    $executableFile = Get-Item -LiteralPath $resolvedExecutablePath
    $installerFile = Get-Item -LiteralPath $resolvedInstallerPath
    $manifestFile = Get-Item -LiteralPath $resolvedManifestPath
    $evidence['artifacts']['executable'] = [ordered]@{
        path = $resolvedExecutablePath
        name = $executableFile.Name
        sizeBytes = $executableFile.Length
        sha256 = $finalExecutableSha256
        peMachine = $executableMachine
        version = $executableVersion
    }
    $evidence['artifacts']['installer'] = [ordered]@{
        path = $resolvedInstallerPath
        name = $installerFile.Name
        sizeBytes = $installerFile.Length
        sha256 = $finalInstallerSha256
        peMachineInformational = $installerMachine
        architectureEvidence = 'Payload Fuwa.exe PE machine; installer bootstrap architecture is informational.'
        payloadBoundary = 'Static verification does not extract or execute the Inno Setup payload.'
    }
    $evidence['artifacts']['manifest'] = [ordered]@{
        source = [ordered]@{
            path = $resolvedManifestPath
            name = $manifestFile.Name
            sizeBytes = $manifestFile.Length
            sha256 = $finalManifestSha256
            policy = $sourceManifestPolicy
        }
        embedded = [ordered]@{
            resource = 'RT_MANIFEST #1'
            sha256 = $embeddedManifestSha256
            policy = $embeddedManifestPolicy
            extractionTool = $mtPath
        }
    }
    $evidence['imports'] = $importEvidence
    $evidence['success'] = $true
}
catch {
    $evidence['error'] = $_.Exception.Message
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($embeddedManifestPath)) {
        Remove-Item `
            -LiteralPath $embeddedManifestPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
    $evidence['completedAtUtc'] = [System.DateTime]::UtcNow.ToString('o')
}

try {
    Write-JsonEvidence -Evidence $evidence -Path $resolvedOutputPath
}
catch {
    [Console]::Error.WriteLine(
        'Could not write verification evidence: {0}',
        $_.Exception.Message
    )
    exit 1
}

if (-not $evidence['success']) {
    [Console]::Error.WriteLine(
        'Fuwa Windows artifact verification failed: {0}',
        $evidence['error']
    )
    exit 1
}

Write-Host "Fuwa Windows artifact verification passed: $resolvedOutputPath"
exit 0
