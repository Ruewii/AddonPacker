$addonName      = "addons"                                          # This shouldn't be an existing addon in the root directory (eg; left4dead2/left4dead2_dlc, ...)
$gameDir        = "G:\SteamLibrary\steamapps\common\Left 4 Dead 2"  # Should be absolute path to game's root directory 
$vpkToolPath    = "vpkeditcli.exe"                                  # Make sure it's in the PATH or just use absolute path. Both works.
$MaxThreads     = 8

$addonDir       = "$gameDir\$addonName"
$outputDir      = "$addonDir\pak01_dir"
$sourceDir      = "$gameDir\left4dead2\addons\workshop"
$tempDir        = "$addonDir\temp"

Set-StrictMode -Version Latest

# Remove the directory first
Remove-Item -Path "$gameDir\$addonName" -Recurse -Force -ErrorAction SilentlyContinue

# Recreate the directories
New-Item -ItemType Directory -Path $addonDir -Force
New-Item -ItemType Directory -Path $tempDir -Force
New-Item -ItemType Directory -Path $outputDir -Force

# Then extract each addons from source to temp in parallel
try {
    Get-ChildItem -Path $sourceDir -Filter "*.vpk" | ForEach-Object -Parallel {
        Start-Process -NoNewWindow -Wait -FilePath $using:vpkToolPath -ArgumentList "--extract `/` --output `"$using:tempDir`" `"$($_.FullName)`""
    } -ThrottleLimit $MaxThreads
}
catch {
    Write-Error "Extraction failed: $_"
    Exit
}

Write-Host "Bundling addons."

# Now bundle them into a directory
try {
    Get-ChildItem -Path $tempDir -Directory | ForEach-Object {
        Get-ChildItem -Path $_.FullName | Copy-Item -Recurse -Destination $outputDir -Force
    }
}
catch {
    Write-Error "Bundling Failed: $_"
    Exit
}

# Don't really need these anyway, but later I might just make my own metadata or something
Remove-Item -Path "$outputDir\addons" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$outputDir\addonimage.jpg" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$outputDir\addoninfo.txt" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$outputDir\readme.txt" -Force -ErrorAction SilentlyContinue

Write-Host "Packing into VPK."

# Then use vpkTool to pack them into a single VPK
# "-v 1" is for version 1
# -s is for the source directory, where all the files are

try {
    Start-Process -NoNewWindow -Wait -FilePath $vpkToolPath -ArgumentList "-v 1 -s `"$outputDir`""
    Write-Host "Packing complete. Cleaning up."
    Remove-Item -Path $tempDir -Recurse -Force
    Remove-Item -Path $outputDir -Recurse -Force
    Write-Host "Done."
}
catch {
    Write-Error "Failed to pack resources: $_"
}
