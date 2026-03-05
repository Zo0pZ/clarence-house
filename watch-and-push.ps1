# Auto-commit and push on file changes
# Run this script once and leave it running in the background.
# Any saved change will be committed and pushed to GitHub automatically.

$repoPath = $PSScriptRoot
$debounceSeconds = 3  # Wait this long after last change before committing

Write-Host "Watching for changes in: $repoPath" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Cyan

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repoPath
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Ignore git internals and the script itself
$ignore = @('.git', 'watch-and-push.ps1')

$timer = $null
$pendingChange = $false

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $relativePath = $path.Replace($repoPath + '\', '')

    # Skip ignored paths
    foreach ($ig in $ignore) {
        if ($relativePath.StartsWith($ig)) { return }
    }

    $script:pendingChange = $true
}

Register-ObjectEvent $watcher Changed -Action $action | Out-Null
Register-ObjectEvent $watcher Created -Action $action | Out-Null
Register-ObjectEvent $watcher Deleted -Action $action | Out-Null
Register-ObjectEvent $watcher Renamed -Action $action | Out-Null

while ($true) {
    Start-Sleep -Seconds 1

    if ($pendingChange) {
        # Debounce — wait until no further changes for $debounceSeconds
        Start-Sleep -Seconds $debounceSeconds
        $pendingChange = $false

        Push-Location $repoPath

        $status = git status --porcelain
        if ($status) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
            git add -A
            git commit -m "Auto-save: $timestamp"
            git push origin main

            Write-Host "[$timestamp] Changes pushed to GitHub." -ForegroundColor Green
        }

        Pop-Location
    }
}
