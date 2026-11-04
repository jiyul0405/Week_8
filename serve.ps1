# 같은 Wi-Fi의 핸드폰에서 게임을 테스트하기 위한 간단한 로컬 서버
# 실행: powershell -ExecutionPolicy Bypass -File serve.ps1   (종료: Ctrl+C)
param([int]$Port = 8080)

$root = $PSScriptRoot
$types = @{ '.html' = 'text/html; charset=utf-8'; '.png' = 'image/png'; '.jpg' = 'image/jpeg';
            '.js' = 'application/javascript'; '.css' = 'text/css'; '.json' = 'application/json' }

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169\.254)' } |
       Select-Object -First 1).IPAddress
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
$listener.Start()
Write-Host ""
Write-Host "  핸드폰에서 (같은 Wi-Fi):"
Write-Host "    수박 버전: http://${ip}:$Port/index.html"
Write-Host "    동물 버전: http://${ip}:$Port/animal.html"
Write-Host "  이 PC에서: http://localhost:$Port/"
Write-Host "  종료: Ctrl+C"
Write-Host ""

function Send($stream, $status, $type, [byte[]]$body) {
  $head = "HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
  $h = [Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($h, 0, $h.Length)
  $stream.Write($body, 0, $body.Length)
}

try {
  while ($true) {
    if (-not $listener.Pending()) { Start-Sleep -Milliseconds 30; continue }  # Ctrl+C가 먹히도록 대기
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = New-Object System.IO.StreamReader($stream)
      $line = $reader.ReadLine()
      if (-not $line) { continue }
      $path = [Uri]::UnescapeDataString(($line -split ' ')[1].Split('?')[0]).TrimStart('/')
      if ($path -eq '') { $path = 'index.html' }
      $file = [IO.Path]::GetFullPath((Join-Path $root $path))
      if ($file.StartsWith($root) -and (Test-Path $file -PathType Leaf)) {
        $ext = [IO.Path]::GetExtension($file).ToLower()
        $type = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
        Send $stream '200 OK' $type ([IO.File]::ReadAllBytes($file))
        Write-Host "200 $path"
      } else {
        Send $stream '404 Not Found' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('Not found'))
        Write-Host "404 $path"
      }
    } catch { } finally { $client.Close() }
  }
} finally { $listener.Stop() }
