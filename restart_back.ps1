Get-Process -Name dotnet -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process -FilePath 'dotnet' -ArgumentList 'run','--no-build','--project','./server/AdminServer/AdminServer.csproj','--cors' -WorkingDirectory 'c:/Users/xbdki/code/chat' -RedirectStandardOutput 'c:/Users/xbdki/code/chat/admin_out.txt' -RedirectStandardError 'c:/Users/xbdki/code/chat/admin_err.txt'
Start-Process -FilePath 'dotnet' -ArgumentList 'run','--no-build','--project','./server/ChatServer/ChatServer.csproj','--cors' -WorkingDirectory 'c:/Users/xbdki/code/chat' -RedirectStandardOutput 'c:/Users/xbdki/code/chat/chat_out.txt' -RedirectStandardError 'c:/Users/xbdki/code/chat/chat_err.txt'
Write-Output 'backends started (no-build)'
