# How to use self-size certificates with API Management and ASE (App Service Environment)

## Who is this for

This is for a scenario where an organization may want to use API Management to consume services hosted on an ASE (APP Service environment) possibly during the dev/test phase of development.

<INSERT DIAGRAM>

## Requirements:

- Deploy the APIM Management in internal mode
- Deploy the ASE in internal mode
- Generate the self-signed certificates

## Installation Instructions

### Generate root CA and wildcard certificate for the ASE

This self-signedd certificate will be used in the ASE

```
# Set the variables
$domain = "mycontosoase.com"
$secret = "StrongP@ssword"
$pfxPassword = ConvertTo-SecureString -String $secret -Force -AsPlainText
$certStore = "cert:\CurrentUser\My"

# Generate a a rootCA
$rootCertAse = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject "CN=$domain" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "$certStore" -KeyUsageProperty Sign -KeyUsage CertSign

# Export the rootCA's public key as a .cer
$rootCertAseThumbprint = $certStore + "\" + $rootCertAse.Thumbprint
Export-Certificate -Cert $rootCertAseThumbprint -FilePath "c:\certs\rootCA-$domain.cer"

# Generate a self-signed certificate for the ASE signed by the rootCA
$certAse = New-SelfSignedCertificate `
-HashAlgorithm sha256 -KeyLength 2048 `
-Signer $rootCert `
-dnsname "*.$domain","*.scm.$domain" `
-CertStoreLocation "$certStore"

$certAseThumbprint = $certStore + "\" + $certAse.Thumbprint
Export-PfxCertificate -cert $certAseThumbprint -FilePath "c:\certs\$domain.pfx" -Password $pfxPassword
```

### Deploy the API Management in internal mode

In internal mode the API Management gets assigned an private IP from the subnet where it was deployed.

```
# Connect to Azure or log into a cloude shell and skip connecting to azure
Connect-AzAccount

# Create a resouce group
$resGroupName = "apim-appGw-RG" # resource group name
$location = "West US"           # Azure region
New-AzResourceGroup -Name $resGroupName -Location $location

# Create a virtual network
$apimsubnet = New-AzVirtualNetworkSubnetConfig -Name "apim02" -AddressPrefix "10.0.1.0/24"
$vnet = New-AzVirtualNetwork -Name "appgwvnet" -ResourceGroupName $resGroupName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $apimsubnet

# Create the API inside the vnet
$apimsubnetdata = $vnet.Subnets[1]
$apimVirtualNetwork = New-AzApiManagementVirtualNetwork -SubnetResourceId $apimsubnetdata.Id
$apimServiceName = "ContosoApi"       # API Management service instance name
$apimOrganization = "Contoso"         # organization name
$apimAdminEmail = "admin@contoso.com" # administrator's email address
$apimService = New-AzApiManagement -ResourceGroupName $resGroupName -Location $location -Name $apimServiceName -Organization $apimOrganization -AdminEmail $apimAdminEmail -VirtualNetwork $apimVirtualNetwork -VpnType "Internal" -Sku "Developer"

```

Once the ASE is created, deploy the rootCA-mycontoso.com.cer to the root CA store.

<INSERT IMAGE>

### Deploy the ASE in internal mode

In internal mode the ASE gets assigned an private IP from the subnet where it was deployed. To deploy an ASE:

- Log into the Azure Portal
- Create a new resource of type App Service Environment V2
- Select or create a resource group
- Select internal for the mode 
- Enter: mycontosoase.com for the domain.

<INSERT IMAGE>

Once the ASE is created, update the ILB certificate with the mycontoso.com.pfx certificate. Note that this step can take up to one hour.

### DNS Configuration

Once API Management and ASE are 
