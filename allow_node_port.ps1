New-NetFirewallRule -DisplayName "Allow NodeJS 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
