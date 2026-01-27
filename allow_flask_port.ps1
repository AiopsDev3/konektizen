New-NetFirewallRule -DisplayName "Allow Flask 5000" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
