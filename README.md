# How to use self-size certificates with API Management and ASE (App Service Environment)

## 1.0 Who is this for

This is for a scenario where an organization may want to use API Management to consume services hosted on an ASE (APP Service environment) possibly during the dev/test phase of development.

INSERT IMAGE

## 2.0 Requirements:

- Generate the rootCA and ASE ILB self-signed wildcard certificate
- Deploy the APIM Management in internal mode
  - Install the generated rootCA.cer in the root CA store
- Deploy the ASE in internal mode
  - Install the generated domain.pfx in as the ASE ILB certificate
  - Create an API app
- Configure the DNS to point to the API APP

## 3.0 Installation Instructions

### 3.1 Generate the rootCA and ASE ILB self-signed wildcard certificate

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

### 3.2 Deploy the API Management in internal mode

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
$apimServiceName = "mycontosoapim"       # API Management service instance name
$apimOrganization = "Contoso"         # organization name
$apimAdminEmail = "admin@contoso.com" # administrator's email address
$apimService = New-AzApiManagement -ResourceGroupName $resGroupName -Location $location -Name $apimServiceName -Organization $apimOrganization -AdminEmail $apimAdminEmail -VirtualNetwork $apimVirtualNetwork -VpnType "Internal" -Sku "Developer"

```

Once the ASE is created, deploy the rootCA-mycontoso.com.cer to the root CA store. This is allow encrypted communication fro the APIM to the ASE.

INSERT IMAGE

### 3.3 Deploy the ASE in internal mode

In internal mode the ASE gets assigned an private IP from the subnet where it was deployed. To deploy an ASE:

- Log into the Azure Portal
- Create a new resource of type App Service Environment V2
- Select or create a resource group
- Select internal for the mode 
- Enter: mycontosoase.com for the domain.

INSERT IMAGE

Once the ASE is created, update the ILB certificate with the mycontoso.com.pfx certificate. Note that this step can take up to one hour.

### 3.4 DNS Configuration

Once API Management and ASE are 


## References

- Integrate API Management in an internal VNET with Application Gateway
  - https://docs.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway
