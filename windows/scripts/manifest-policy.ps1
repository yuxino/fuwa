function Read-FuwaManifestDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.IgnoreComments = $true
    $settings.IgnoreProcessingInstructions = $true
    $settings.MaxCharactersInDocument = 1MB
    $settings.MaxCharactersFromEntities = 1024

    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $false
    $document.XmlResolver = $null
    try {
        $document.Load($reader)
    }
    finally {
        $reader.Dispose()
    }

    if ($null -eq $document.DocumentElement) {
        throw 'Manifest does not contain a document element.'
    }
    Write-Output -NoEnumerate $document
}

function Get-FuwaRequiredManifestNode {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Document,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNamespaceManager]$Namespaces,

        [Parameter(Mandatory = $true)]
        [string]$XPath,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $nodes = @($Document.SelectNodes($XPath, $Namespaces))
    if ($nodes.Count -ne 1) {
        throw "Manifest must contain exactly one $Label at its required namespace and path."
    }
    Write-Output -NoEnumerate $nodes[0]
}

function Assert-FuwaUniqueManifestLocalName {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Document,

        [Parameter(Mandatory = $true)]
        [string]$LocalName,

        [Parameter(Mandatory = $true)]
        [int]$ExpectedCount
    )

    $nodes = @($Document.SelectNodes(
        "//*[local-name()='$LocalName']"
    ))
    if ($nodes.Count -ne $ExpectedCount) {
        throw "Manifest must contain exactly $ExpectedCount $LocalName element(s)."
    }
}

function Read-FuwaManifestPolicy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $document = Read-FuwaManifestDocument -Path $Path
    $root = $document.DocumentElement
    if (
        $root.LocalName -cne 'assembly' -or
        $root.NamespaceURI -cne 'urn:schemas-microsoft-com:asm.v1'
    ) {
        throw 'Manifest root must be the asm.v1 assembly element.'
    }

    $namespaces = New-Object System.Xml.XmlNamespaceManager `
        -ArgumentList (, $document.NameTable)
    $namespaces.AddNamespace(
        'asmv1',
        'urn:schemas-microsoft-com:asm.v1'
    )
    $namespaces.AddNamespace(
        'asmv3',
        'urn:schemas-microsoft-com:asm.v3'
    )
    $namespaces.AddNamespace(
        'compat',
        'urn:schemas-microsoft-com:compatibility.v1'
    )
    $namespaces.AddNamespace(
        'ws2005',
        'http://schemas.microsoft.com/SMI/2005/WindowsSettings'
    )
    $namespaces.AddNamespace(
        'ws2016',
        'http://schemas.microsoft.com/SMI/2016/WindowsSettings'
    )

    Assert-FuwaUniqueManifestLocalName `
        -Document $document `
        -LocalName 'assemblyIdentity' `
        -ExpectedCount 2
    Assert-FuwaUniqueManifestLocalName `
        -Document $document `
        -LocalName 'requestedExecutionLevel' `
        -ExpectedCount 1
    Assert-FuwaUniqueManifestLocalName `
        -Document $document `
        -LocalName 'supportedOS' `
        -ExpectedCount 1
    foreach ($settingName in @(
            'dpiAwareness',
            'dpiAware',
            'longPathAware'
        )) {
        Assert-FuwaUniqueManifestLocalName `
            -Document $document `
            -LocalName $settingName `
            -ExpectedCount 1
    }
    $autoElevateNodes = @($document.SelectNodes(
        "//*[local-name()='autoElevate']"
    ))
    if ($autoElevateNodes.Count -ne 0) {
        throw 'Manifest must not contain an autoElevate element.'
    }

    $identity = Get-FuwaRequiredManifestNode `
        -Document $document `
        -Namespaces $namespaces `
        -XPath '/asmv1:assembly/asmv1:assemblyIdentity' `
        -Label 'root assemblyIdentity'
    $execution = Get-FuwaRequiredManifestNode `
        -Document $document `
        -Namespaces $namespaces `
        -XPath '/asmv1:assembly/asmv3:trustInfo/asmv3:security/asmv3:requestedPrivileges/asmv3:requestedExecutionLevel' `
        -Label 'asm.v3 requestedExecutionLevel'
    $supportedOS = Get-FuwaRequiredManifestNode `
        -Document $document `
        -Namespaces $namespaces `
        -XPath '/asmv1:assembly/compat:compatibility/compat:application/compat:supportedOS' `
        -Label 'Windows compatibility supportedOS'
    $dpiAwareness = Get-FuwaRequiredManifestNode `
        -Document $document `
        -Namespaces $namespaces `
        -XPath '/asmv1:assembly/asmv3:application/asmv3:windowsSettings/ws2016:dpiAwareness' `
        -Label '2016 dpiAwareness'
    $dpiAware = Get-FuwaRequiredManifestNode `
        -Document $document `
        -Namespaces $namespaces `
        -XPath '/asmv1:assembly/asmv3:application/asmv3:windowsSettings/ws2005:dpiAware' `
        -Label '2005 dpiAware'
    $longPathAware = Get-FuwaRequiredManifestNode `
        -Document $document `
        -Namespaces $namespaces `
        -XPath '/asmv1:assembly/asmv3:application/asmv3:windowsSettings/ws2016:longPathAware' `
        -Label '2016 longPathAware'
    $commonControls = Get-FuwaRequiredManifestNode `
        -Document $document `
        -Namespaces $namespaces `
        -XPath '/asmv1:assembly/asmv1:dependency/asmv1:dependentAssembly/asmv1:assemblyIdentity' `
        -Label 'Common-Controls assemblyIdentity'

    return [pscustomobject][ordered]@{
        rootNamespace = $root.NamespaceURI
        manifestVersion = $root.GetAttribute('manifestVersion')
        assemblyName = $identity.GetAttribute('name')
        assemblyType = $identity.GetAttribute('type')
        assemblyVersion = $identity.GetAttribute('version')
        processorArchitecture = $identity.GetAttribute('processorArchitecture')
        assemblyPublicKeyToken = $identity.GetAttribute('publicKeyToken')
        assemblyLanguage = $identity.GetAttribute('language')
        requestedExecutionLevelNamespace = $execution.NamespaceURI
        requestedExecutionLevel = $execution.GetAttribute('level')
        uiAccess = $execution.GetAttribute('uiAccess')
        autoElevate = $false
        supportedOS = $supportedOS.GetAttribute('Id')
        dpiAwareness = $dpiAwareness.InnerText.Trim()
        dpiAware = $dpiAware.InnerText.Trim()
        longPathAware = $longPathAware.InnerText.Trim()
        commonControlsName = $commonControls.GetAttribute('name')
        commonControlsType = $commonControls.GetAttribute('type')
        commonControlsVersion = $commonControls.GetAttribute('version')
        commonControlsPublicKeyToken = $commonControls.GetAttribute('publicKeyToken')
        commonControlsLanguage = $commonControls.GetAttribute('language')
        commonControlsProcessorArchitecture = $commonControls.GetAttribute('processorArchitecture')
    }
}

function Get-FuwaNormalizedProcessorArchitecture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeclaredArchitecture,

        [Parameter(Mandatory = $true)]
        [ValidateSet('x64', 'arm64')]
        [string]$ExpectedArchitecture,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $declared = $DeclaredArchitecture.ToLowerInvariant()
    $normalized = switch ($ExpectedArchitecture.ToLowerInvariant()) {
        'x64' {
            if ($declared -notin @('*', 'amd64')) {
                throw "$Label processorArchitecture must be * or amd64 for x64, found: $DeclaredArchitecture"
            }
            'amd64'
        }
        'arm64' {
            if ($declared -notin @('*', 'arm64')) {
                throw "$Label processorArchitecture must be * or arm64 for ARM64, found: $DeclaredArchitecture"
            }
            'arm64'
        }
    }
    return $normalized
}

function Assert-FuwaManifestPolicyContract {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Policy,

        [Parameter(Mandatory = $true)]
        [ValidateSet('x64', 'arm64')]
        [string]$ExpectedArchitecture,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedVersion,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $expectedValues = [ordered]@{
        rootNamespace = 'urn:schemas-microsoft-com:asm.v1'
        manifestVersion = '1.0'
        assemblyName = 'app.yuxino.fuwa.windows'
        assemblyType = 'win32'
        assemblyVersion = $ExpectedVersion
        assemblyPublicKeyToken = ''
        assemblyLanguage = ''
        requestedExecutionLevelNamespace = 'urn:schemas-microsoft-com:asm.v3'
        requestedExecutionLevel = 'asInvoker'
        uiAccess = 'false'
        dpiAwareness = 'PerMonitorV2,PerMonitor'
        dpiAware = 'true/pm'
        longPathAware = 'true'
        commonControlsName = 'Microsoft.Windows.Common-Controls'
        commonControlsType = 'win32'
        commonControlsVersion = '6.0.0.0'
        commonControlsLanguage = '*'
    }
    foreach ($field in $expectedValues.Keys) {
        if (-not [System.String]::Equals(
                [string]$Policy.$field,
                [string]$expectedValues[$field],
                [System.StringComparison]::Ordinal
            )) {
            throw "$Label manifest field $field must be $($expectedValues[$field]), found: $($Policy.$field)"
        }
    }
    if ($Policy.autoElevate -ne $false) {
        throw "$Label manifest must not enable autoElevate."
    }
    if (-not [System.String]::Equals(
            [string]$Policy.supportedOS,
            '{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "$Label manifest has an unexpected supportedOS GUID: $($Policy.supportedOS)"
    }
    if (-not [System.String]::Equals(
            [string]$Policy.commonControlsPublicKeyToken,
            '6595b64144ccf1df',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "$Label manifest has an unexpected Common-Controls publicKeyToken."
    }

    $null = Get-FuwaNormalizedProcessorArchitecture `
        -DeclaredArchitecture $Policy.processorArchitecture `
        -ExpectedArchitecture $ExpectedArchitecture `
        -Label "$Label root identity"
    $null = Get-FuwaNormalizedProcessorArchitecture `
        -DeclaredArchitecture $Policy.commonControlsProcessorArchitecture `
        -ExpectedArchitecture $ExpectedArchitecture `
        -Label "$Label Common-Controls identity"
}

function Get-FuwaManifestBehaviorContract {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Policy,

        [Parameter(Mandatory = $true)]
        [ValidateSet('x64', 'arm64')]
        [string]$ExpectedArchitecture
    )

    $rootArchitecture = Get-FuwaNormalizedProcessorArchitecture `
        -DeclaredArchitecture $Policy.processorArchitecture `
        -ExpectedArchitecture $ExpectedArchitecture `
        -Label 'root identity'
    $commonControlsArchitecture = Get-FuwaNormalizedProcessorArchitecture `
        -DeclaredArchitecture $Policy.commonControlsProcessorArchitecture `
        -ExpectedArchitecture $ExpectedArchitecture `
        -Label 'Common-Controls identity'
    return @(
        $Policy.rootNamespace,
        $Policy.manifestVersion,
        $Policy.assemblyName,
        $Policy.assemblyType,
        $Policy.assemblyVersion,
        $rootArchitecture,
        $Policy.assemblyPublicKeyToken,
        $Policy.assemblyLanguage,
        $Policy.requestedExecutionLevelNamespace,
        $Policy.requestedExecutionLevel,
        $Policy.uiAccess,
        [string]$Policy.autoElevate,
        $Policy.supportedOS.ToLowerInvariant(),
        $Policy.dpiAwareness,
        $Policy.dpiAware,
        $Policy.longPathAware,
        $Policy.commonControlsName,
        $Policy.commonControlsType,
        $Policy.commonControlsVersion,
        $Policy.commonControlsPublicKeyToken.ToLowerInvariant(),
        $Policy.commonControlsLanguage,
        $commonControlsArchitecture
    ) -join [char]0
}

function Assert-FuwaManifestPoliciesEquivalent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$SourcePolicy,

        [Parameter(Mandatory = $true)]
        [object]$EmbeddedPolicy,

        [Parameter(Mandatory = $true)]
        [ValidateSet('x64', 'arm64')]
        [string]$ExpectedArchitecture,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedVersion
    )

    Assert-FuwaManifestPolicyContract `
        -Policy $SourcePolicy `
        -ExpectedArchitecture $ExpectedArchitecture `
        -ExpectedVersion $ExpectedVersion `
        -Label 'Source'
    Assert-FuwaManifestPolicyContract `
        -Policy $EmbeddedPolicy `
        -ExpectedArchitecture $ExpectedArchitecture `
        -ExpectedVersion $ExpectedVersion `
        -Label 'Embedded'

    $sourceContract = Get-FuwaManifestBehaviorContract `
        -Policy $SourcePolicy `
        -ExpectedArchitecture $ExpectedArchitecture
    $embeddedContract = Get-FuwaManifestBehaviorContract `
        -Policy $EmbeddedPolicy `
        -ExpectedArchitecture $ExpectedArchitecture
    if (-not [System.String]::Equals(
            $sourceContract,
            $embeddedContract,
            [System.StringComparison]::Ordinal
        )) {
        throw 'Embedded manifest behavior contract differs from the source manifest.'
    }
}
