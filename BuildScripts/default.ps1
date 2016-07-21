Include ".\helpers.ps1"

properties {
    $cleanMessage = 'Executed Clean!'
    $testMessage = 'Executed Test!'

    $solutionDirectory = (Get-Item $solutionFile).DirectoryName
    
    $outputDirectory = "$solutionDirectory\.build"
    $temporaryOutputDirectory = "$outputDirectory\temp"

    $publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
    $publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTests"

    $testResultsDirectory = "$outputDirectory\TestResults"
    $NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
    $MSTestTestResultsDirectory = "$testResultsDirectory\MSTest"

    $buildConfiguration = "Release"
    $buildPlatform = "Any CPU"

    $packagesPath = "$solutionDirectory\packages"

    $nunitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner") + "\tools\nunit3-console.exe"

    $vsTestExe = (Get-ChildItem("C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | select -Last 1
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
    # SANTI: PUT THIS BACK Assert(Test-Path $vsTestExe) "VSTest Console could not be found at [$vsTestExe]"

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
    $testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
                                    -publishedTestsDirectory $publishedNUnitTestsDirectory `
                                    -testResultsDirectory $NUnitTestResultsDirectory

    Exec { & $nunitExe $testAssemblies --work $NUnitTestResultsDirectory --noheader }
}

task TestMSTest `
    -depends Compile `
    -description "Run MSTest tests" `
    -precondition { return Test-Path $publishedMSTestTestsDirectory } `
{
    $testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
                                    -publishedTestsDirectory $publishedMSTestTestsDirectory `
                                    -testResultsDirectory $MSTestTestResultsDirectory

    # changing working directory and back to current directory because vstest console doesn't have any option to change the output directory so we need to change the working directory
    Push-Location $MSTestTestResultsDirectory

    Exec { & $vsTestExe $testAssemblies /Logger:trx }

    Pop-Location

    # moving the .trx file back to the results directory because vstest create its own results directory (Test Results)
    Move-Item -Path $MSTestTestResultsDirectory\TestResults\*.trx -Destination $MSTestTestResultsDirectory\MSTest.trx

    Remove-Item $MSTestTestResultsDirectory\TestResults
}

task Test `
    -depends Compile, TestNUnit, TestMSTest `
    -description "Run unit tests" `
{
    Write-Host $testMessage
}
