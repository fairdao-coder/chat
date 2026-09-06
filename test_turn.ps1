$ErrorActionPreference = 'Stop'
$hostIp = '47.238.90.232'
$port   = 3478
$user   = 'testuser'
$pass   = 'Ab_153x90000'

function Get-BindingRequest {
    # STUN Binding Request: type=0x0001, length=0, magic=0x2112A442, tid=random
    $tid = New-Object byte[] 12
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($tid)
    $msg = [byte[]]::new(20)
    $msg[0] = 0x00; $msg[1] = 0x01          # Binding Request
    $msg[2] = 0x00; $msg[3] = 0x00          # length 0
    $magic = 0x2112A442
    $msg[4] = ($magic -shr 24) -band 0xFF
    $msg[5] = ($magic -shr 16) -band 0xFF
    $msg[6] = ($magic -shr 8)  -band 0xFF
    $msg[7] = $magic -band 0xFF
    [Array]::Copy($tid, 0, $msg, 8, 12)
    ,$msg
}

function Get-TurnAllocateRequest {
    param($username, $password, $tid)
    # Attributes:
    #  REQUESTED-TRANSPORT (0x0019) xor-relay UDP: value=0x11000000
    #  USERNAME (0x0006)
    #  MESSAGE-INTEGRITY (0x0008)  HMAC-SHA1 over (msg + key)  key=MD5(user:realm:pass)
    #  Realm needed for long-term creds -> first do Allocation without MI to get REALM (401),
    #  then retry. We implement the 401-retry here.
    # Build allocate request with username + requested-transport, no MI first.
    $attrs = [System.Collections.Generic.List[byte]]::new()

    # REQUESTED-TRANSPORT
    $rt = [byte[]]::new(8)
    $rt[0]=0x00; $rt[1]=0x19          # type
    $rt[2]=0x00; $rt[3]=0x04          # len 4
    $rt[4]=0x11; $rt[5]=0x00; $rt[6]=0x00; $rt[7]=0x00
    $attrs.AddRange($rt)

    # USERNAME (must be 4-byte aligned with padding)
    $ub = [System.Text.Encoding]::UTF8.GetBytes($username)
    $pad = ((4 - ($ub.Length % 4)) % 4)
    $ublock = [byte[]]::new(4 + $ub.Length + $pad)
    $ublock[0]=0x00; $ublock[1]=0x06
    $ublock[2]=[byte](($ub.Length -shr 8) -band 0xFF); $ublock[3]=[byte]($ub.Length -band 0xFF)
    [Array]::Copy($ub,0,$ublock,4,$ub.Length)
    $attrs.AddRange($ublock)

    $bodyLen = $attrs.Count
    $msg = [byte[]]::new(20 + $bodyLen + 24)  # reserve 24 for MI + padding
    $msg[0]=0x00; $msg[1]=0x03            # Allocate Request
    $msg[2]=[byte](($bodyLen -shr 8) -band 0xFF); $msg[3]=[byte]($bodyLen -band 0xFF)
    $magic = 0x2112A442
    $msg[4]=[byte](($magic -shr 24) -band 0xFF); $msg[5]=[byte](($magic -shr 16) -band 0xFF)
    $msg[6]=[byte](($magic -shr 8) -band 0xFF); $msg[7]=[byte]($magic -band 0xFF)
    [Array]::Copy($tid,0,$msg,8,12)
    [Array]::Copy($attrs.ToArray(),0,$msg,20,$bodyLen)

    # MESSAGE-INTEGRITY placeholder (added by caller after we know realm); return body for now
    ,$msg
}

function Compute-MI {
    param($msgNoMi, $username, $realm, $password)
    # key = MD5("user:realm:password")
    $md5 = [Security.Cryptography.MD5]::Create()
    $keyStr = "$username`:$realm`:$password"
    $key = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($keyStr))
    # HMAC-SHA1 over msgNoMi (which must have MI attribute slot zeroed, length excluded)
    $hmac = New-Object Security.Cryptography.HMACSHA1(,$key)
    # The data to HMAC is the message up to (but excluding) the MESSAGE-INTEGRITY attribute,
    # with the message length field set to include only up-to MI.
    # We'll compute over msgNoMi's first (20+bodyLen) bytes but with length field adjusted.
    $lenField = ($msgNoMi[2] -shl 8) -bor $msgNoMi[3]
    $dataLen = 20 + $lenField
    $data = [byte[]]::new($dataLen)
    [Array]::Copy($msgNoMi,0,$data,0,$dataLen)
    $hash = $hmac.ComputeHash($data)
    ,$hash
}

function Parse-StunAttributes {
    param($resp)
    $results = @{}
    $len = ($resp[2] -shl 8) -bor $resp[3]
    $pos = 20
    while ($pos -lt (20 + $len)) {
        $type = ($resp[$pos] -shl 8) -bor $resp[$pos+1]
        $alen = ($resp[$pos+2] -shl 8) -bor $resp[$pos+3]
        $val = $resp[($pos+4)..($pos+4+$alen-1)]
        if ($type -eq 0x0009) { # ERROR-CODE
            $code = ($val[2] -shr 4)*100 + ($val[3])
            $results['ERROR_CODE'] = $code
        } elseif ($type -eq 0x0014) { # REALM
            $results['REALM'] = [System.Text.Encoding]::UTF8.GetString($val)
        } elseif ($type -eq 0x0020) { # XOR-RELAYED-ADDRESS (relay assigned)
            $results['RELAY'] = 'allocated'
        } elseif ($type -eq 0x000C) { # XOR-MAPPED-ADDRESS
            $results['XORMAPPED'] = 'ok'
        }
        $pos += 4 + $alen + ((4 - ($alen % 4)) % 4)
    }
    ,$results
}

Write-Host "=== 1. STUN Binding (UDP $hostIp`:$port) ==="
try {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.Client.ReceiveTimeout = 4000
    $udp.Connect($hostIp, $port)
    $tid = New-Object byte[] 12; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($tid)
    $breq = Get-BindingRequest
    $udp.Send($breq, $breq.Length) | Out-Null
    $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
    $r = $udp.Receive([ref]$remote)
    $class = ($r[0] -shr 4) -band 0x1
    Write-Host "UDP Binding reply received ($([System.Text.Encoding]::ASCII.GetString($r,0,[Math]::Min(4,$r.Length)))) -> class=$class (2=success)"
    $udp.Close()
} catch {
    Write-Host "UDP Binding FAILED: $_"
}

Write-Host "=== 2. TURN Allocate (LONG-TERM creds) ==="
try {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.Client.ReceiveTimeout = 5000
    $udp.Connect($hostIp, $port)
    $tid = New-Object byte[] 12; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($tid)

    # Step A: Allocate without MI -> expect 401 + REALM
    $msgA = Get-TurnAllocateRequest -username $user -password $pass -tid $tid
    $udp.Send($msgA, $msgA.Length) | Out-Null
    $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
    $rA = $udp.Receive([ref]$remote)
    $pA = Parse-StunAttributes $rA
    if ($pA['REALM']) {
        Write-Host "Got REALM = $($pA['REALM']) (expected 401 challenge)"
        $realm = $pA['REALM']

        # Step B: rebuild with USERNAME + REALM + MI, resend same tid
        # Build full message with MI attribute (20-byte attr)
        $attrs = [System.Collections.Generic.List[byte]]::new()
        # REQUESTED-TRANSPORT
        $attrs.AddRange(@(0x00,0x19,0x00,0x04,0x11,0x00,0x00,0x00))
        # USERNAME
        $ub = [System.Text.Encoding]::UTF8.GetBytes($user)
        $ublock = [byte[]]::new(4 + $ub.Length)
        $ublock[0]=0x00; $ublock[1]=0x06; $ublock[2]=[byte](($ub.Length -shr 8) -band 0xFF); $ublock[3]=[byte]($ub.Length -band 0xFF)
        [Array]::Copy($ub,0,$ublock,4,$ub.Length)
        $attrs.AddRange($ublock)
        # REALM
        $rb = [System.Text.Encoding]::UTF8.GetBytes($realm)
        $rblock = [byte[]]::new(4 + $rb.Length)
        $rblock[0]=0x00; $rblock[1]=0x14; $rblock[2]=[byte](($rb.Length -shr 8) -band 0xFF); $rblock[3]=[byte]($rb.Length -band 0xFF)
        [Array]::Copy($rb,0,$rblock,4,$rb.Length)
        $attrs.AddRange($rblock)
        # MESSAGE-INTEGRITY placeholder (20 bytes)
        $miBlock = [byte[]]::new(4 + 20)
        $miBlock[0]=0x00; $miBlock[1]=0x08; $miBlock[2]=0x00; $miBlock[3]=0x14

        $bodyLen = $attrs.Count + $miBlock.Length
        $msgB = [byte[]]::new(20 + $bodyLen)
        $msgB[0]=0x00; $msgB[1]=0x03
        $msgB[2]=[byte](($bodyLen -shr 8) -band 0xFF); $msgB[3]=[byte]($bodyLen -band 0xFF)
        $magic = 0x2112A442
        $msgB[4]=[byte](($magic -shr 24) -band 0xFF); $msgB[5]=[byte](($magic -shr 16) -band 0xFF); $msgB[6]=[byte](($magic -shr 8) -band 0xFF); $msgB[7]=[byte]($magic -band 0xFF)
        [Array]::Copy($tid,0,$msgB,8,12)
        [Array]::Copy($attrs.ToArray(),0,$msgB,20,$attrs.Count)
        [Array]::Copy($miBlock,0,$msgB,20+$attrs.Count,$miBlock.Length)

        # compute MI over msgB with length=bodyLen (excludes MI) and MI slot zeroed
        $lenForHmac = 20 + $attrs.Count
        $msgB[2]=[byte](($lenForHmac -shr 8) -band 0xFF); $msgB[3]=[byte]($lenForHmac -band 0xFF)
        # zero the MI attribute region (already zero from new, but ensure)
        for ($i=20+$attrs.Count; $i -lt $msgB.Length; $i++) { $msgB[$i]=0 }
        $hmac = New-Object Security.Cryptography.HMACSHA1 -ArgumentList @(,(New-Object Security.Cryptography.MD5).ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$user`:$realm`:$pass")))
        $hash = $hmac.ComputeHash($msgB,0,$lenForHmac)
        [Array]::Copy($hash,0,$msgB,20+$attrs.Count+4,20)
        # restore full length
        $msgB[2]=[byte](($bodyLen -shr 8) -band 0xFF); $msgB[3]=[byte]($bodyLen -band 0xFF)

        $udp.Send($msgB, $msgB.Length) | Out-Null
        $rB = $udp.Receive([ref]$remote)
        $pB = Parse-StunAttributes $rB
        if ($pB['RELAY']) {
            Write-Host "SUCCESS: TURN relay allocated (creds valid). Username/password OK."
        } elseif ($pB['ERROR_CODE']) {
            Write-Host "Allocate failed with ERROR-CODE $($pB['ERROR_CODE']) (creds likely invalid or rejected)"
        } else {
            Write-Host "Allocate reply received but no relay address; attrs=$(($pB.Keys) -join ',')"
        }
    } else {
        Write-Host "No REALM in reply; attrs=$(($pA.Keys) -join ',') (server may not support TURN or rejected)"
    }
    $udp.Close()
} catch {
    Write-Host "TURN Allocate FAILED: $_"
}
