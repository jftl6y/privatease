Login-AzureRmAccount

$resGroupName = "apim-appGw-RG" # resource group name
$location = "West US"           # Azure region
New-AzResourceGroup -Name $resGroupName -Location $location

$appgatewaysubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "apim01" -AddressPrefix "10.3.0.0/24"
$apimsubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "apim02" -AddressPrefix "10.3.1.0/24"

# Create the VNET witht he three subnets
$vnet = New-AzureRmVirtualNetwork -Name "appgwvnet" -ResourceGroupName $resGroupName -Location $location -AddressPrefix "10.3.0.0/20" -Subnet $appgatewaysubnet,$apimsubnet
$appgatewaysubnetdata = $vnet.Subnets[0]
$apimsubnetdata = $vnet.Subnets[1]
$apimVirtualNetwork = New-AzureRmApiManagementVirtualNetwork -Location $location -SubnetResourceId $apimsubnetdata.Id

# Create the API Management developer instance in internal mode
$apimServiceName = "ContosoApi"       # API Management service instance name
$apimOrganization = "Contoso"         # organization name
$apimAdminEmail = "admin@contoso.com" # administrator's email address
$apimService = New-AzApiManagement -ResourceGroupName $resGroupName -Location $location -Name $apimServiceName -Organization $apimOrganization -AdminEmail $apimAdminEmail -VirtualNetwork $apimVirtualNetwork -VpnType "Internal" -Sku "Developer"

# Initialize the certificates
$gatewayHostname = "api.contoso.net"                 # API gateway host
$portalHostname = "portal.contoso.net"               # API developer portal host
$gatewayCertCerPath = "C:\Users\Contoso\gateway.cer" # full path to api.contoso.net .cer file
$gatewayCertPfxPath = "C:\Users\Contoso\gateway.pfx" # full path to api.contoso.net .pfx file
$portalCertPfxPath = "C:\Users\Contoso\portal.pfx"   # full path to portal.contoso.net .pfx file
$gatewayCertPfxPassword = "certificatePassword123"   # password for api.contoso.net pfx certificate
$portalCertPfxPassword = "certificatePassword123"    # password for portal.contoso.net pfx certificate

$certPwd = ConvertTo-SecureString -String $gatewayCertPfxPassword -AsPlainText -Force
$certPortalPwd = ConvertTo-SecureString -String $portalCertPfxPassword -AsPlainText -Force

# Import the certificates 
$certUploadResult = Import-AzureRmApiManagementHostnameCertificate -ResourceGroupName $resGroupName -Name $apimServiceName -HostnameType "Proxy" -PfxPath $gatewayCertPfxPath -PfxPassword $gatewayCertPfxPassword -PassThru
$certPortalUploadResult = Import-AzureRmApiManagementHostnameCertificate -ResourceGroupName $resGroupName -Name $apimServiceName -HostnameType "Proxy" -PfxPath $portalCertPfxPath -PfxPassword $portalCertPfxPassword -PassThru

# Update the API Managegement host configuration
$proxyHostnameConfig = New-AzureRmApiManagementHostnameConfiguration -CertificateThumbprint $certUploadResult.Thumbprint -Hostname $gatewayHostname
$portalHostnameConfig = New-AzureRmApiManagementHostnameConfiguration -CertificateThumbprint $certPortalUploadResult.Thumbprint -Hostname $portalHostname

# Change the API Managemement host names
$result = Set-AzureRmApiManagementHostnames -Name $apimServiceName -ResourceGroupName $resGroupName –PortalHostnameConfiguration $portalHostnameConfig -ProxyHostnameConfiguration $proxyHostnameConfig

# Create a public IP. Later it will be assiged to the App Gateway
$publicip = New-AzureRmPublicIpAddress -ResourceGroupName $resGroupName -name "publicIP01" -location $location -AllocationMethod Dynamic

# Add App Gateway to the App Gateway subnet
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration -Name "gatewayIP01" -Subnet $appgatewaysubnetdata

# Configure App Gateway frontend ports
$fp01 = New-AzureRmApplicationGatewayFrontendPort -Name "port01"  -Port 443
$fipconfig01 = New-AzureRmApplicationGatewayFrontendIPConfig -Name "frontend1" -PublicIPAddress $publicip

# Configure the App Gateway SSL certificates
$certPwd = ConvertTo-SecureString $gatewayCertPfxPassword -AsPlainText -Force
$cert = New-AzureRmApplicationGatewaySslCertificate -Name "cert01" -CertificateFile $gatewayCertPfxPath -Password $certPwd
$certPortalPwd = ConvertTo-SecureString $portalCertPfxPassword -AsPlainText -Force
$certPortal = New-AzureRmApplicationGatewaySslCertificate -Name "cert02" -CertificateFile $portalCertPfxPath -Password $certPortalPwd

# Configure the App Gateway Listeners
$listener = New-AzureRmApplicationGatewayHttpListener -Name "listener01" -Protocol "Https" -FrontendIPConfiguration $fipconfig01 -FrontendPort $fp01 -SslCertificate $cert -HostName $gatewayHostname -RequireServerNameIndication true
$portalListener = New-AzureRmApplicationGatewayHttpListener -Name "listener02" -Protocol "Https" -FrontendIPConfiguration $fipconfig01 -FrontendPort $fp01 -SslCertificate $certPortal -HostName $portalHostname -RequireServerNameIndication true

# Configure the App Gateway custom probes
$apimprobe = New-AzureRmApplicationGatewayProbeConfig -Name "apimproxyprobe" -Protocol "Https" -HostName $gatewayHostname -Path "/status-0123456789abcdef" -Interval 30 -Timeout 120 -UnhealthyThreshold 8
$apimPortalProbe = New-AzureRmApplicationGatewayProbeConfig -Name "apimportalprobe" -Protocol "Https" -HostName $portalHostname -Path "/signin" -Interval 60 -Timeout 300 -UnhealthyThreshold 8

# Configure the App Gateway Authentication certificate
$authcert = New-AzureRmApplicationGatewayAuthenticationCertificate -Name "whitelistcert1" -CertificateFile $gatewayCertCerPath

# Configure the App Gateway backend settings
$apimPoolSetting = New-AzureRmApplicationGatewayBackendHttpSettings -Name "apimPoolSetting" -Port 443 -Protocol "Https" -CookieBasedAffinity "Disabled" -Probe $apimprobe -AuthenticationCertificates $authcert -RequestTimeout 180
$apimPoolPortalSetting = New-AzureRmApplicationGatewayBackendHttpSettings -Name "apimPoolPortalSetting" -Port 443 -Protocol "Https" -CookieBasedAffinity "Disabled" -Probe $apimPortalProbe -AuthenticationCertificates $authcert -RequestTimeout 180

# Configure the App Gateway backedn address pool
$apimProxyBackendPool = New-AzureRmApplicationGatewayBackendAddressPool -Name "apimbackend" -BackendIPAddresses $apimService.StaticIPs[1] # changed from .PrivateIPAddresses[0]

# Configure the App Gateway rules
$rule01 = New-AzureRmApplicationGatewayRequestRoutingRule -Name "rule1" -RuleType Basic -HttpListener $listener -BackendAddressPool $apimProxyBackendPool -BackendHttpSettings $apimPoolSetting
$rule02 = New-AzureRmApplicationGatewayRequestRoutingRule -Name "rule2" -RuleType Basic -HttpListener $portalListener -BackendAddressPool $apimProxyBackendPool -BackendHttpSettings $apimPoolPortalSetting

# Set the App Gateway in WAF mode
$sku = New-AzureRmApplicationGatewaySku -Name "WAF_Medium" -Tier "WAF" -Capacity 2
$config = New-AzureRmApplicationGatewayWebApplicationFirewallConfiguration -Enabled $true -FirewallMode "Prevention"

# Create the Application Gateway with all the settings including the public IP, SSL certificates, Listeners, backend settings, backend address pool and rules
$appgwName = "apim-app-gw"
$appgw = New-AzureRmApplicationGateway -Name $appgwName -ResourceGroupName $resGroupName -Location $location `
-BackendAddressPools $apimProxyBackendPool `
-BackendHttpSettingsCollection $apimPoolSetting, $apimPoolPortalSetting  `
-FrontendIpConfigurations $fipconfig01 -GatewayIpConfigurations $gipconfig `
-FrontendPorts $fp01 -HttpListeners $listener, $portalListener `
-RequestRoutingRules $rule01, $rule02 `
-Sku $sku -WebApplicationFirewallConfig $config -SslCertificates $cert, $certPortal `
-AuthenticationCertificates $authcert `
-Probes $apimprobe, $apimPortalProbe

