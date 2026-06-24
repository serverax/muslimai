<#
  Minimal static file server for Flutter web build output (Phase 6D fallback).
  Used when Node/npx is unavailable. Binds localhost + 127.0.0.1 on the given port.
#>
param(
  [Parameter(Mandatory = $true)][string]$Root,
  [Parameter(Mandatory = $true)][int]$Port
)

$ErrorActionPreference = "Stop"
$rootFull = (Resolve-Path $Root).Path.TrimEnd('\')
$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif'  = 'image/gif'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.wasm' = 'application/wasm'
  '.map'  = 'application/json; charset=utf-8'
  '.woff' = 'font/woff'
  '.woff2'= 'font/woff2'
  '.ttf'  = 'font/ttf'
}

function Get-ContentType([string]$path) {
  $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
  if ($mime.ContainsKey($ext)) { return $mime[$ext] }
  return 'application/octet-stream'
}

$listener = New-Object System.Net.HttpListener
foreach ($bindHost in @('localhost', '127.0.0.1')) {
  $listener.Prefixes.Add("http://${bindHost}:$Port/")
}
$listener.Start()
Write-Host "Sakina static web server: http://localhost:$Port/ (root: $rootFull)"

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.LocalPath).TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'index.html' }
    $candidate = Join-Path $rootFull ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $candidate -PathType Leaf)) {
      $candidate = Join-Path $rootFull 'index.html'
    }
    if (-not (Test-Path $candidate -PathType Leaf)) {
      $ctx.Response.StatusCode = 404
      $bytes = [Text.Encoding]::UTF8.GetBytes('404 Not Found')
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $bytes = [IO.File]::ReadAllBytes($candidate)
      $ctx.Response.StatusCode = 200
      $ctx.Response.ContentType = Get-ContentType $candidate
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
  } catch {
    $ctx.Response.StatusCode = 500
  } finally {
    $ctx.Response.OutputStream.Close()
  }
}
