[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\scripts\manifest-policy.ps1')

function Write-TestManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [System.Text.Encoding]$Encoding
    )

    [System.IO.File]::WriteAllText($Path, $Content, $Encoding)
}

function Assert-PolicyRejected {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestRoot,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter()]
        [ValidateSet('x64', 'arm64')]
        [string]$Architecture = 'x64'
    )

    $path = Join-Path $TestRoot ($Name + '.manifest')
    $utf16LeBom = New-Object System.Text.UnicodeEncoding `
        -ArgumentList $false, $true
    Write-TestManifest -Path $path -Content $Content -Encoding $utf16LeBom
    $wasRejected = $false
    try {
        $policy = Read-FuwaManifestPolicy -Path $path
        Assert-FuwaManifestPolicyContract `
            -Policy $policy `
            -ExpectedArchitecture $Architecture `
            -ExpectedVersion '0.1.1.2' `
            -Label $Name
    }
    catch {
        $wasRejected = $true
    }
    if (-not $wasRejected) {
        throw "Manifest policy regression was not rejected: $Name"
    }
}

$testRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('fuwa-manifest-policy-' + ([System.Guid]::NewGuid()).ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null

try {
    $sourceXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity name="app.yuxino.fuwa.windows" processorArchitecture="*" type="win32" version="0.1.1.2" />
  <description>Fuwa window mirror</description>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false" /></requestedPrivileges></security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application><supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}" /></application>
  </compatibility>
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2,PerMonitor</dpiAwareness>
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true/pm</dpiAware>
      <longPathAware xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">true</longPathAware>
    </windowsSettings>
  </application>
  <dependency><dependentAssembly>
    <assemblyIdentity name="Microsoft.Windows.Common-Controls" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*" type="win32" version="6.0.0.0" />
  </dependentAssembly></dependency>
</assembly>
'@

    $embeddedXml = @'
<?xml version="1.0" encoding="utf-16"?>
<v1:assembly manifestVersion="1.0"
 xmlns:w16="http://schemas.microsoft.com/SMI/2016/WindowsSettings"
 xmlns:compat="urn:schemas-microsoft-com:compatibility.v1"
 xmlns:v3="urn:schemas-microsoft-com:asm.v3"
 xmlns:w05="http://schemas.microsoft.com/SMI/2005/WindowsSettings"
 xmlns:v1="urn:schemas-microsoft-com:asm.v1">
  <!-- mt.exe may change formatting, namespace prefixes and architecture. -->
  <v1:assemblyIdentity version="0.1.1.2" type="win32" processorArchitecture="amd64" name="app.yuxino.fuwa.windows"/>
  <v1:description>Non-policy metadata may be normalized.</v1:description>
  <v3:trustInfo><v3:security><v3:requestedPrivileges>
    <v3:requestedExecutionLevel uiAccess="false" level="asInvoker" />
  </v3:requestedPrivileges></v3:security></v3:trustInfo>
  <compat:compatibility><compat:application>
    <compat:supportedOS Id="{8E0F7A12-BFB3-4FE8-B9A5-48FD50A15A9A}"/>
  </compat:application></compat:compatibility>
  <v3:application><v3:windowsSettings>
    <w16:dpiAwareness>PerMonitorV2,PerMonitor</w16:dpiAwareness>
    <w05:dpiAware>true/pm</w05:dpiAware>
    <w16:longPathAware>true</w16:longPathAware>
  </v3:windowsSettings></v3:application>
  <v1:dependency><v1:dependentAssembly>
    <v1:assemblyIdentity version="6.0.0.0" type="win32" language="*" publicKeyToken="6595B64144CCF1DF" processorArchitecture="amd64" name="Microsoft.Windows.Common-Controls" />
  </v1:dependentAssembly></v1:dependency>
</v1:assembly>
'@

    $sourcePath = Join-Path $testRoot 'source.manifest'
    $embeddedPath = Join-Path $testRoot 'embedded.manifest'
    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $utf16LeBom = New-Object System.Text.UnicodeEncoding -ArgumentList $false, $true
    Write-TestManifest `
        -Path $sourcePath `
        -Content $sourceXml `
        -Encoding $utf8NoBom
    Write-TestManifest `
        -Path $embeddedPath `
        -Content ($embeddedXml -replace "`n", "`r`n") `
        -Encoding $utf16LeBom

    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $embeddedHash = (Get-FileHash -LiteralPath $embeddedPath -Algorithm SHA256).Hash
    if ($sourceHash -ceq $embeddedHash) {
        throw 'Regression fixtures must differ at the byte level.'
    }

    $sourcePolicy = Read-FuwaManifestPolicy -Path $sourcePath
    $embeddedPolicy = Read-FuwaManifestPolicy -Path $embeddedPath
    Assert-FuwaManifestPoliciesEquivalent `
        -SourcePolicy $sourcePolicy `
        -EmbeddedPolicy $embeddedPolicy `
        -ExpectedArchitecture 'x64' `
        -ExpectedVersion '0.1.1.2'

    $arm64Xml = $embeddedXml.Replace(
        'processorArchitecture="amd64"',
        'processorArchitecture="arm64"'
    )
    $arm64Path = Join-Path $testRoot 'embedded-arm64.manifest'
    Write-TestManifest `
        -Path $arm64Path `
        -Content $arm64Xml `
        -Encoding $utf16LeBom
    $arm64Policy = Read-FuwaManifestPolicy -Path $arm64Path
    Assert-FuwaManifestPoliciesEquivalent `
        -SourcePolicy $sourcePolicy `
        -EmbeddedPolicy $arm64Policy `
        -ExpectedArchitecture 'arm64' `
        -ExpectedVersion '0.1.1.2'

    $rootIdentityXml = '<v1:assemblyIdentity version="0.1.1.2" type="win32" processorArchitecture="amd64" name="app.yuxino.fuwa.windows"/>'
    $commonControlsIdentityXml = '<v1:assemblyIdentity version="6.0.0.0" type="win32" language="*" publicKeyToken="6595B64144CCF1DF" processorArchitecture="amd64" name="Microsoft.Windows.Common-Controls" />'
    $arm64RootIdentityXml = $rootIdentityXml.Replace(
        'processorArchitecture="amd64"',
        'processorArchitecture="arm64"'
    )
    $arm64CommonControlsIdentityXml = $commonControlsIdentityXml.Replace(
        'processorArchitecture="amd64"',
        'processorArchitecture="arm64"'
    )
    $mutations = [ordered]@{
        'root-namespace' = $embeddedXml.Replace('xmlns:v1="urn:schemas-microsoft-com:asm.v1"', 'xmlns:v1="urn:schemas-microsoft-com:asm.invalid"')
        'manifest-version' = $embeddedXml.Replace('manifestVersion="1.0"', 'manifestVersion="2.0"')
        'assembly-name' = $embeddedXml.Replace('name="app.yuxino.fuwa.windows"', 'name="app.example.other"')
        'assembly-type' = $embeddedXml.Replace($rootIdentityXml, $rootIdentityXml.Replace('type="win32"', 'type="win64"'))
        'assembly-version' = $embeddedXml.Replace('version="0.1.1.2"', 'version="9.9.9.9"')
        'assembly-public-key-token' = $embeddedXml.Replace($rootIdentityXml, $rootIdentityXml.Replace('/>', ' publicKeyToken="0000000000000000"/>'))
        'assembly-language' = $embeddedXml.Replace($rootIdentityXml, $rootIdentityXml.Replace('/>', ' language="en-US"/>'))
        'assembly-architecture' = $embeddedXml.Replace($rootIdentityXml, $arm64RootIdentityXml)
        'assembly-architecture-whitespace' = $embeddedXml.Replace($rootIdentityXml, $rootIdentityXml.Replace('processorArchitecture="amd64"', 'processorArchitecture=" amd64 "'))
        'execution-namespace' = $embeddedXml.Replace('xmlns:v3="urn:schemas-microsoft-com:asm.v3"', 'xmlns:v3="urn:schemas-microsoft-com:asm.invalid"')
        'execution-level' = $embeddedXml.Replace('level="asInvoker"', 'level="requireAdministrator"')
        'ui-access' = $embeddedXml.Replace('uiAccess="false"', 'uiAccess="true"')
        'duplicate-execution-level' = $embeddedXml.Replace(
            '<v3:requestedExecutionLevel uiAccess="false" level="asInvoker" />',
            '<v3:requestedExecutionLevel uiAccess="false" level="asInvoker" /><v3:requestedExecutionLevel uiAccess="false" level="asInvoker" />'
        )
        'supported-os' = $embeddedXml.Replace('{8E0F7A12-BFB3-4FE8-B9A5-48FD50A15A9A}', '{00000000-0000-0000-0000-000000000000}')
        'dpi-awareness' = $embeddedXml.Replace('PerMonitorV2,PerMonitor', 'System')
        'dpi-aware' = $embeddedXml.Replace('>true/pm<', '>false<')
        'long-path-aware' = $embeddedXml.Replace('<w16:longPathAware>true</w16:longPathAware>', '<w16:longPathAware>false</w16:longPathAware>')
        'common-controls-name' = $embeddedXml.Replace('name="Microsoft.Windows.Common-Controls"', 'name="Unexpected.Controls"')
        'common-controls-type' = $embeddedXml.Replace($commonControlsIdentityXml, $commonControlsIdentityXml.Replace('type="win32"', 'type="win64"'))
        'common-controls-version' = $embeddedXml.Replace('version="6.0.0.0"', 'version="5.0.0.0"')
        'common-controls-token' = $embeddedXml.Replace('publicKeyToken="6595B64144CCF1DF"', 'publicKeyToken="0000000000000000"')
        'common-controls-language' = $embeddedXml.Replace('language="*"', 'language="en-US"')
        'common-controls-architecture' = $embeddedXml.Replace($commonControlsIdentityXml, $arm64CommonControlsIdentityXml)
        'auto-elevate' = $embeddedXml.Replace(
            '<v3:requestedExecutionLevel uiAccess="false" level="asInvoker" />',
            '<v3:requestedExecutionLevel uiAccess="false" level="asInvoker" /><v3:autoElevate>true</v3:autoElevate>'
        )
    }
    foreach ($mutation in $mutations.GetEnumerator()) {
        if ($mutation.Value -ceq $embeddedXml) {
            throw "Regression mutation did not change its fixture: $($mutation.Key)"
        }
        Assert-PolicyRejected `
            -TestRoot $testRoot `
            -Name $mutation.Key `
            -Content $mutation.Value
    }

    Assert-PolicyRejected `
        -TestRoot $testRoot `
        -Name 'arm64-root-with-amd64-architecture' `
        -Content ($arm64Xml.Replace(
            $arm64RootIdentityXml,
            $rootIdentityXml
        )) `
        -Architecture 'arm64'
    Assert-PolicyRejected `
        -TestRoot $testRoot `
        -Name 'arm64-common-controls-with-amd64-architecture' `
        -Content ($arm64Xml.Replace(
            $arm64CommonControlsIdentityXml,
            $commonControlsIdentityXml
        )) `
        -Architecture 'arm64'

    $dtdXml = $embeddedXml.Replace(
        '?>',
        '?>' + "`n" + '<!DOCTYPE assembly [<!ENTITY probe SYSTEM "file:///C:/Windows/win.ini">]>'
    )
    Assert-PolicyRejected `
        -TestRoot $testRoot `
        -Name 'dtd-and-external-entity' `
        -Content $dtdXml

    Write-Host 'All Fuwa manifest policy tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
