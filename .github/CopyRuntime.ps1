param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [ValidateSet('arm64','x64')]
    [string]
    $Arch = "x64"
) 

$VsInstances = Get-VSSetupInstance

$VsDirectory = $VsInstances[0].InstallationPath

$DefaultRedistFile = Join-Path $VsDirectory "VC" "Auxiliary" "Build" "Microsoft.VCRedistVersion.default.txt"

$ExpectedVersion = (Get-Content -Path $DefaultRedistFile).Trim()

$RuntimeLocation = Join-Path $VsDirectory "VC" "Redist" "MSVC" $ExpectedVersion $Arch

$CrtLocation = Join-Path $RuntimeLocation "*.CRT" -Resolve

if ($CrtLocation.Length -eq 0) {
    throw [System.IO.FileNotFoundException] "$RuntimeLocation CRT folder not resolved"
}

$Copied = Copy-Item -Path "$CrtLocation\*.dll" -Destination $OutputPath -PassThru

if ($Copied.Length -eq 0) {
    throw [System.IO.FileNotFoundException] "$CrtLocation No files copied"
}
