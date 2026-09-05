$need = @(8080, 8081)
$running = $true
foreach ($p in $need) {
  if (-not (Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue)) {
    $running = $false
  }
}
if ($running) {
  Write-Output 'web server already running on 8080/8081'
} else {
  $pys = @('python', 'py')
  foreach ($py in $pys) {
    try {
      Start-Process -FilePath $py -ArgumentList 'serve_web.py' -WorkingDirectory 'c:/Users/xbdki/code/chat' -RedirectStandardOutput 'c:/Users/xbdki/code/chat/web_out.txt' -RedirectStandardError 'c:/Users/xbdki/code/chat/web_err.txt' -ErrorAction Stop
      Write-Output "web server started with $py"
      break
    } catch {
      Write-Output "cannot start with $py"
    }
  }
}
