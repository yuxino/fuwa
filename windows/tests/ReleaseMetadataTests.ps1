param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-TextMatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Text -cnotmatch $Pattern) {
        throw $Message
    }
}

function Get-PlistString {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$Plist,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $dictionary = $Plist.SelectSingleNode('/plist/dict')
    if ($null -eq $dictionary) {
        throw 'Info.plist does not contain a root dictionary.'
    }
    $elements = @(
        $dictionary.ChildNodes |
            Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element }
    )
    for ($index = 0; $index -lt ($elements.Count - 1); $index += 1) {
        if (
            $elements[$index].Name -ceq 'key' -and
            $elements[$index].InnerText -ceq $Key
        ) {
            return [string]$elements[$index + 1].InnerText
        }
    }
    throw "Info.plist is missing $Key."
}

$repositoryRoot = (
    Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')
).Path
$infoPlistPath = Join-Path $repositoryRoot 'Resources\Info.plist'
[xml]$infoPlist = Get-Content -LiteralPath $infoPlistPath -Raw
$marketingVersion = Get-PlistString `
    -Plist $infoPlist `
    -Key 'CFBundleShortVersionString'
$buildNumber = Get-PlistString -Plist $infoPlist -Key 'CFBundleVersion'

if ($marketingVersion -cnotmatch '^\d+\.\d+\.\d+$') {
    throw "CFBundleShortVersionString is not SemVer core: $marketingVersion"
}
if ($buildNumber -cnotmatch '^\d+$') {
    throw "CFBundleVersion is not numeric: $buildNumber"
}
$windowsVersion = "$marketingVersion.$buildNumber"
$windowsVersionCsv = $windowsVersion.Replace('.', ',')
$escapedMarketingVersion = [regex]::Escape($marketingVersion)
$escapedBuildNumber = [regex]::Escape($buildNumber)
$escapedWindowsVersion = [regex]::Escape($windowsVersion)
$escapedWindowsVersionCsv = [regex]::Escape($windowsVersionCsv)

$cmake = Get-Content `
    -LiteralPath (Join-Path $repositoryRoot 'windows\CMakeLists.txt') `
    -Raw
Assert-TextMatch $cmake `
    ('set\(FUWA_MARKETING_VERSION "{0}"\)' -f $escapedMarketingVersion) `
    'CMake marketing version differs from Info.plist.'
Assert-TextMatch $cmake `
    ('set\(FUWA_BUILD_NUMBER "{0}"\)' -f $escapedBuildNumber) `
    'CMake build number differs from Info.plist.'
Assert-TextMatch $cmake `
    'VERSION "\$\{FUWA_MARKETING_VERSION\}\.\$\{FUWA_BUILD_NUMBER\}"' `
    'CMake project version must combine the marketing version and build number.'
Assert-TextMatch $cmake `
    'set\(CPACK_PACKAGE_VERSION "\$\{FUWA_MARKETING_VERSION\}"\)' `
    'CPack package version must use the public marketing version.'
Assert-TextMatch $cmake `
    'Fuwa-\$\{FUWA_MARKETING_VERSION\}-windows-\$\{FUWA_PACKAGE_ARCHITECTURE\}-setup' `
    'CPack installer name must use the public marketing version.'

$resource = Get-Content `
    -LiteralPath (Join-Path $repositoryRoot 'windows\resources\FuwaWindows.rc') `
    -Raw
foreach ($field in @('FILEVERSION', 'PRODUCTVERSION')) {
    Assert-TextMatch $resource `
        (('(?m)^ {0} {1}$' -f $field, $escapedWindowsVersionCsv)) `
        "$field differs from Info.plist marketing/build metadata."
}
foreach ($field in @('FileVersion', 'ProductVersion')) {
    Assert-TextMatch $resource `
        (('VALUE "{0}", "{1}\\0"' -f $field, $escapedWindowsVersion)) `
        "$field string differs from Info.plist marketing/build metadata."
}

$manifest = Get-Content `
    -LiteralPath (Join-Path $repositoryRoot 'windows\resources\app.manifest') `
    -Raw
Assert-TextMatch $manifest `
    (('version="{0}"' -f $escapedWindowsVersion)) `
    'Windows assembly version differs from Info.plist marketing/build metadata.'

$verifier = Get-Content `
    -LiteralPath (Join-Path $repositoryRoot 'windows\scripts\verify-artifact.ps1') `
    -Raw
Assert-TextMatch $verifier `
    (('\$ExpectedVersion = ''{0}''' -f $escapedWindowsVersion)) `
    'Artifact verifier file-version default differs from Info.plist.'
Assert-TextMatch $verifier `
    (('\$ExpectedPackageVersion = ''{0}''' -f $escapedMarketingVersion)) `
    'Artifact verifier package-version default differs from Info.plist.'

$acceptance = Get-Content `
    -LiteralPath (Join-Path $repositoryRoot 'windows\lab\acceptance.ps1') `
    -Raw
Assert-TextMatch $acceptance `
    (('\$ExpectedVersion = ''{0}''' -f $escapedWindowsVersion)) `
    'Native acceptance file-version default differs from Info.plist.'

foreach ($sourcePath in @(
        'Sources\Fuwa\AppModel.swift',
        'Sources\Fuwa\AppDelegate.swift'
    )) {
    $source = Get-Content `
        -LiteralPath (Join-Path $repositoryRoot $sourcePath) `
        -Raw
    Assert-TextMatch $source `
        (('"{0}"' -f $escapedMarketingVersion)) `
        "$sourcePath does not contain the current fallback version."
}

$ci = Get-Content `
    -LiteralPath (Join-Path $repositoryRoot '.github\workflows\ci.yml') `
    -Raw
Assert-TextMatch $ci `
    (('-ExpectedVersion ''{0}''' -f $escapedWindowsVersion)) `
    'CI file-version expectation differs from Info.plist.'
Assert-TextMatch $ci `
    (('-ExpectedPackageVersion ''{0}''' -f $escapedMarketingVersion)) `
    'CI package-version expectation differs from Info.plist.'
Assert-TextMatch $ci `
    ('Fuwa-' + $escapedMarketingVersion + '-windows-\$\{\{ matrix\.arch \}\}') `
    'CI artifact paths differ from the public marketing version.'

$changelog = Get-Content `
    -LiteralPath (Join-Path $repositoryRoot 'CHANGELOG.md') `
    -Raw
Assert-TextMatch $changelog `
    (('(?m)^## \[{0}\] - \d{{4}}-\d{{2}}-\d{{2}}$' -f $escapedMarketingVersion)) `
    'CHANGELOG does not contain the current release heading.'
Assert-TextMatch $changelog `
    (('\[Unreleased\]: https://github\.com/yuxino/fuwa/compare/v{0}\.\.\.HEAD' -f $escapedMarketingVersion)) `
    'CHANGELOG Unreleased comparison does not start at the current version.'

Write-Host (
    'Fuwa release metadata tests passed: public {0}, build {1}, Windows {2}.' `
        -f $marketingVersion, $buildNumber, $windowsVersion
)
