# OpenLeaf HTTPS Setup - Certificate Generation Script
# Run this script with Git Bash on Windows to generate all required certificates

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " OpenLeaf HTTPS Certificate Generator" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if OpenSSL is available
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    Write-Host "❌ OpenSSL not found!" -ForegroundColor Red
    Write-Host "Please install OpenSSL or use Git Bash which includes OpenSSL" -ForegroundColor Yellow
    Write-Host "Run this script in Git Bash instead: bash generate-certificates.sh" -ForegroundColor Yellow
    exit 1
}

# Create certs directory if it doesn't exist
$certsDir = "certs"
if (-not (Test-Path $certsDir)) {
    Write-Host "📁 Creating certs directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $certsDir | Out-Null
}

Set-Location $certsDir

Write-Host "🔐 Step 1: Generating Root CA Certificate..." -ForegroundColor Green
Write-Host ""

# Generate Root CA
if (-not (Test-Path "rootCA.key")) {
    & openssl genrsa -out rootCA.key 4096 2>&1 | Out-Null
    Write-Host "  ✅ Root CA private key generated" -ForegroundColor Green
} else {
    Write-Host "  ⏭️  Root CA key already exists, skipping..." -ForegroundColor Yellow
}

if (-not (Test-Path "rootCA.crt")) {
    & openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.crt -subj "/C=NL/ST=Noord-Brabant/L=Eindhoven/O=OpenLeaf/OU=Development/CN=OpenLeaf Root CA" 2>&1 | Out-Null
    Write-Host "  ✅ Root CA certificate generated (valid for 10 years)" -ForegroundColor Green
} else {
    Write-Host "  ⏭️  Root CA certificate already exists, skipping..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🔐 Step 2: Generating API Gateway Certificate..." -ForegroundColor Green
Write-Host ""

# Create API Gateway config file
@"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=NL
ST=Noord-Brabant
L=Eindhoven
O=OpenLeaf
OU=Development
CN=localhost

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = api-gateway
DNS.3 = *.localhost
IP.1 = 127.0.0.1
"@ | Out-File -FilePath "api-gateway.conf" -Encoding ASCII

# Generate API Gateway certificates
& openssl genrsa -out api-gateway.key 2048 2>&1 | Out-Null
Write-Host "  ✅ API Gateway private key generated" -ForegroundColor Green

& openssl req -new -key api-gateway.key -out api-gateway.csr -config api-gateway.conf 2>&1 | Out-Null
Write-Host "  ✅ Certificate signing request created" -ForegroundColor Green

& openssl x509 -req -in api-gateway.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out api-gateway.crt -days 825 -sha256 -extfile api-gateway.conf -extensions v3_req 2>&1 | Out-Null
Write-Host "  ✅ Certificate signed by Root CA" -ForegroundColor Green

& openssl pkcs12 -export -in api-gateway.crt -inkey api-gateway.key -out api-gateway.p12 -name api-gateway -passout pass:changeit 2>&1 | Out-Null
Write-Host "  ✅ PKCS12 keystore created for Spring Boot" -ForegroundColor Green

Write-Host ""
Write-Host "🔐 Step 3: Generating Keycloak Certificate..." -ForegroundColor Green
Write-Host ""

# Create Keycloak config file
@"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=NL
ST=Noord-Brabant
L=Eindhoven
O=OpenLeaf
OU=Development
CN=localhost

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = keycloak
DNS.3 = *.localhost
IP.1 = 127.0.0.1
"@ | Out-File -FilePath "keycloak.conf" -Encoding ASCII

# Generate Keycloak certificates
& openssl genrsa -out keycloak.key 2048 2>&1 | Out-Null
Write-Host "  ✅ Keycloak private key generated" -ForegroundColor Green

& openssl req -new -key keycloak.key -out keycloak.csr -config keycloak.conf 2>&1 | Out-Null
Write-Host "  ✅ Certificate signing request created" -ForegroundColor Green

& openssl x509 -req -in keycloak.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out keycloak.crt -days 825 -sha256 -extfile keycloak.conf -extensions v3_req 2>&1 | Out-Null
Write-Host "  ✅ Certificate signed by Root CA" -ForegroundColor Green

& openssl pkcs12 -export -in keycloak.crt -inkey keycloak.key -out keycloak.p12 -name keycloak -passout pass:changeit 2>&1 | Out-Null
Write-Host "  ✅ PKCS12 keystore created for Keycloak" -ForegroundColor Green

Write-Host ""
Write-Host "🔐 Step 4: Generating Frontend Certificate..." -ForegroundColor Green
Write-Host ""

# Generate Frontend certificates (using same config as API Gateway)
& openssl genrsa -out frontend.key 2048 2>&1 | Out-Null
Write-Host "  ✅ Frontend private key generated" -ForegroundColor Green

& openssl req -new -key frontend.key -out frontend.csr -config api-gateway.conf 2>&1 | Out-Null
Write-Host "  ✅ Certificate signing request created" -ForegroundColor Green

& openssl x509 -req -in frontend.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out frontend.crt -days 825 -sha256 -extfile api-gateway.conf -extensions v3_req 2>&1 | Out-Null
Write-Host "  ✅ Certificate signed by Root CA" -ForegroundColor Green

Write-Host ""
Write-Host "🔐 Step 5: Creating Java Truststore..." -ForegroundColor Green
Write-Host ""

# Create truststore for Java services
if (Get-Command keytool -ErrorAction SilentlyContinue) {
    & keytool -import -trustcacerts -alias openleaf-ca -file rootCA.crt -keystore truststore.jks -storepass changeit -noprompt 2>&1 | Out-Null
    Write-Host "  ✅ Java truststore created" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  keytool not found - skipping truststore creation" -ForegroundColor Yellow
    Write-Host "     This is optional if you trust certificates system-wide" -ForegroundColor Gray
}

Set-Location ..

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " ✅ Certificate Generation Complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Generated Files in ./certs/:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Root CA:" -ForegroundColor White
Write-Host "    • rootCA.crt (to be trusted system-wide)" -ForegroundColor Gray
Write-Host "    • rootCA.key (keep secure!)" -ForegroundColor Gray
Write-Host ""
Write-Host "  API Gateway:" -ForegroundColor White
Write-Host "    • api-gateway.p12 (for Spring Boot)" -ForegroundColor Gray
Write-Host "    • api-gateway.crt & .key" -ForegroundColor Gray
Write-Host ""
Write-Host "  Keycloak:" -ForegroundColor White
Write-Host "    • keycloak.crt & .key (for Docker)" -ForegroundColor Gray
Write-Host "    • keycloak.p12 (alternative format)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Frontend:" -ForegroundColor White
Write-Host "    • frontend.crt & .key (for Vite)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Java Services:" -ForegroundColor White
Write-Host "    • truststore.jks (optional)" -ForegroundColor Gray
Write-Host ""
Write-Host "📖 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Trust the Root CA certificate:" -ForegroundColor White
Write-Host "   Windows: certutil -addstore -f `"ROOT`" certs\rootCA.crt" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Copy certificates to services:" -ForegroundColor White
Write-Host "   • API Gateway: copy certs\api-gateway.p12 to src\main\resources\certs\" -ForegroundColor Gray
Write-Host "   • Frontend: certificates already in ./certs/ (referenced by vite.config.js)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Update configuration files as per HTTPS_IMPLEMENTATION_GUIDE.md" -ForegroundColor White
Write-Host ""
Write-Host "4. Start services and test HTTPS connections!" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  Security Note: These certificates are for LOCAL DEVELOPMENT ONLY" -ForegroundColor Yellow
Write-Host "    Never use self-signed certificates in production!" -ForegroundColor Yellow
Write-Host ""