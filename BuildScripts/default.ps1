Include ".\helpers.ps1"

properties {
    $cleanMessage = 'Executed Clean!'

    $solutionDirectory = (Get-Item $solutionFile).DirectoryName
    
    $outputDirectory = "$solutionDirectory\.build"
    $temporaryOutputDirectory = "$outputDirectory\temp"

    $publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
    $publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTests"
    $publishedApplicationsDirectory = "$temporaryOutputDirectory\_PublishedApplications"
    $publishedWebsitesDirectory = "$temporaryOutputDirectory\_PublishedWebsites"
    
    $testResultsDirectory = "$outputDirectory\TestResults"
    $NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
    $MSTestTestResultsDirectory = "$testResultsDirectory\MSTest"

    $testCoverageDirectory = "$outputDirectory\TestCoverage"
    $testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
    $testCoverageFilter = "`"`"+[*]* -[*.NUnitTests]* -[*.Tests]*`"`""
    $testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
    $testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"

    $packagesOutputDirectory = "$outputDirectory\Packages"
    $applicationsOutputDirectory = "$packagesOutputDirectory\Applications"
    
    $buildConfiguration = "Release"
    $buildPlatform = "Any CPU"

    $packagesPath = "$solutionDirectory\packages"

    $nunitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner") + "\tools\nunit3-console.exe"

    # SANTI PUT THIS BACK $vsTestExe = (Get-ChildItem("C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | select -Last 1
    $vsTestExe = "foo.exe"

    $openCoverExe = (Find-PackagePath $packagesPath "OpenCover") + "\tools\OpenCover.Console.exe"
    $reportGeneratorExe = (Find-PackagePath $packagesPath "ReportGenerator") + "\tools\ReportGenerator.exe"
    $7ZipExe = (Find-PackagePath $packagesPath "7-Zip.CommandLine") + "\tools\7za.exe"
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

    Exec `
    {
        Assert(Test-Path $nunitExe) "NUnit Console could not be found at [$nunitExe]"
        # SANTI: PUT THIS BACK Assert(Test-Path $vsTestExe) "VSTest Console could not be found at [$vsTestExe]"
        Assert(Test-Path $openCoverExe) "OpenCover Console could not be found at [$openCoverExe]"
        Assert(Test-Path $reportGeneratorExe) "ReportGenerator Console could not be found at [$reportGeneratorExe]"
        Assert(Test-Path $7ZipExe) "7-Zip Command Line could not be found at [$7ZipExe]"
    }
    
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

    Exec `
    {
        msbuild $solutionFile /m "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
    }
}

task TestNUnit `
    -depends Compile `
    -description "Run NUnit tests" `
    -precondition { return Test-Path $publishedNUnitTestsDirectory } `
{
    $testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
                                    -publishedTestsDirectory $publishedNUnitTestsDirectory `
                                    -testResultsDirectory $NUnitTestResultsDirectory `
                                    -testCoverageDirectory $testCoverageDirectory

    $targetArgs = "$testAssemblies --work `"`"$NUnitTestResultsDirectory`"`" --noheader"

    # running OpenCover, which in turn will run NUnit
    Run-Tests -openCoverExe $openCoverExe `
              -targetExe $nunitExe `
              -targetArgs $targetArgs `
              -coveragePath $testCoverageReportPath `
              -filter $testCoverageFilter `
              -excludeByAttribute $testCoverageExcludeByAttribute `
              -excludeByFile $testCoverageExcludeByFile
}

task TestMSTest `
    -depends Compile `
    -description "Run MSTest tests" `
    -precondition { return Test-Path $publishedMSTestTestsDirectory } `
{
    $testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
                                    -publishedTestsDirectory $publishedMSTestTestsDirectory `
                                    -testResultsDirectory $MSTestTestResultsDirectory `
                                    -testCoverageDirectory $testCoverageDirectory

    # changing working directory and back to current directory because vstest console doesn't have any option to change the output directory so we need to change the working directory
    Push-Location $MSTestTestResultsDirectory

    $targetArgs = "$testAssemblies /Logger:trx"

    # running OpenCover, which in turn will run NUnit
    Run-Tests -openCoverExe $openCoverExe `
              -targetExe $vsTestExe `
              -targetArgs $targetArgs `
              -coveragePath $testCoverageReportPath `
              -filter $testCoverageFilter `
              -excludeByAttribute: $testCoverageExcludeByAttribute `
              -excludeByFile: $testCoverageExcludeByFile

    Pop-Location

    # moving the .trx file back to the results directory because vstest create its own results directory (Test Results)
    Move-Item -Path $MSTestTestResultsDirectory\TestResults\*.trx -Destination $MSTestTestResultsDirectory\MSTest.trx

    Remove-Item $MSTestTestResultsDirectory\TestResults
}

# SANTI: ADD MSTEST WHEN AVAILABLE IN TEAM-CITY
task Test `
    -depends Compile, TestNUnit `
    -description "Run unit tests" `
{
    if (Test-Path $testCoverageReportPath)
    {
        # generating HTML test coverage report
        Write-Host "`r`nGenerating HTML test coverage report"
        Exec { & $reportGeneratorExe $testCoverageReportPath $testCoverageDirectory }

        # loading the coverage report as xml
        Exec `
        {
            Write-Host "`r`n >>> TeamCity service messages BEGIN`r`n"

            $coverage = [xml](Get-Content -Path $testCoverageReportPath)
            $coverageSummary = $coverage.CoverageSession.Summary
        
            # providing service messages to TeamCity for class coverage
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
            Write-Host("##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N2}']" -f (($coverageSummary.visitedClasses / $coverageSummary.numClasses) * 100))

            # providing service messages to TeamCity for method coverage
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
            Write-Host("##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N2}']" -f (($coverageSummary.visitedMethods / $coverageSummary.numMethods) * 100))

            # providing service messages to TeamCity for branch coverage
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBCovered' value='$($coverageSummary.visitedBranchPoints)']"
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBTotal' value='$($coverageSummary.numBranchPoints)']"
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageB' value='$($coverageSummary.branchCoverage)']"

            # providing service messages to TeamCity for statement coverage using OpenCover sequence coverage
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSCovered' value='$($coverageSummary.visitedSequencePoints)']"
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSTotal' value='$($coverageSummary.numSequencePoints)']"
            Write-Host "##teamcity[buildStatisticValue key='CodeCoverageS' value='$($coverageSummary.sequenceCoverage)']"

            Write-Host "`r`n >>> TeamCity service messages END`r`n"
        }
    }
    else
    {
        Write-Host "No coverage file found at [$testCoverageReportPath]"
    }
}

task Package `
    -depends Compile, Test `
    -description "Package applications" `
    -requiredVariables publishedWebsitesDirectory, publishedApplicationsDirectory, applicationsOutputDirectory `
{
    # merging published websites and published applications paths
    $applications = @(Get-ChildItem $publishedWebsitesDirectory) + @(Get-ChildItem $publishedApplicationsDirectory)

    if ($applications.Length -gt 0 -and !(Test-Path $applicationsOutputDirectory))
    {
        New-Item $applicationsOutputDirectory -ItemType Directory | Out-Null
    }

    foreach($app in $applications)
    {
        Write-Host "Packaging [$app.Name] as a zip file"

        $archivePath = "$($applicationsOutputDirectory)\$($app.Name).zip"
        $inputDirectory = "$($app.FullName)\*"

        Exec { & $7ZipExe a -r -mx3 $archivePath $inputDirectory }
    }
}

task Clean `
    -description "Remove temporary files" `
{
    Write-Host $cleanMessage
}