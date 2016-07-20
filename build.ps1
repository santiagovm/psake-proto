[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$nugetExe
)

cls

# Restore NuGet packages for build to run
Write-Host "Restoring packages needed for Build script to run"
& $nugetExe restore ".\BuildScripts\packages.config" -PackagesDirectory ".\packages"

# '[p]sake' is the same as 'psake' but $Error is not polluted
Write-Host "Importing psake module"
Remove-Module [p]sake

# find psake's path
$psakeModule = (Get-ChildItem(".\packages\psake.*\tools\psake.psm1")).FullName | `
					Sort-Object $_ | `
					Select -Last 1

Import-Module $psakeModule

# running the build script
Write-Host "Running the build script"

Invoke-psake -buildFile .\BuildScripts\default.ps1 `
			 -taskList Test `
			 -framework 4.5.2 `
			 -properties @{ 
			     "buildConfiguration" = "Release" 
			     "buildPlatform" = "Any CPU" } `
			 -parameters @{ 
				 "solutionFile" = "..\psake.sln" 
				 "nugetExe" = $nugetExe }

# propagating the exit code so that builds actually fail when there is a problem
Write-Host "`r`nBuild exit code: " $LASTEXITCODE

Exit $LASTEXITCODE
