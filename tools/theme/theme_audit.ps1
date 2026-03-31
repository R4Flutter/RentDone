param(
  [string]$Root = "lib"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Root)) {
  Write-Error "Path not found: $Root"
  exit 1
}

$allowList = @("lib/app/app_theme.dart")

$pattern = "Color\(0x|\bColors\."
$workspace = (Get-Location).Path
$workspaceUri = New-Object System.Uri(($workspace.TrimEnd('\\') + '\\'))
$files = Get-ChildItem -Path $Root -Recurse -File -Filter "*.dart"
$violations = @()

foreach ($file in $files) {
  $fileUri = New-Object System.Uri($file.FullName)
  $relative = [System.Uri]::UnescapeDataString($workspaceUri.MakeRelativeUri($fileUri).ToString()).Replace("\\", "/")

  $normalized = $relative -replace '^[.]/', '' -replace '^\.\./', ''
  if (($allowList | Where-Object { $normalized.EndsWith($_) }).Count -gt 0) {
    continue
  }

  $matches = Select-String -Path $file.FullName -Pattern $pattern -CaseSensitive
  foreach ($m in $matches) {
    $violations += [PSCustomObject]@{
      File = $relative
      Line = $m.LineNumber
      Text = $m.Line.Trim()
    }
  }
}

if ($violations.Count -gt 0) {
  Write-Host "Hardcoded color audit failed. Found $($violations.Count) violations:" -ForegroundColor Red
  $violations | ForEach-Object {
    Write-Host ("{0}:{1} -> {2}" -f $_.File, $_.Line, $_.Text)
  }
  exit 2
}

Write-Host "Theme audit passed. No hardcoded colors found outside lib/app/app_theme.dart." -ForegroundColor Green
exit 0
