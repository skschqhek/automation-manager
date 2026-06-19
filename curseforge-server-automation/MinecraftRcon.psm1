function ConvertTo-RconPacket {
  param(
    [int]$RequestId,
    [int]$Type,
    [string]$Body
  )

  $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
  $length = 4 + 4 + $bodyBytes.Length + 2
  $packet = New-Object byte[] (4 + $length)

  [System.BitConverter]::GetBytes($length).CopyTo($packet, 0)
  [System.BitConverter]::GetBytes($RequestId).CopyTo($packet, 4)
  [System.BitConverter]::GetBytes($Type).CopyTo($packet, 8)
  $bodyBytes.CopyTo($packet, 12)
  $packet[$packet.Length - 2] = 0
  $packet[$packet.Length - 1] = 0

  return $packet
}

function Read-RconPacket {
  param([System.Net.Sockets.NetworkStream]$Stream)

  $lengthBuffer = New-Object byte[] 4
  $read = $Stream.Read($lengthBuffer, 0, 4)
  if ($read -ne 4) {
    throw "RCON 응답 길이를 읽지 못했습니다."
  }

  $length = [System.BitConverter]::ToInt32($lengthBuffer, 0)
  $buffer = New-Object byte[] $length
  $offset = 0

  while ($offset -lt $length) {
    $count = $Stream.Read($buffer, $offset, $length - $offset)
    if ($count -le 0) {
      throw "RCON 응답이 중간에 끊겼습니다."
    }
    $offset += $count
  }

  $requestId = [System.BitConverter]::ToInt32($buffer, 0)
  $type = [System.BitConverter]::ToInt32($buffer, 4)
  $bodyLength = [Math]::Max(0, $length - 10)
  $body = [System.Text.Encoding]::UTF8.GetString($buffer, 8, $bodyLength)

  [pscustomobject]@{
    RequestId = $requestId
    Type = $type
    Body = $body
  }
}

function Invoke-MinecraftRcon {
  param(
    [Parameter(Mandatory = $true)][string]$HostName,
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)][string]$Password,
    [Parameter(Mandatory = $true)][string]$Command
  )

  $client = [System.Net.Sockets.TcpClient]::new()
  try {
    $client.Connect($HostName, $Port)
    $stream = $client.GetStream()

    $authPacket = ConvertTo-RconPacket -RequestId 1 -Type 3 -Body $Password
    $stream.Write($authPacket, 0, $authPacket.Length)
    $authResponse = Read-RconPacket -Stream $stream

    if ($authResponse.RequestId -eq -1) {
      throw "RCON 인증에 실패했습니다. 비밀번호를 확인하세요."
    }

    $commandPacket = ConvertTo-RconPacket -RequestId 2 -Type 2 -Body $Command
    $stream.Write($commandPacket, 0, $commandPacket.Length)
    $commandResponse = Read-RconPacket -Stream $stream

    return $commandResponse.Body
  }
  finally {
    if ($client) {
      $client.Close()
    }
  }
}

Export-ModuleMember -Function Invoke-MinecraftRcon
