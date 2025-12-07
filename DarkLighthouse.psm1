#Requires -Version 5.1
#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    PowerShell module for discovering cross-tenant access via Azure Lighthouse

.DESCRIPTION
    This module provides a command to check the current user's or service principal's
    access into other tenants via Azure Lighthouse delegated resource management
    (using Get-AzManagedServicesAssignment).
#>

# Module-scoped variables
$script:CrossTenantAccessContext = $null

# Common Azure RBAC Role mappings
$script:AzureRoleMap = @{
    'Reader' = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    'Contributor' = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    'Owner' = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
    'UserAccessAdministrator' = '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
    'VirtualMachineContributor' = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
    'StorageBlobDataContributor' = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    'StorageBlobDataReader' = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    'KeyVaultSecretsUser' = '4633458b-17de-408a-b874-0445c86b69e6'
    'MonitoringContributor' = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
    'LogAnalyticsContributor' = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    'SecurityAdmin' = 'fb1c8493-542b-48eb-b624-b4c8fea62acd'
    'NetworkContributor' = '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

#region Private Functions

<#
.SYNOPSIS
    Displays ASCII art lighthouse banner
#>
Function Show-LighthouseBanner {
    [CmdletBinding()]
    Param()
    
    $banner = @"

▓█████▄  ▄▄▄       ██▀███   ██ ▄█▀    ██▓     ██▓  ▄████  ██░ ██ ▄▄▄█████▓ ██░ ██  ▒█████   █    ██   ██████ ▓█████ 
▒██▀ ██▌▒████▄    ▓██ ▒ ██▒ ██▄█▒    ▓██▒    ▓██▒ ██▒ ▀█▒▓██░ ██▒▓  ██▒ ▓▒▓██░ ██▒▒██▒  ██▒ ██  ▓██▒▒██    ▒ ▓█   ▀ 
░██   █▌▒██  ▀█▄  ▓██ ░▄█ ▒▓███▄░    ▒██░    ▒██▒▒██░▄▄▄░▒██▀▀██░▒ ▓██░ ▒░▒██▀▀██░▒██░  ██▒▓██  ▒██░░ ▓██▄   ▒███   
░▓█▄   ▌░██▄▄▄▄██ ▒██▀▀█▄  ▓██ █▄    ▒██░    ░██░░▓█  ██▓░▓█ ░██ ░ ▓██▓ ░ ░▓█ ░██ ▒██   ██░▓▓█  ░██░  ▒   ██▒▒▓█  ▄ 
░▒████▓  ▓█   ▓██▒░██▓ ▒██▒▒██▒ █▄   ░██████▒░██░░▒▓███▀▒░▓█▒░██▓  ▒██▒ ░ ░▓█▒░██▓░ ████▓▒░▒▒█████▓ ▒██████▒▒░▒████▒
 ▒▒▓  ▒  ▒▒   ▓▒█░░ ▒▓ ░▒▓░▒ ▒▒ ▓▒   ░ ▒░▓  ░░▓   ░▒   ▒  ▒ ░░▒░▒  ▒ ░░    ▒ ░░▒░▒░ ▒░▒░▒░ ░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░░░ ▒░ ░
 ░ ▒  ▒   ▒   ▒▒ ░  ░▒ ░ ▒░░ ░▒ ▒░   ░ ░ ▒  ░ ▒ ░  ░   ░  ▒ ░▒░ ░    ░     ▒ ░▒░ ░  ░ ▒ ▒░ ░░▒░ ░ ░ ░ ░▒  ░ ░ ░ ░  ░
 ░ ░  ░   ░   ▒     ░░   ░ ░ ░░ ░      ░ ░    ▒ ░░ ░   ░  ░  ░░ ░  ░       ░  ░░ ░░ ░ ░ ▒   ░░░ ░ ░ ░  ░  ░     ░   
   ░          ░  ░   ░     ░  ░          ░  ░ ░        ░  ░  ░  ░          ░  ░  ░    ░ ░     ░           ░     ░  ░
 ░                                                                                                                  

🛡️ [Dark Lighthouse - version 1.0.0]
PowerShell module to discover cross-tenant access via Azure Lighthouse - 2025
"@
    
    Write-Host $banner -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Interactive wizard mode for DarkLighthouse
#>
Function Start-DarkLighthouseWizard {
    [CmdletBinding()]
    Param()
    
    Show-LighthouseBanner
    
    Write-Host "Welcome to the Dark Lighthouse Wizard!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "What would you like to do?" -ForegroundColor Cyan
    Write-Host "  1. Check Azure Lighthouse delegations" -ForegroundColor White
    Write-Host "  2. Create Lighthouse delegation template" -ForegroundColor White
    Write-Host "  3. Exit" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-3)"
    
    switch ($choice) {
        '1' {
            Write-Host "`nStarting Lighthouse discovery..." -ForegroundColor Green
            $tenantId = Read-Host "Enter your Tenant ID"
            
            Write-Host "`nAuthentication method:" -ForegroundColor Cyan
            Write-Host "  1. Interactive login (user)" -ForegroundColor White
            Write-Host "  2. Service Principal (client ID + secret)" -ForegroundColor White
            $authChoice = Read-Host "Enter authentication method (1 or 2)"
            
            if ($authChoice -eq '2') {
                $appId = Read-Host "Enter Application (Client) ID"
                $secretPlain = Read-Host "Enter Client Secret" -AsSecureString
                Invoke-DarkLighthouse -TenantId $tenantId -ApplicationId $appId -ClientSecret $secretPlain -HideBanner
            } else {
                Invoke-DarkLighthouse -TenantId $tenantId -HideBanner
            }
        }
        '2' {
            Write-Host "`nStarting Lighthouse template creation wizard..." -ForegroundColor Green
            Write-Host ""
            
            # Collect required parameters
            $principalId = Read-Host "Enter Principal ID (Object ID of user, group, or service principal)"
            
            Write-Host "`nScope options:" -ForegroundColor Cyan
            Write-Host "  1. Subscription" -ForegroundColor White
            Write-Host "  2. Resource Group" -ForegroundColor White
            $scopeChoice = Read-Host "Enter scope (1 or 2)"
            $scope = if ($scopeChoice -eq '2') { 'ResourceGroup' } else { 'Subscription' }
            
            $resourceGroupName = $null
            if ($scope -eq 'ResourceGroup') {
                $resourceGroupName = Read-Host "Enter Resource Group Name"
            }
            
            Write-Host "`nCommon roles:" -ForegroundColor Cyan
            Write-Host "  1. Reader" -ForegroundColor White
            Write-Host "  2. Contributor" -ForegroundColor White
            Write-Host "  3. Owner" -ForegroundColor White
            Write-Host "  4. Custom (enter role name or GUID)" -ForegroundColor White
            $roleChoice = Read-Host "Enter role choice (1-4)"
            $role = switch ($roleChoice) {
                '1' { 'Reader' }
                '2' { 'Contributor' }
                '3' { 'Owner' }
                '4' { Read-Host "Enter role name or GUID" }
                default { 'Reader' }
            }
            
            $managingTenantId = Read-Host "Enter Managing Tenant ID (your MSP tenant)"
            $targetTenantId = Read-Host "Enter Target Tenant ID (customer tenant)"
            $subscriptionId = Read-Host "Enter Target Subscription ID"
            $offerName = Read-Host "Enter Offer Name (e.g., 'Contoso Managed Services')"
            $offerDescription = Read-Host "Enter Offer Description (optional, press Enter to skip)"
            $principalDisplayName = Read-Host "Enter Principal Display Name (optional, press Enter to skip)"
            
            Write-Host "`nDeploy now? (requires Owner role in target tenant)" -ForegroundColor Yellow
            $deployChoice = Read-Host "Deploy immediately? (Y/N)"
            $deploy = $deployChoice -match '^[Yy]'
            
            # Build parameters
            $params = @{
                AddPersistence = $true
                PrincipalId = $principalId
                Scope = $scope
                Role = $role
                ManagingTenantId = $managingTenantId
                TargetTenantId = $targetTenantId
                SubscriptionId = $subscriptionId
                OfferName = $offerName
            }
            
            if ($resourceGroupName) { $params['ResourceGroupName'] = $resourceGroupName }
            if (![string]::IsNullOrWhiteSpace($offerDescription)) { $params['OfferDescription'] = $offerDescription }
            if (![string]::IsNullOrWhiteSpace($principalDisplayName)) { $params['PrincipalDisplayName'] = $principalDisplayName }
            if ($deploy) { $params['Deploy'] = $true }
            
            Invoke-DarkLighthouse @params
        }
        '3' {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            return
        }
        default {
            Write-Host "`nInvalid choice. Exiting..." -ForegroundColor Red
            return
        }
    }
}

<#
.SYNOPSIS
    Connects to Azure with the specified authentication method
#>
Function Connect-Services {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$AuthType,
        
        [string]$TenantId,
        [string]$Username,
        [string]$ApplicationId,
        [SecureString]$ClientSecret
    )
    
    try {
        Write-Verbose "Authenticating using $AuthType method..."
        
        $azureConnected = $false
        
        switch ($AuthType) {
            'Interactive' {
                # Connect to Azure
                try {
                    # Check if already connected to Azure
                    $existingAzContext = Get-AzContext -ErrorAction SilentlyContinue
                    if ($existingAzContext -and $existingAzContext.Tenant.Id -eq $TenantId) {
                        Write-Verbose "Already connected to Azure for tenant $TenantId"
                        $azureConnected = $true
                    } else {
                        $azParams = @{
                            TenantId = $TenantId
                            WarningAction = 'SilentlyContinue'
                        }
                        if ($Username) {
                            $azParams['AccountId'] = $Username
                        }
                        
                        # Suppress all output including subscription selection prompts
                        $env:AZURE_CORE_COLLECT_TELEMETRY = 'False'
                        $env:AZURE_CORE_NO_COLOR = 'True'
                        
                        $null = Connect-AzAccount @azParams -ErrorAction Stop 2>&1 | Out-Null
                        
                        # After connection, set context to first available subscription silently
                        $subs = Get-AzSubscription -TenantId $TenantId -ErrorAction SilentlyContinue
                        if ($subs -and @($subs).Count -gt 0) {
                            $null = Set-AzContext -Subscription @($subs)[0].Id -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                        }
                        
                        $azureConnected = $true
                        Write-Verbose "Azure connection successful"
                    }
                } catch {
                    Write-Warning "Failed to connect to Azure: $_"
                }
            }
            'ServicePrincipal' {
                # Convert SecureString to credential
                $spCredential = New-Object PSCredential($ApplicationId, $ClientSecret)
            
                # Connect to Azure
                try {
                    $existingAzContext = Get-AzContext -ErrorAction SilentlyContinue
                    if ($existingAzContext -and $existingAzContext.Tenant.Id -eq $TenantId) {
                        Write-Verbose "Already connected to Azure for tenant $TenantId"
                        $azureConnected = $true
                    } else {
                        $null = Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $spCredential -ErrorAction Stop -WarningAction SilentlyContinue 2>&1 | Out-Null
                        
                        # Set context to first subscription
                        $subs = Get-AzSubscription -TenantId $TenantId -ErrorAction SilentlyContinue
                        if ($subs -and $subs.Count -gt 0) {
                            $null = Set-AzContext -Subscription $subs[0].Id -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                        }
                        
                        $azureConnected = $true
                    }
                } catch {
                    Write-Warning "Failed to connect to Azure: $_"
                }
            }
        }
        
        # Store context
        $script:CrossTenantAccessContext = @{
            TenantId = $TenantId
            AuthenticationType = $AuthType
            ConnectedAt = Get-Date
            AzureConnected = $azureConnected
        }
        
        $connectionStatus = @()
        if ($azureConnected) { $connectionStatus += "Azure" }
        Write-Verbose "Successfully authenticated to: $($connectionStatus -join ', ')"
        
        return $true
        
    } catch {
        Write-Error "Failed to authenticate: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Gets Azure Lighthouse delegations for the authenticated context
#>
Function Get-LighthouseDelegations {
    [CmdletBinding()]
    Param()
    
    try {
        Write-Verbose "Discovering Azure Lighthouse delegations..."
        
        # Get current tenant context
        $currentContext = Get-AzContext
        $homeTenantId = $currentContext.Tenant.Id
        Write-Verbose "Home tenant: $homeTenantId"
        
        # Get all subscriptions accessible to the authenticated identity
        $subscriptions = Get-AzSubscription -ErrorAction Stop
        
        if (-not $subscriptions) {
            Write-Verbose "No subscriptions found"
            return @()
        }
        
        # If SubscriptionId is provided, filter to only that subscription
        if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
            $subscriptions = $subscriptions | Where-Object { $_.Id -eq $SubscriptionId }
            if (-not $subscriptions) {
                Write-Warning "Subscription $SubscriptionId not found or not accessible"
                return @()
            }
            Write-Verbose "Filtering to subscription: $SubscriptionId"
        }
        
        $delegations = foreach ($sub in $subscriptions) {
            Write-Verbose "Checking subscription: $($sub.Name) ($($sub.Id))"
            
            # Set context to this subscription
            try {
                $null = Set-AzContext -Subscription $sub.Id -ErrorAction Stop -WarningAction SilentlyContinue
                Write-Verbose "  Context set successfully"
            } catch {
                Write-Verbose "  Failed to set context: $_"
                continue
            }
            
            # Get all Lighthouse managed services assignments using the proper cmdlet
            try {
                $assignments = @(Get-AzManagedServicesAssignment -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
                Write-Verbose "  Found $($assignments.Count) Lighthouse assignment(s)"
                
                foreach ($assignment in $assignments) {
                    Write-Verbose "  Processing assignment: $($assignment.Name)"
                    
                    # Get the registration definition details
                    try {
                        $definition = Get-AzManagedServicesDefinition -Name $assignment.Properties.RegistrationDefinitionId.Split('/')[-1] -ErrorAction Stop
                        
                        # Determine scope from assignment
                        $assignmentScope = $assignment.Id
                        if ($assignmentScope -match '/resourceGroups/([^/]+)') {
                            $scope = 'ResourceGroup'
                            $target = $matches[1]
                            Write-Verbose "    Scope: ResourceGroup ($target)"
                        } else {
                            $scope = 'Subscription'
                            $target = $sub.Name
                            Write-Verbose "    Scope: Subscription"
                        }
                        
                        $managingTenantId = $definition.Properties.ManagedByTenantId
                        $offerName = $definition.Properties.RegistrationDefinitionName
                        $description = $definition.Properties.Description
                        
                        # Get role information
                        $roleInfo = @()
                        if ($definition.Properties.Authorizations) {
                            $roleInfo = $definition.Properties.Authorizations | ForEach-Object {
                                $roleGuid = $_.RoleDefinitionId
                                # Try to resolve GUID to role name
                                $roleName = $script:AzureRoleMap.GetEnumerator() | Where-Object { $_.Value -eq $roleGuid } | Select-Object -First 1 -ExpandProperty Key
                                if ($roleName) { 
                                    $roleName 
                                } else { 
                                    # Try to get role definition from Azure
                                    try {
                                        $roleDef = Get-AzRoleDefinition -Id $roleGuid -ErrorAction SilentlyContinue
                                        if ($roleDef) { $roleDef.Name } else { $roleGuid }
                                    } catch {
                                        $roleGuid
                                    }
                                }
                            }
                        }
                        
                        Write-Verbose "    Managing Tenant: $managingTenantId"
                        Write-Verbose "    Offer: $offerName"
                        Write-Verbose "    Roles: $($roleInfo -join ', ')"
                        
                        # Check if this is cross-tenant access
                        $isCrossTenant = $managingTenantId -ne $homeTenantId
                        
                        [PSCustomObject]@{
                            PSTypeName = 'CrossTenantAccess.Lighthouse'
                            Scope = $scope
                            Target = $target
                            OfferName = $offerName
                            Description = $description
                            ManagingTenant = $managingTenantId
                            TargetTenant = $sub.TenantId
                            Roles = if ($roleInfo.Count -gt 0) { ($roleInfo -join ', ') } else { 'Unknown' }
                            CrossTenant = $isCrossTenant
                            SubscriptionId = $sub.Id
                            SubscriptionName = $sub.Name
                            AssignmentId = $assignment.Id
                            DiscoveredAt = Get-Date
                        }
                    } catch {
                        Write-Verbose "    Failed to get definition details: $_"
                        
                        # Fallback - create entry with limited info
                        [PSCustomObject]@{
                            PSTypeName = 'CrossTenantAccess.Lighthouse'
                            Scope = 'Unknown'
                            Target = $sub.Name
                            OfferName = 'Unknown'
                            Description = $null
                            ManagingTenant = 'Unknown'
                            TargetTenant = $sub.TenantId
                            Roles = 'Unknown'
                            CrossTenant = $false
                            SubscriptionId = $sub.Id
                            SubscriptionName = $sub.Name
                            AssignmentId = $assignment.Id
                            DiscoveredAt = Get-Date
                        }
                    }
                }
            } catch {
                Write-Verbose "  Error querying assignments: $_"
            }
        }
        
        $count = ($delegations | Measure-Object).Count
        Write-Verbose "Found $count Lighthouse delegation(s)"
        
        return $delegations
        
    } catch {
        Write-Warning "Error discovering Lighthouse delegations: $_"
        return @()
    }
}

<#
.SYNOPSIS
    Creates an Azure Lighthouse ARM template for delegation

.DESCRIPTION
    This function generates an Azure Lighthouse ARM template with parameters for delegating
    subscription or resource group access from a target tenant to a managing tenant.
    
    The function creates a parameter file that can be deployed to establish Lighthouse delegation,
    granting the specified principal (user/group/service principal) a role in the target scope.
    
    Optionally, the template can be deployed immediately with the -Deploy switch.

.PARAMETER PrincipalId
    The Object ID (GUID) of the user, group, or service principal in the managing tenant
    that will be granted access. Found in Azure AD/Entra ID.

.PARAMETER Scope
    The scope of the delegation. Valid values are 'Subscription' or 'ResourceGroup'.

.PARAMETER Role
    The Azure RBAC role to assign. Accepts either a role name or GUID.
    
    Supported role names:
    - Reader, Contributor, Owner
    - UserAccessAdministrator
    - VirtualMachineContributor
    - StorageBlobDataContributor, StorageBlobDataReader
    - KeyVaultSecretsUser
    - MonitoringContributor, LogAnalyticsContributor
    - SecurityAdmin, NetworkContributor
    
    Or provide a custom role definition ID (GUID).
    Find full list: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles

.PARAMETER ManagingTenantId
    Your own tenant ID (GUID) - the tenant that will manage the delegated resources.

.PARAMETER TargetTenantId
    The tenant ID (GUID) where resources will be delegated from (customer tenant).

.PARAMETER SubscriptionId
    The subscription ID in the target tenant to delegate (required for both scopes).

.PARAMETER ResourceGroupName
    The resource group name to delegate (required when Scope is 'ResourceGroup').

.PARAMETER OfferName
    The name for this Lighthouse offer. This will be visible to the customer.
    Must be unique per subscription.

.PARAMETER OfferDescription
    Optional description of the offer, visible to the customer in Azure portal.

.PARAMETER PrincipalDisplayName
    Optional friendly name for the principal, visible to the customer.
    Defaults to the PrincipalId if not provided.

.PARAMETER OutputPath
    Directory where the parameter file will be saved. Defaults to current directory.

.PARAMETER Deploy
    If specified, attempts to deploy the template immediately to the target tenant.
    Requires authentication to the target tenant with Owner role.

.EXAMPLE
    New-LighthouseTemplate -PrincipalId "12345678-1234-1234-1234-123456789012" `
                           -Scope Subscription `
                           -Role Reader `
                           -ManagingTenantId "87654321-4321-4321-4321-210987654321" `
                           -TargetTenantId "11111111-2222-3333-4444-555555555555" `
                           -SubscriptionId "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" `
                           -OfferName "Contoso Managed Services" `
                           -OfferDescription "24/7 monitoring and support"
    
    Creates a Lighthouse template for subscription-level delegation with Reader role.

.EXAMPLE
    New-LighthouseTemplate -PrincipalId "12345678-1234-1234-1234-123456789012" `
                           -Scope ResourceGroup `
                           -Role Contributor `
                           -ResourceGroupName "rg-example" `
                           -ManagingTenantId "87654321-4321-4321-4321-210987654321" `
                           -TargetTenantId "11111111-2222-3333-4444-555555555555" `
                           -SubscriptionId "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" `
                           -OfferName "Contoso RG Management" `
                           -PrincipalDisplayName "Contoso Support Team" `
                           -Deploy
    
    Creates and immediately deploys a resource group delegation with Contributor role.

.EXAMPLE
    # Common role definition IDs for easy reference
    $roles = @{
        Reader = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
        Contributor = "b24988ac-6180-42a0-ab88-20f7382dd24c"
        Owner = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
    }
    
    New-LighthouseTemplate -PrincipalId "00000000-0000-0000-0000-000000000000" `
                           -Scope Subscription `
                           -Role Contributor `
                           -ManagingTenantId "your-tenant-id" `
                           -TargetTenantId "customer-tenant-id" `
                           -SubscriptionId "customer-sub-id" `
                           -OfferName "My MSP Services"

.OUTPUTS
    PSCustomObject with properties:
    - DeploymentName: Generated deployment name
    - Scope: Subscription or ResourceGroup
    - TemplateFile: Path to the ARM template file
    - ParameterFile: Path to generated parameter file
    - TargetSubscriptionId: Target subscription
    - TargetTenantId: Target tenant
    - ResourceGroupName: Resource group (if applicable)
    - Deployed: Boolean indicating if deployment was attempted

.NOTES
    The deployment must be executed by a user in the TARGET tenant with Owner role
    on the subscription or resource group being delegated.
    
    Common Azure Built-in Role IDs:
    - Reader: acdd72a7-3385-48ef-bd42-f606fba81ae7
    - Contributor: b24988ac-6180-42a0-ab88-20f7382dd24c
    - Owner: 8e3af657-a8ff-443c-a75c-2fe8c4bcb635
    - User Access Administrator: 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9
    
    Full list: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles
#>
Function New-LighthouseTemplate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$PrincipalId,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Subscription', 'ResourceGroup')]
        [string]$Scope,
        
        [Parameter(Mandatory=$true)]
        [string]$Role,
        
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$ManagingTenantId,
        
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TargetTenantId,
        
        [Parameter(Mandatory=$true, ParameterSetName='Subscription')]
        [Parameter(Mandatory=$true, ParameterSetName='ResourceGroup')]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory=$true, ParameterSetName='ResourceGroup')]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$OfferName,
        
        [string]$OfferDescription,
        
        [string]$PrincipalDisplayName,
        
        [ValidateScript({Test-Path $_ -IsValid})]
        [string]$OutputPath = ".",
        
        [switch]$Deploy,
        
        [Parameter(Mandatory=$false)]
        [string]$DeploymentPrincipal
    )
    
    try {
        Write-Verbose "Creating Lighthouse template for $Scope scope..."
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            Write-Verbose "Creating output directory: $OutputPath"
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        # Resolve role to GUID
        $roleDefinitionId = if ($script:AzureRoleMap.ContainsKey($Role)) {
            Write-Verbose "Mapping role '$Role' to GUID: $($script:AzureRoleMap[$Role])"
            $script:AzureRoleMap[$Role]
        } elseif ($Role -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
            Write-Verbose "Using custom role GUID: $Role"
            $Role
        } else {
            throw "Invalid role '$Role'. Must be a supported role name or valid GUID. Supported names: $($script:AzureRoleMap.Keys -join ', ')"
        }
        
        # Generate unique deployment name
        $deploymentName = "Lighthouse-$($OfferName -replace '[^a-zA-Z0-9]','')-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        # Create the ARM template based on scope
        if ($Scope -eq 'ResourceGroup') {
            # Resource Group scoped Lighthouse template
            $template = @{
                '$schema' = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                contentVersion = '1.0.0.0'
                parameters = @{
                    mspOfferName = @{
                        type = 'string'
                        metadata = @{
                            description = 'Specify a unique name for your offer'
                        }
                    }
                    mspOfferDescription = @{
                        type = 'string'
                        metadata = @{
                            description = 'Name of the Managed Service Provider offering'
                        }
                    }
                    managedByTenantId = @{
                        type = 'string'
                        metadata = @{
                            description = 'Specify the tenant id of the Managed Service Provider'
                        }
                    }
                    authorizations = @{
                        type = 'array'
                        metadata = @{
                            description = 'Specify an array of objects, containing tuples of Azure Active Directory principalId, a Azure roleDefinitionId, and an optional principalIdDisplayName. The roleDefinition specified is granted to the principalId in the provider''s Active Directory and the principalIdDisplayName is visible to customers.'
                        }
                    }
                    rgName = @{
                        type = 'string'
                    }
                }
                variables = @{
                    mspRegistrationName = "[guid(parameters('mspOfferName'))]"
                    mspAssignmentName = "[guid(parameters('mspOfferName'))]"
                }
                resources = @(
                    @{
                        type = 'Microsoft.ManagedServices/registrationDefinitions'
                        apiVersion = '2019-06-01'
                        name = "[variables('mspRegistrationName')]"
                        properties = @{
                            registrationDefinitionName = "[parameters('mspOfferName')]"
                            description = "[parameters('mspOfferDescription')]"
                            managedByTenantId = "[parameters('managedByTenantId')]"
                            authorizations = "[parameters('authorizations')]"
                        }
                    }
                    @{
                        type = 'Microsoft.Resources/deployments'
                        apiVersion = '2018-05-01'
                        name = 'rgAssignment'
                        resourceGroup = "[parameters('rgName')]"
                        dependsOn = @(
                            "[resourceId('Microsoft.ManagedServices/registrationDefinitions/', variables('mspRegistrationName'))]"
                        )
                        properties = @{
                            mode = 'Incremental'
                            template = @{
                                '$schema' = 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#'
                                contentVersion = '1.0.0.0'
                                parameters = @{}
                                resources = @(
                                    @{
                                        type = 'Microsoft.ManagedServices/registrationAssignments'
                                        apiVersion = '2019-06-01'
                                        name = "[variables('mspAssignmentName')]"
                                        properties = @{
                                            registrationDefinitionId = "[resourceId('Microsoft.ManagedServices/registrationDefinitions/', variables('mspRegistrationName'))]"
                                        }
                                    }
                                )
                            }
                        }
                    }
                )
                outputs = @{
                    mspOfferName = @{
                        type = 'string'
                        value = "[concat('Managed by', ' ', parameters('mspOfferName'))]"
                    }
                    authorizations = @{
                        type = 'array'
                        value = "[parameters('authorizations')]"
                    }
                }
            }
        } else {
            # Subscription scoped Lighthouse template
            $template = @{
                '$schema' = 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                contentVersion = '1.0.0.0'
                parameters = @{
                    mspOfferName = @{
                        type = 'string'
                        metadata = @{
                            description = 'Specify a unique name for your offer'
                        }
                    }
                    mspOfferDescription = @{
                        type = 'string'
                        metadata = @{
                            description = 'Name of the Managed Service Provider offering'
                        }
                    }
                    managedByTenantId = @{
                        type = 'string'
                        metadata = @{
                            description = 'Specify the tenant id of the Managed Service Provider'
                        }
                    }
                    authorizations = @{
                        type = 'array'
                        metadata = @{
                            description = 'Specify an array of objects, containing tuples of Azure Active Directory principalId, a Azure roleDefinitionId, and an optional principalIdDisplayName. The roleDefinition specified is granted to the principalId in the provider''s Active Directory and the principalIdDisplayName is visible to customers.'
                        }
                    }
                }
                variables = @{
                    mspRegistrationName = "[guid(parameters('mspOfferName'))]"
                    mspAssignmentName = "[guid(parameters('mspOfferName'))]"
                }
                resources = @(
                    @{
                        type = 'Microsoft.ManagedServices/registrationDefinitions'
                        apiVersion = '2019-09-01'
                        name = "[variables('mspRegistrationName')]"
                        properties = @{
                            registrationDefinitionName = "[parameters('mspOfferName')]"
                            description = "[parameters('mspOfferDescription')]"
                            managedByTenantId = "[parameters('managedByTenantId')]"
                            authorizations = "[parameters('authorizations')]"
                        }
                    }
                    @{
                        type = 'Microsoft.ManagedServices/registrationAssignments'
                        apiVersion = '2019-09-01'
                        name = "[variables('mspAssignmentName')]"
                        dependsOn = @(
                            "[resourceId('Microsoft.ManagedServices/registrationDefinitions/', variables('mspRegistrationName'))]"
                        )
                        properties = @{
                            registrationDefinitionId = "[resourceId('Microsoft.ManagedServices/registrationDefinitions/', variables('mspRegistrationName'))]"
                        }
                    }
                )
                outputs = @{
                    mspOfferName = @{
                        type = 'string'
                        value = "[concat('Managed by', ' ', parameters('mspOfferName'))]"
                    }
                    authorizations = @{
                        type = 'array'
                        value = "[parameters('authorizations')]"
                    }
                }
            }
        }
        
        # Convert to JSON and save template file
        $templateContent = $template | ConvertTo-Json -Depth 20
        $templateFile = Join-Path $OutputPath "$deploymentName.json"
        $templateContent | Out-File -FilePath $templateFile -Encoding utf8
        Write-Host "Template file created: $templateFile" -ForegroundColor Green
        
        # Create parameter file with actual values
        $parameterFileContent = @{
            '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
            contentVersion = '1.0.0.0'
            parameters = @{
                mspOfferName = @{ value = $OfferName }
                mspOfferDescription = @{ value = if ($OfferDescription) { $OfferDescription } else { $OfferName } }
                managedByTenantId = @{ value = $ManagingTenantId }
                authorizations = @{
                    value = @(
                        @{
                            principalId = $PrincipalId
                            principalIdDisplayName = if ($PrincipalDisplayName) { $PrincipalDisplayName } else { $PrincipalId }
                            roleDefinitionId = $roleDefinitionId
                        }
                    )
                }
            }
        }
        
        if ($Scope -eq 'ResourceGroup') {
            $parameterFileContent.parameters['rgName'] = @{ value = $ResourceGroupName }
        }
        
        $parameterFile = Join-Path $OutputPath "$deploymentName.parameters.json"
        ($parameterFileContent | ConvertTo-Json -Depth 20) | Out-File -FilePath $parameterFile -Encoding utf8
        Write-Host "Parameter file created: $parameterFile" -ForegroundColor Green
        
        $result = [PSCustomObject]@{
            DeploymentName = $deploymentName
            Scope = $Scope
            TemplateFile = $templateFile
            ParameterFile = $parameterFile
            TargetSubscriptionId = $SubscriptionId
            TargetTenantId = $TargetTenantId
            ResourceGroupName = if ($Scope -eq 'ResourceGroup') { $ResourceGroupName } else { $null }
            Deployed = $false
        }
        
        # Deploy if requested
        if ($Deploy) {
            Write-Host "`nDeploying Lighthouse template to target tenant..." -ForegroundColor Cyan
            Write-Warning "This deployment must be executed by a user in the target tenant ($TargetTenantId) with Owner permissions."
            Write-Host "Connecting to target tenant..." -ForegroundColor Yellow
            
            # Connect to target tenant
            if ($DeploymentPrincipal) {
                Write-Host "Connecting as: $DeploymentPrincipal" -ForegroundColor Yellow
                Connect-AzAccount -TenantId $TargetTenantId -SubscriptionId $SubscriptionId -AccountId $DeploymentPrincipal | Out-Null
            } else {
                Connect-AzAccount -TenantId $TargetTenantId -SubscriptionId $SubscriptionId | Out-Null
            }
            
            # Deploy template
            $deployParams = @{
                Name = $deploymentName
                Location = 'westeurope'  # Required for subscription deployments
                TemplateFile = $templateFile
                TemplateParameterFile = $parameterFile
                Verbose = $true
            }
            
            Write-Host "Deploying to subscription $SubscriptionId..." -ForegroundColor Cyan
            $deployment = New-AzSubscriptionDeployment @deployParams
            
            if ($deployment.ProvisioningState -eq 'Succeeded') {
                Write-Host "Deployment successful!" -ForegroundColor Green
                $result.Deployed = $true
            } else {
                Write-Warning "Deployment state: $($deployment.ProvisioningState)"
            }
        } else {
            Write-Host "`nTemplate files created. To deploy manually, run:" -ForegroundColor Yellow
            if ($DeploymentPrincipal) {
                Write-Host "  1. Connect to target tenant: Connect-AzAccount -TenantId $TargetTenantId -SubscriptionId $SubscriptionId -AccountId $DeploymentPrincipal" -ForegroundColor White
            } else {
                Write-Host "  1. Connect to target tenant: Connect-AzAccount -TenantId $TargetTenantId -SubscriptionId $SubscriptionId" -ForegroundColor White
            }
            Write-Host "  2. Deploy: New-AzSubscriptionDeployment -Name $deploymentName -Location westeurope -TemplateFile $templateFile -TemplateParameterFile $parameterFile" -ForegroundColor White
        }
        
        return $result
        
    } catch {
        Write-Error "Failed to create/deploy Lighthouse template: $_"
        throw
    }
}

#endregion

#region Public Functions

<#
.SYNOPSIS
    Discovers cross-tenant access via Azure Lighthouse

.DESCRIPTION
    Invoke-DarkLighthouse has two modes:
    
    1. Discovery Mode (default): Discovers Azure Lighthouse delegations
       - Checks all subscriptions accessible to the authenticated identity
       - Supports both user and service principal authentication
    
    2. Add Persistence Mode (-AddPersistence): Creates and optionally deploys an Azure 
       Lighthouse delegation template to establish persistent access from a managing tenant
       to a target tenant.
    
    IMPORTANT: Before running discovery, ensure any PIM-eligible Lighthouse delegations
    or group memberships are activated in Azure Portal. This tool only discovers ACTIVE
    assignments, not eligible ones.

.PARAMETER Wizard
    Launch interactive wizard mode to guide through options

.PARAMETER AddPersistence
    Switch to enable Lighthouse template creation mode instead of discovery mode.

.PARAMETER TemplateOnly
    Switch to create Lighthouse template files without deployment or authentication.
    Use -TemplateOutPath to specify output directory.

.PARAMETER Username
    Username for interactive authentication (Discovery mode)

.PARAMETER ApplicationId
    Application (Client) ID for service principal authentication

.PARAMETER ClientSecret
    Client secret as SecureString for service principal authentication

.PARAMETER TenantId
    The home tenant ID to authenticate against

.PARAMETER SubscriptionId
    Optional: Specific subscription ID to check for Lighthouse delegations
    If not specified, all accessible subscriptions will be checked
    For template creation modes, this parameter is mandatory

.PARAMETER PrincipalId
    (AddPersistence mode) Object ID of the principal in managing tenant to grant access

.PARAMETER Scope
    (AddPersistence mode) Delegation scope: Subscription or ResourceGroup

.PARAMETER Role
    (AddPersistence mode) Azure RBAC role name (Reader, Contributor, Owner, etc.) or custom GUID

.PARAMETER ManagingTenantId
    (AddPersistence mode) Your MSP/managing tenant ID

.PARAMETER TargetTenantId
    (AddPersistence mode) Customer/target tenant ID where resources are delegated from

.PARAMETER SubscriptionId
    (AddPersistence mode) Subscription ID in target tenant

.PARAMETER ResourceGroupName
    (AddPersistence mode) Resource group name (required when Scope is ResourceGroup)

.PARAMETER OfferName
    (AddPersistence mode) Name for the Lighthouse offer (visible to customer)

.PARAMETER OfferDescription
    (AddPersistence mode) Description of the offer (visible to customer)

.PARAMETER PrincipalDisplayName
    (AddPersistence mode) Friendly name for the principal

.PARAMETER OutputPath
    (AddPersistence mode) Directory for parameter file output (default: current directory)

.PARAMETER TemplateOutPath
    (TemplateOnly mode) Directory for template and parameter file output (default: current directory)

.PARAMETER Deploy
    (AddPersistence mode) Deploy the template immediately to target tenant

.EXAMPLE
    Invoke-DarkLighthouse
    
    Launches interactive wizard mode with ASCII art banner and guided menu

.EXAMPLE
    Invoke-DarkLighthouse -Wizard
    
    Explicitly launches wizard mode for guided configuration

.EXAMPLE
    Invoke-DarkLighthouse -Username "admin@contoso.com" -TenantId "00000000-0000-0000-0000-000000000000"
    
    Discovery mode: Performs interactive authentication and checks Lighthouse delegations

.EXAMPLE
    Invoke-DarkLighthouse -TemplateOnly `
                          -PrincipalId "12345678-1234-1234-1234-123456789012" `
                          -Scope Subscription `
                          -Role Reader `
                          -ManagingTenantId "msp-tenant-id" `
                          -TargetTenantId "customer-tenant-id" `
                          -SubscriptionId "customer-sub-id" `
                          -OfferName "Monitoring Services" `
                          -TemplateOutPath "C:\Templates"
    
    Creates Lighthouse template files without authentication or deployment

.EXAMPLE
    Invoke-DarkLighthouse -AddPersistence `
                          -PrincipalId "12345678-1234-1234-1234-123456789012" `
                          -Scope Subscription `
                          -Role Reader `
                          -ManagingTenantId "msp-tenant-id" `
                          -TargetTenantId "customer-tenant-id" `
                          -SubscriptionId "customer-sub-id" `
                          -OfferName "Contoso Managed Services"
    
    Creates a Lighthouse delegation template for subscription-level access with Reader role

.EXAMPLE
    Invoke-DarkLighthouse -AddPersistence `
                          -PrincipalId "12345678-1234-1234-1234-123456789012" `
                          -Scope ResourceGroup `
                          -ResourceGroupName "rg-example" `
                          -Role Contributor `
                          -ManagingTenantId "msp-tenant-id" `
                          -TargetTenantId "customer-tenant-id" `
                          -SubscriptionId "customer-sub-id" `
                          -OfferName "RG Management" `
                          -Deploy
    
    Creates and deploys a resource group delegation with Contributor role

.EXAMPLE
    $secret = ConvertTo-SecureString "your-client-secret" -AsPlainText -Force
    Invoke-DarkLighthouse -ApplicationId "00000000-0000-0000-0000-000000000000" -ClientSecret $secret -TenantId "00000000-0000-0000-0000-000000000001"
    
    Authenticates as service principal and runs Lighthouse checks

.OUTPUTS
    Discovery Mode: PSCustomObject with properties:
    - TenantId: The authenticated tenant ID
    - AuthenticationType: The authentication method used
    - DiscoveryDate: When the discovery was performed
    - LighthouseAccess: Array of Lighthouse delegations
    - Warnings: Array of warning messages
    
    AddPersistence Mode: PSCustomObject with properties:
    - DeploymentName: Generated deployment name
    - Scope: Subscription or ResourceGroup
    - TemplateFile: Path to ARM template file
    - ParameterFile: Path to parameter file
    - TargetSubscriptionId: Target subscription
    - TargetTenantId: Target tenant
    - ResourceGroupName: Resource group (if applicable)
    - Deployed: Boolean if deployment was attempted

.NOTES
    Discovery Mode Authentication:
    - Interactive: Uses Azure PowerShell interactive login
    - Service Principal: Uses ApplicationId and ClientSecret
    
    Both authentication methods require appropriate Azure RBAC permissions to read
    Azure Lighthouse delegations in the accessible subscriptions.
    
    AddPersistence Mode Requirements:
    - Deployment must be executed by user in TARGET tenant with Owner role
    
    Supported Role Names:
    Reader, Contributor, Owner, UserAccessAdministrator, VirtualMachineContributor,
    StorageBlobDataContributor, StorageBlobDataReader, KeyVaultSecretsUser,
    MonitoringContributor, LogAnalyticsContributor, SecurityAdmin, NetworkContributor
#>
Function Invoke-DarkLighthouse {
    [CmdletBinding(DefaultParameterSetName='Interactive')]
    Param(
        # Wizard Mode
        [Parameter(ParameterSetName='Wizard', Mandatory=$false)]
        [switch]$Wizard,
        
        # Mode Selection
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [switch]$AddPersistence,
        
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [switch]$TemplateOnly,
        
        # Internal parameter to hide banner when called from wizard
        [Parameter(DontShow)]
        [switch]$HideBanner,
        
        # Authentication: Interactive
        [Parameter(ParameterSetName='Interactive')]
        [string]$Username,
        
        # Authentication: ServicePrincipal
        [Parameter(ParameterSetName='ServicePrincipal', Mandatory=$true)]
        [string]$ApplicationId,
        
        [Parameter(ParameterSetName='ServicePrincipal', Mandatory=$true)]
        [SecureString]$ClientSecret,
        
        # Required for discovery mode parameter sets only
        [Parameter(ParameterSetName='Interactive', Mandatory=$false)]
        [Parameter(ParameterSetName='ServicePrincipal', Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,
        
        # Lighthouse Template Parameters (used with -AddPersistence)
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$PrincipalId,
        
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [ValidateSet('Subscription', 'ResourceGroup')]
        [string]$Scope,
        
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [string]$Role,
        
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$ManagingTenantId,
        
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TargetTenantId,
        
        # Subscription ID - Optional for discovery modes, Mandatory for template modes
        [Parameter(ParameterSetName='Interactive')]
        [Parameter(ParameterSetName='ServicePrincipal')]
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$SubscriptionId,
        
        [Parameter(ParameterSetName='AddPersistence')]
        [Parameter(ParameterSetName='TemplateOnly')]
        [string]$ResourceGroupName,
        
        [Parameter(ParameterSetName='AddPersistence', Mandatory=$true)]
        [Parameter(ParameterSetName='TemplateOnly', Mandatory=$true)]
        [string]$OfferName,
        
        [Parameter(ParameterSetName='AddPersistence')]
        [Parameter(ParameterSetName='TemplateOnly')]
        [string]$OfferDescription,
        
        [Parameter(ParameterSetName='AddPersistence')]
        [Parameter(ParameterSetName='TemplateOnly')]
        [string]$PrincipalDisplayName,
        
        [Parameter(ParameterSetName='AddPersistence')]
        [ValidateScript({Test-Path $_ -IsValid})]
        [string]$OutputPath = ".",
        
        [Parameter(ParameterSetName='TemplateOnly')]
        [ValidateScript({Test-Path $_ -IsValid})]
        [string]$TemplateOutPath = ".",
        
        [Parameter(ParameterSetName='AddPersistence')]
        [switch]$Deploy,
        
        [Parameter(ParameterSetName='AddPersistence')]
        [string]$DeploymentPrincipal
    )
    
    Begin {
        # Check if Wizard mode or no parameters (wizard displays its own banner)
        if ($Wizard -or ($PSCmdlet.ParameterSetName -eq 'Wizard')) {
            Start-DarkLighthouseWizard
            return
        }
        
        # Check if no parameters provided (invoke wizard by default)
        if (-not $PSBoundParameters.ContainsKey('TenantId') -and 
            -not $PSBoundParameters.ContainsKey('AddPersistence') -and
            -not $PSBoundParameters.ContainsKey('TemplateOnly')) {
            Start-DarkLighthouseWizard
            return
        }
        
        # Display ASCII art banner for non-wizard modes (unless hidden)
        if (-not $HideBanner) {
            Show-LighthouseBanner
        }
        
        # Check if TemplateOnly mode
        if ($TemplateOnly) {
            Write-Host "Creating Azure Lighthouse template files..." -ForegroundColor Cyan
            
            # Call New-LighthouseTemplate with provided parameters
            $templateParams = @{
                PrincipalId = $PrincipalId
                Scope = $Scope
                Role = $Role
                ManagingTenantId = $ManagingTenantId
                TargetTenantId = $TargetTenantId
                SubscriptionId = $SubscriptionId
                OfferName = $OfferName
                OutputPath = $TemplateOutPath
            }
            
            if ($ResourceGroupName) { $templateParams['ResourceGroupName'] = $ResourceGroupName }
            if ($OfferDescription) { $templateParams['OfferDescription'] = $OfferDescription }
            if ($PrincipalDisplayName) { $templateParams['PrincipalDisplayName'] = $PrincipalDisplayName }
            
            $result = New-LighthouseTemplate @templateParams
            
            Write-Host "`nTemplate files created successfully!" -ForegroundColor Green
            Write-Host "Template file: $($result.TemplateFile)" -ForegroundColor White
            Write-Host "Parameter file: $($result.ParameterFile)" -ForegroundColor White
            
            # Set flag to skip processing block
            $script:SkipProcessing = $true
            return $result
        }
        
        # Check if AddPersistence mode
        if ($AddPersistence) {
            Write-Host "Creating Azure Lighthouse delegation template..." -ForegroundColor Cyan
            
            # Call New-LighthouseTemplate with provided parameters
            $templateParams = @{
                PrincipalId = $PrincipalId
                Scope = $Scope
                Role = $Role
                ManagingTenantId = $ManagingTenantId
                TargetTenantId = $TargetTenantId
                SubscriptionId = $SubscriptionId
                OfferName = $OfferName
                OutputPath = $OutputPath
            }
            
            if ($ResourceGroupName) { $templateParams['ResourceGroupName'] = $ResourceGroupName }
            if ($OfferDescription) { $templateParams['OfferDescription'] = $OfferDescription }
            if ($PrincipalDisplayName) { $templateParams['PrincipalDisplayName'] = $PrincipalDisplayName }
            if ($Deploy) { $templateParams['Deploy'] = $true }
            if ($DeploymentPrincipal) { $templateParams['DeploymentPrincipal'] = $DeploymentPrincipal }
            
            $result = New-LighthouseTemplate @templateParams
            $script:SkipProcessing = $true
            return $result
        }
        
        $script:SkipProcessing = $false
        Write-Verbose "Starting cross-tenant access discovery..."
        
        # Determine authentication type
        $authType = $PSCmdlet.ParameterSetName
        
        # Authenticate
        $authParams = @{
            AuthType = $authType
            TenantId = $TenantId
        }
        
        switch ($authType) {
            'Interactive' {
                if ($Username) {
                    $authParams['Username'] = $Username
                }
            }
            'ServicePrincipal' {
                $authParams['ApplicationId'] = $ApplicationId
                $authParams['ClientSecret'] = $ClientSecret
            }
        }
        
        # Only connect to Azure for Lighthouse checks
        $connected = Connect-Services @authParams
        
        if (-not $connected) {
            throw "Failed to establish connection"
        }
        
        # Set flag to ensure Process block only runs once
        $script:ProcessExecuted = $false
    }
    
    Process {
        # Skip if we're in AddPersistence mode or already executed
        if ($script:SkipProcessing -or $script:ProcessExecuted) {
            return
        }
        
        # Mark as executed to prevent multiple runs
        $script:ProcessExecuted = $true
        
        # Display PIM eligibility reminder
        Write-Host ""
        Write-Host "IMPORTANT REMINDERS:" -ForegroundColor Yellow
        Write-Host "  • Eligible Lighthouse access (PIM) requires activation in Azure Portal before discovery" -ForegroundColor White
        Write-Host "  • Eligible group memberships that grant Lighthouse access also require activation" -ForegroundColor White
        Write-Host "  • This tool only discovers ACTIVE delegations, not eligible assignments" -ForegroundColor White
        Write-Host ""
        
        $proceed = Read-Host "Have you activated any eligible roles/groups? [Y/N]"
        if ($proceed -notmatch '^[Yy]') {
            Write-Host "Discovery cancelled. Please activate eligible roles in Azure Portal if needed." -ForegroundColor Cyan
            return
        }
        
        # Initialize results object
        $results = [PSCustomObject]@{
            PSTypeName = 'CrossTenantAccess.Report'
            TenantId = $TenantId
            AuthenticationType = $authType
            DiscoveryDate = Get-Date
            LighthouseAccess = @()
            Warnings = @()
        }
        
        # LIGHTHOUSE CHECKS
        if ($script:CrossTenantAccessContext.AzureConnected) {
            Write-Host "Checking Azure Lighthouse delegations..." -ForegroundColor Cyan
            $results.LighthouseAccess = @(Get-LighthouseDelegations)
            
            if ($results.LighthouseAccess.Count -gt 0) {
                Write-Host "  Found $($results.LighthouseAccess.Count) Lighthouse delegation(s)" -ForegroundColor Green
            } else {
                Write-Host "  No Lighthouse delegations found" -ForegroundColor Yellow
            }
        } else {
            $warning = "Lighthouse checks skipped: Azure connection failed"
            $results.Warnings += $warning
            Write-Warning $warning
        }
        
        # Display detailed results
        if ($results.LighthouseAccess.Count -gt 0) {
            Write-Host "`nAzure Lighthouse Delegations:" -ForegroundColor Cyan
            
            # Filter out Unknown/blank values and format output
            $cleanedResults = $results.LighthouseAccess | ForEach-Object {
                $props = [ordered]@{}
                
                foreach ($prop in $_.PSObject.Properties) {
                    $value = $prop.Value
                    # Include property if it's not null, empty, "Unknown", or "False" for CrossTenant
                    if ($value -and 
                        $value -ne "Unknown" -and 
                        $value -ne "" -and
                        -not ($prop.Name -eq "CrossTenant" -and $value -eq $false) -and
                        -not ($prop.Name -eq "Description" -and [string]::IsNullOrWhiteSpace($value))) {
                        $props[$prop.Name] = $value
                    }
                }
                
                [PSCustomObject]$props
            }
            
            $cleanedResults | Format-List | Out-Host
        }
        
        # Summary
        Write-Host "`nDiscovery Summary:" -ForegroundColor Green
        Write-Host "  Lighthouse Delegations: $($results.LighthouseAccess.Count)" -ForegroundColor White
        if ($results.Warnings.Count -gt 0) {
            Write-Host "  Warnings: $($results.Warnings.Count)" -ForegroundColor Yellow
        }
        
        # Return the results object so it can be captured
        Write-Output $results
    }
    
    End {
        Write-Verbose "Cross-tenant access discovery complete"
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function Invoke-DarkLighthouse, New-LighthouseTemplate


