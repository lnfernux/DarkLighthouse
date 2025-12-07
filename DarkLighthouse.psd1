@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'DarkLighthouse.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author of this module
    Author = 'Truls TD'
    
    # Company or vendor of this module
    CompanyName = 'infernux.no'
    
    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PowerShell module to discover cross-tenant access via Azure Lighthouse'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Modules that must be imported into the global environment prior to importing this module
    # Note: Microsoft.Graph is optional and only required when using -B2B flag
    RequiredModules = @(
        @{ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'Az.Resources'; ModuleVersion = '6.0.0'}
    )
    
    # Functions to export from this module
    FunctionsToExport = @('Invoke-DarkLighthouse', 'New-LighthouseTemplate')
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Azure', 'Lighthouse', 'CrossTenant', 'Identity', 'Security', 'AzureAD', 'RBAC')
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/lnfernux/DarkLighthousePrivate/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/lnfernux/DarkLighthousePrivate'
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
Version 1.0.0
- Azure Lighthouse delegation discovery across all accessible subscriptions
- Interactive wizard mode for guided workflows
- Template generation for creating new Lighthouse delegations
- Support for both subscription and resource group scopes
- User and service principal authentication
- Comprehensive help documentation and examples
'@
        }
    }
}
