properties {
    $cleanMessage = 'Executed Clean!'
    $testMessage = 'Executed Test!'

    $solutionDirectory = (Get-Item $solutionFile).DirectoryName
    
    $outputDirectory = "$solutionDirectory\.build"
    $temporaryOutputDirectory = "$outputDirectory\temp"

    $buildConfiguration = "Release"
    $buildPlatform = "Any CPU"
}

FormatTaskName "`r`n`r`n------------------ Executing {0} Task ------------------"

task default -depends Test
                                                                                                            
task Init -description "Initiates the build by removing previous artifacts and creating output directories" `
          -requiredVariables outputDirectory, temporaryOutputDirectory `
{
    Assert("Debug", "Release" -contains $buildConfiguration) `
    "Invalid build configuration [$buildConfiguration]. Valid values are 'Debug' or 'Release'"

    Assert("x86", "x64", "Any CPU" -contains $buildPlatform) `
    "Invalid build platform [$buildPlatform]. Valid values are 'x86', 'x64', or 'Any CPU'"

    # Removing previous build results
    if (Test-Path $outputDirectory)
    {
        Write-Host "Removing output directory located at [$outputDirectory]"
        Remove-Item $outputDirectory -Force -Recurse
    }

    Write-Host "Creating output directory located at [..\.build]"
    New-Item $outputDirectory -ItemType Directory | Out-Null

    Write-Host "Creating temporary directory located at [$temporaryOutputDirectory]"
    New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}

task RestorePackages -description "Restores NuGet packages" `
                     -requiredVariables solutionFile, nugetExe {
    Write-Host "Restoring packages for solution [$solutionFile] using NuGet at [$nugetExe]"
    Exec { & $nugetExe restore $solutionFile -PackagesDirectory ..\packages -NonInteractive }
}

task Compile -depends Init, RestorePackages `
             -description "Compile the code" `
             -requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{
    Write-Host "Building solution [$solutionFile]"

    Exec {
        msbuild $solutionFile /m "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
    }
}

task Clean -description "Remove temporary files" {
    Write-Host $cleanMessage
}

task Test -depends Compile, Clean -description "Run unit tests" {
    Write-Host $testMessage
}
