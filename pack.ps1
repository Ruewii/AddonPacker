# Define Variables
$AddonName      = "addons"                                          # This shouldn't be an existing addon in the root directory (eg; left4dead2/left4dead2_dlc, ...)
$GameDir        = "G:\SteamLibrary\steamapps\common\Left 4 Dead 2"  # Should be absolute path to game's root directory 
$VPKToolPath    = "vpkeditcli.exe"                                  # Make sure it's in the PATH or just use absolute path. Both works.
$MaxThreads     = 8                                                 # Threads to use for processing

$addonDir       = "$GameDir\$AddonName"
$outputDir      = "$addonDir\pak01_dir"
$sourceDir      = "$GameDir\left4dead2\addons\workshop"
$tempDir        = "$addonDir\temp"

# Absolutely recommend using Powershell 7+
# I use multithreading here that does not exist in traditional Powershell 5 or below
Set-StrictMode -Version Latest

# Remove the directory first
Remove-Item -Path "$GameDir\$AddonName" -Recurse -Force -ErrorAction SilentlyContinue

# Recreate the directories
New-Item -ItemType Directory -Path $addonDir -Force
New-Item -ItemType Directory -Path $tempDir -Force
New-Item -ItemType Directory -Path $outputDir -Force

# Then extract each addons from source to temp in parallel
try {
    Get-ChildItem -Path $sourceDir -Filter "*.vpk" | ForEach-Object -Parallel {
        Start-Process -NoNewWindow -Wait -FilePath $using:VPKToolPath -ArgumentList "--extract `/` --output `"$using:tempDir`" `"$($_.FullName)`""
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
    Start-Process -NoNewWindow -Wait -FilePath $VPKToolPath -ArgumentList "-v 1 -s `"$outputDir`""
    Write-Host "Packing complete. Cleaning up."
    Remove-Item -Path $tempDir -Recurse -Force
    Remove-Item -Path $outputDir -Recurse -Force
    Write-Host "Done."
}
catch {
    Write-Error "Failed to pack resources: $_"
}

Write-Host @"
Now, modify your gameinfo.txt to include the packed addon name ($AddonName).

Example:
    {
        Game 				addons
        Game				update
        Game				left4dead2_dlc3
        Game				left4dead2_dlc2
        Game				left4dead2_dlc1
        Game				|gameinfo_path|.
        Game				hl2
    }
"@
