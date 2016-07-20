cls

# Restore NuGet packages
# SANTI: MAKE THIS A PARAMETER
$nugetExe = "D:\Santi\soft-lib\NuGet-3\nuget.exe"

# restoring psake package if missing
& $nugetExe restore ".\Build\packages.config" -PackagesDirectory ".\packages"

# '[p]sake' is the same as 'psake' but $Error is not polluted
Remove-Module [p]sake

# find psake's path
$psakeModule = (Get-ChildItem(".\packages\psake.*\tools\psake.psm1")).FullName | `
					Sort-Object $_ | `
					Select -Last 1

Import-Module $psakeModule

Invoke-psake -buildFile .\Build\default.ps1 `
			 -taskList Test `
			 -framework 4.5.2 `
			 -properties @{ 
			     "buildConfiguration" = "Release" 
			     "buildPlatform" = "Any CPU" } `
			 -parameters @{ "solutionFile" = "..\psake.sln" }

Write-Host "`r`nBuild exit code: " $LASTEXITCODE

# propagating the exit code so that builds actually fail when there is a problem
Exit $LASTEXITCODE
