$WSL_IP = (wsl -d Ubuntu-22.04 -- hostname -I).Trim().Split(" ")[0]
Write-Host "Detected WSL2 IP: $WSL_IP" -ForegroundColor Green

if (-not $WSL_IP) {
    Write-Host "Error: Could not detect WSL2 IP. Is Ubuntu running?" -ForegroundColor Red
    exit
}

Write-Host "Cleaning up old rules..." -ForegroundColor Yellow
netsh interface portproxy delete v4tov4 listenport=8443 listenaddress=0.0.0.0
netsh interface portproxy delete v4tov4 listenport=8443 listenaddress=127.0.0.1

Write-Host "Adding Port Forwarding (Windows localhost:8443 -> WSL $WSL_IP:8443)..." -ForegroundColor Yellow
netsh interface portproxy add v4tov4 listenport=8443 listenaddress=0.0.0.0 connectport=8443 connectaddress=$WSL_IP

Write-Host "Updating Firewall Rules..." -ForegroundColor Yellow
Remove-NetFirewallRule -DisplayName "Jitsi SSL" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Jitsi SSL" -Direction Inbound -LocalPort 8443 -Protocol TCP -Action Allow

Write-Host "------------------------------------------------" -ForegroundColor Green
Write-Host "✅ Network Fix Applied!" -ForegroundColor Green
Write-Host "You can now access: https://localhost:8443" -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor Green
