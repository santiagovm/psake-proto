Include ".\helpers.ps1"

properties {
    $cleanMessage = 'Executed Clean!'
    $testMessage = 'Executed Test!'

    $solutionDirectory = (Get-Item $solutionFile).DirectoryName
    
    $outputDirectory = "$solutionDirectory\.build"
    $temporaryOutputDirectory = "$outputDirectory\temp"

    $publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"

    $testResultsDirectory = "$outputDirectory\TestResults"
    $NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"

    $buildConfiguration = "Release"
    $buildPlatform = "Any CPU"

    $packagesPath = "$solutionDirectory\packages"

    $nunitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner") + "\tools\nunit3-console.exe"
}

FormatTaskName "`r`n`r`n------------------ Executing {0} Task ------------------"

task default `
    -depends Test
                                                                                                            
task Init `
    -description "Initiates the build by removing previous artifacts and creating output directories" `
    -requiredVariables outputDirectory, temporaryOutputDirectory `
{
    Assert("Debug", "Release" -contains $buildConfiguration) `
    "Invalid build configuration [$buildConfiguration]. Valid values are 'Debug' or 'Release'"

    Assert("x86", "x64", "Any CPU" -contains $buildPlatform) `
    "Invalid build platform [$buildPlatform]. Valid values are 'x86', 'x64', or 'Any CPU'"

    # Checking that all tools are available
    Write-Host "Checking that all required tools are available"
    Assert(Test-Path $nunitExe) "NUnit Console could not be found at [$nunitExe]"

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

task RestorePackages `
    -description "Restores NuGet packages" `
    -requiredVariables solutionFile, nugetExe `
{
    Write-Host "Restoring packages for solution [$solutionFile] using NuGet at [$nugetExe]"
    Exec { & $nugetExe restore $solutionFile -PackagesDirectory ..\packages -NonInteractive }
}

task Compile `
    -depends Init, RestorePackages `
    -description "Compile the code" `
    -requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{
    Write-Host "Building solution [$solutionFile]"

    Exec {
        msbuild $solutionFile /m "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
    }
}

task Clean `
    -description "Remove temporary files" `
{
    Write-Host $cleanMessage
}

task TestNUnit `
    -depends Compile `
    -description "Run NUnit tests" `
    -precondition { return Test-Path $publishedNUnitTestsDirectory } `
{
    $projects = Get-ChildItem $publishedNUnitTestsDirectory

    if ($projects.Count -eq 1)
    {
        Write-Host "1 NUnit project has been found:"
    }
    else
    {
        Write-Host $projects.Count " NUnit projects have been found:"
    }

    Write-Host ($projects | Select $_.Name)

    # creating the test results directory if needed
    if (!(Test-Path $NUnitTestResultsDirectory))
    {
        Write-Host "Creating test results directory located at [$NUnitTestResultsDirectory]"
        mkdir $NUnitTestResultsDirectory | Out-Null
    }

    # getting list of test DLLs
    $testAssemblies = $projects | ForEach-Object { $_.FullName + "\" + $_.Name + ".dll" }

    $testAssembliesParameter = [string]::Join(" ", $testAssemblies)

    Exec { & $nunitExe $testAssembliesParameter --work $NUnitTestResultsDirectory --noheader }
}

task TestMSTest `
    -depends Compile `
    -description "Run MSTest tests" `
{
}

task Test `
    -depends Compile, TestNUnit, TestMSTest `
    -description "Run unit tests" `
{
    Write-Host $testMessage
}
