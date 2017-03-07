# Custom Post Initialization Step from init.ps1.
#
# This script will install the project json smudge filter to the in repo git config.
# Assumes this location is at .git/config
Param(
  [string]$RepoRoot
)

try {
    Push-Location
    Set-Location $RepoRoot

    Write-Host "Installing Project.Json Smudge Filter "-ForegroundColor Magenta 

    # installs filter
    & git config --local include.path ../.gitconfig

    Write-Host "Running Project.Json Smudge Filter on working directory"-ForegroundColor Magenta 

    # runs it on the repo by checking everything out again
    & git stash save
    Remove-Item .git/index -Force
    & git checkout HEAD -- .
    & git stash pop
} finally {
    Pop-Location
}