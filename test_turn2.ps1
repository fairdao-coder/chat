$ErrorActionPreference = 'Stop'
$hostIp = '47.238.90.232'
$port   = 3478
$user   = 'testuser'
$pass   = 'Ab_153x90000'
$realm  = 'i8i8.ru'

function Align4($len) { return $len + ((4 - ($len % 4)) % 4) }

# Build Allocate request with REQUESTED-TRANSPORT, USERNAME, REALM, MESSAGE-INTEGRITY
$reqTransport = [byte[]]@(0x00,0x19,0x00,0x04, 0x11,0x00,0x00,0x00)

$ub = [System.Text.Encoding]::UTF8.GetBytes($user)
$ualen = Align4 $ub.Length
$uBlock = [byte[]]::new(4 + $ualen)
$uBlock[0]=0x00; $uBlock[1]=0x06
$uBlock[2]=[byte](($ub.Length -shr 8) -band 0xFF); $uBlock[3]=[byte]($ub.Length -band 0xFF)
[Array]::Copy($ub,0,$uBlock,4,$ub.Length)

$rb = [System.Text.Encoding]::UTF8.GetBytes($realm)
$ralen = Align4 $rb.Length
$rBlock = [byte[]]::new(4 + $ralen)
$rBlock[0]=0x00; $rBlock[1]=0x14
$rBlock[2]=[byte](($rb.Length -shr 8) -band 0xFF); $rBlock[3]=[byte]($rb.Length -band 0xFF)
[Array]::Copy($rb,0,$rBlock,4,$rb.Length)

$miBlock = [byte[]]@(0x00,0x08,0x00,0x14, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)

$bodyLen = $reqTransport.Length + $uBlock.Length + $rBlock.Length + $miBlock.Length
$msg = [byte[]]::new(20 + $bodyLen)
$msg[0]=0x00; $msg[1]=0x03   # Allocate Request
$magic = 0x2112A442
$msg[2]=[byte](($bodyLen -shr 8) -band 0xFF); $msg[3]=[byte]($bodyLen -band 0xFF)
$msg[4]=[byte](($magic -shr 24) -band 0xFF); $msg[5]=[byte](($magic -shr 16) -band 0xFF)
$msg[6]=[byte](($magic -shr 8) -band 0xFF); $msg[7]=[byte]($magic -band 0xFF)
$tid = New-Object byte[] 12; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($tid)
[Array]::Copy($tid,0,$msg,8,12)
[Array]::Copy($reqTransport,0,$msg,20,$reqTransport.Length)
[Array]::Copy($uBlock,0,$msg,20+$reqTransport.Length,$uBlock.Length)
[Array]::Copy($rBlock,0,$msg,20+$reqTransport.Length+$uBlock.Length,$rBlock.Length)
[Array]::Copy($miBlock,0,$msg,20+$reqTransport.Length+$uBlock.Length+$rBlock.Length,$miBlock.Length)

# Compute MESSAGE-INTEGRITY: HMAC-SHA1 over msg[0 .. 20+bodyLen-MIlen) with length field = that size
$lenForHmac = 20 + $reqTransport.Length + $uBlock.Length + $rBlock.Length
$msg[2]=[byte](($lenForHmac -shr 8) -band 0xFF); $msg[3]=[byte]($lenForHmac -band 0xFF)
for ($i=$lenForHmac; $i -lt $msg.Length; $i++) { $msg[$i]=0 }
$key = [Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$user`:$realm`:$pass"))
$hmac = New-Object Security.Cryptography.HMACSHA1 -ArgumentList @(,$key)
$hash = $hmac.ComputeHash($msg,0,$lenForHmac)
[Array]::Copy($hash,0,$msg,20+$reqTransport.Length+$uBlock.Length+$rBlock.Length+4,20)
# restore full length
$msg[2]=[byte](($bodyLen -shr 8) -band 0xFF); $msg[3]=[byte]($bodyLen -band 0xFF)

Write-Host "=== TURN Allocate (realm=$realm, user=$user) ==="
try {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.Client.ReceiveTimeout = 6000
    $udp.Connect($hostIp, $port)
    $udp.Send($msg, $msg.Length) | Out-Null
    $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
    $r = $udp.Receive([ref]$remote)
    $class = ($r[0] -shr 4) -band 0x1   # 2=success, 3=failure
    $type = ($r[0] -band 0xF) -shl 8 -bor $r[1]
    Write-Host "Reply class=$class type=0x$($type.ToString('X4'))"
    $len = ($r[2] -shl 8) -bor $r[3]
    $pos = 20
    while ($pos -lt (20 + $len)) {
        $at = ($r[$pos] -shl 8) -bor $r[$pos+1]
        $al = ($r[$pos+2] -shl 8) -bor $r[$pos+3]
        if ($at -eq 0x0009) {
            $ec = ($r[$pos+4+2] -shr 4)*100 + $r[$pos+4+3]
            $etxt = [System.Text.Encoding]::ASCII.GetString($r[($pos+4+4)..($pos+4+$al-1)])
            Write-Host "  ERROR-CODE: $ec $etxt"
        } elseif ($at -eq 0x0020) {
            Write-Host "  XOR-RELAYED-ADDRESS: relay allocated (TURN relay WORKING)"
        } elseif ($at -eq 0x000C) {
            Write-Host "  XOR-MAPPED-ADDRESS present"
        } elseif ($at -eq 0x0014) {
            Write-Host "  REALM: $([System.Text.Encoding]::UTF8.GetString($r[($pos+4)..($pos+4+$al-1)]))"
        } elseif ($at -eq 0x000D) {
            Write-Host "  LIFETIME: present"
        } elseif ($at -eq 0x000F) {
            Write-Host "  XOR-PEER-ADDRESS: present"
        } else {
            Write-Host "  ATTR 0x$($at.ToString('X4')) len=$al"
        }
        $pos += 4 + $al + ((4 - ($al % 4)) % 4)
    }
    if ($class -eq 2) { Write-Host "RESULT: SUCCESS - TURN credentials VALID, relay allocated" }
    else { Write-Host "RESULT: FAILED - server rejected (see ERROR-CODE above)" }
    $udp.Close()
} catch {
    Write-Host "RESULT: TIMEOUT/NO REPLY - server did not respond to Allocate (creds/realm rejected or TURN disabled)"
    Write-Host "  detail: $_"
}
