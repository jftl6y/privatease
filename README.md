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

```
# Set the variables
$domain = "mycontosoase.com"
$secret = "StrongP@ssword"
$pfxPassword = ConvertTo-SecureString -String $secret -Force -AsPlainText
$path = $PWD
$certStore = "cert:\CurrentUser\My"

# Generate a a rootCA
$rootCertAse = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject "CN=$domain" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "$certStore" -KeyUsageProperty Sign -KeyUsage CertSign

# Export the rootCA's public key as a .cer

# Generate a self-signed certificate for the ASE signed by the rootCA
$certAse = New-SelfSignedCertificate `
-HashAlgorithm sha256 -KeyLength 2048 `
-Signer $rootCert `
-dnsname "*.$domain","*.scm.$domain" `
-CertStoreLocation "$certStore"

$certAseThumbprint = $certStore + "\" + $certAse.Thumbprint
$password = ConvertTo-SecureString -String $passwd -Force -AsPlainText
$fileName = "D:\certs\asedemo\ilbase.$domain.pfx" 
Export-PfxCertificate -cert $certAseThumbprint -FilePath $fileName -Password $password
```

### Deploy the API Management in internal mode

In internal mode the API Management gets assigned an private IP from the subnet where it was deployed.



### Deploy the ASE in internal mode

In internal mode the ASE gets assigned an private IP from the subnet where it was deployed.



