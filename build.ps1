param(
	[String]$nugetExe,
	[Int32]$buildNumber=0,
	[String]$branchName="localBuild",
	[String]$gitCommitHash="unknownHash",
	[Switch]$isMainBranch=$False,
	[String]$nugetSource=""
)

cls

# Restore NuGet packages for build to run
Write-Host "Restoring packages needed for Build script to run"

Write-Host "NuGetExe: [$nugetExe]"
Write-Host "NuGetSource: [$nugetSource]"

if ($nugetSource -eq "")
{
	& $nugetExe restore ".\BuildScripts\packages.config" -PackagesDirectory ".\packages" -NonInteractive
}
else
{
	& $nugetExe restore ".\BuildScripts\packages.config" -PackagesDirectory ".\packages" -NonInteractive -Source $nugetSource
}

# '[p]sake' is the same as 'psake' but $Error is not polluted
Write-Host "Importing psake module"
Remove-Module [p]sake

# find psake's path
$psakeModule = (Get-ChildItem(".\packages\psake*\tools\psake.psm1")).FullName | `
					Sort-Object $_ | `
					Select -Last 1

$psakeScript = (Get-ChildItem(".\packages\EG.BuildScripts*\tools\default.ps1")).FullName | `
					Sort-Object $_ | `
					Select -Last 1

Import-Module $psakeModule

# running the build script
Write-Host "Running the build script"

Invoke-psake -buildFile $psakeScript `
			 -taskList Clean `
			 -framework 4.5.2 `
			 -properties @{ 
			     "buildConfiguration" = "Release" 
			     "buildPlatform" = "Any CPU" } `
			 -parameters @{ 
				 "solutionFile" = Resolve-Path(".\psake.sln") 
				 "nugetExe" = $nugetExe
				 "buildNumber" = $buildNumber
				 "branchName" = $branchName
				 "gitCommitHash" = $gitCommitHash
				 "isMainBranch" = $isMainBranch 
				 "nugetSource" = $nugetSource }

# propagating the exit code so that builds actually fail when there is a problem
Write-Host "`r`nBuild exit code: " $LASTEXITCODE

Exit $LASTEXITCODE
