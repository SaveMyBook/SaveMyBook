# Render every slide of the decks in the output folder to PNG (build/render/<deck name>/) with the local PowerPoint, for layout review.
# Usage: powershell -ExecutionPolicy Bypass -File tools/render.ps1 [-Width 1600]
# (Kept ASCII-only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI, so CJK folder names would be garbled here.)
param([int]$Width = 1600)
$root = Split-Path $PSScriptRoot -Parent
$decks = Get-ChildItem $root -Recurse -Filter *.pptx | Where-Object { $_.FullName -notmatch '\\(build|node_modules)\\' }
$app = New-Object -ComObject PowerPoint.Application
try {
  foreach ($f in $decks) {
    $out = Join-Path $root ('build\render\' + $f.BaseName)
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    New-Item -ItemType Directory -Force $out | Out-Null
    $deck = $app.Presentations.Open($f.FullName, $true, $false, $false)
    $h = [int]($Width * $deck.PageSetup.SlideHeight / $deck.PageSetup.SlideWidth)
    foreach ($s in $deck.Slides) { $s.Export((Join-Path $out ('{0:D2}.png' -f $s.SlideIndex)), 'PNG', $Width, $h) }
    Write-Output ('{0}: {1} slides' -f $f.BaseName, $deck.Slides.Count)
    $deck.Close()
  }
} finally { $app.Quit() }
