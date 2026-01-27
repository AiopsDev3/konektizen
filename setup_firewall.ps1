New-NetFirewallRule -DisplayName "Allow Node Port 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
