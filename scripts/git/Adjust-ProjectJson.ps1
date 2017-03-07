Param(
  [string]$FileName,
  
  [Parameter(ParameterSetName='smudge')]
  [switch]$smudge,

  [Parameter(ParameterSetName='clean')]
  [switch]$clean
)

$PackageVersionToUse = "*"

if ($smudge) {
  $GitBranchName = & git.exe name-rev --name-only HEAD

  if ($GitBranchName -eq "master") {
    # easy mode. Don't touch it
    return 0;
  }

  $GitTag = & git.exe describe --abbrev=0 --tags master
  $VersionRegex = '^v?(?<MAJOR>\d+)\.(?<MINOR>\d+)\.(?<PATCH>\d+)(?:\-(?<LABEL>[\dA-Za-z\-\.]+))?$|^(?<LABEL>[\dA-Za-z\-\.]+)\-v?(?<MAJOR>\d+)\.(?<MINOR>\d+)\.(?<PATCH>\d+)$'

  $GitTagMajor = [regex]::Match($GitTag, $VersionRegex).Groups['MAJOR'].Value
  $GitTagMinor = [regex]::Match($GitTag, $VersionRegex).Groups['MINOR'].Value
  $GitTagPatch = [regex]::Match($GitTag, $VersionRegex).Groups['PATCH'].Value

  # Up the patch version by 1 for new candidate release.
  $GitTagPatch = [int64]$GitTagPatch + 1

  $PackageVersionToUse = "$GitTagMajor.$GitTagMinor.$GitTagPatch-*"
}

Write-Host $FileName
$projectJson = (Get-Content $FileName | ConvertFrom-Json)

$projectjson.dependencies.PSObject.Properties | Where-Object { $_.Name -like "WinObjC.*" } | ForEach-Object { $_.Value = $PackageVersionToUse }

ConvertTo-Json $projectjson | set-content $FileName
