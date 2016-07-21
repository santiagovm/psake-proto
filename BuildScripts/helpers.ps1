function Find-PackagePath
{
    [CmdLetBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$packagesPath,
        [Parameter(Position=1,Mandatory=1)]$packageName
    )

    return (Get-ChildItem($packagesPath + "\" + $packageName + "*")).FullName | Sort-Object $_ | select -Last 1
}

function Prepare-Tests
{
    [CmdLetBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$testRunnerName,
        [Parameter(Position=1,Mandatory=1)]$publishedTestsDirectory,
        [Parameter(Position=2,Mandatory=1)]$testResultsDirectory,
        [Parameter(Position=3,Mandatory=1)]$testCoverageDirectory
    )

    $projects = Get-ChildItem $publishedTestsDirectory

    if ($projects.Count -eq 1)
    {
        Write-Host "1 $testRunnerName project has been found:"
    }
    else
    {
        Write-Host $projects.Count " $testRunnerName projects have been found:"
    }

    Write-Host ($projects | Select $_.Name)

    # creating the test results directory if needed
    if (!(Test-Path $testResultsDirectory))
    {
        Write-Host "Creating test results directory located at [$testResultsDirectory]"
        mkdir $testResultsDirectory | Out-Null
    }

    # creating the test coverage directory if needed
    if (!(Test-Path $testCoverageDirectory))
    {
        Write-Host "Creating test coverage directory located at [$testCoverageDirectory]"
        mkdir $testCoverageDirectory | Out-Null
    }

    # getting list of test DLLs
    $testAssembliesPaths = $projects | ForEach-Object { "`"`"" + $_.FullName + "\" + $_.Name + ".dll`"`"" }

    $testAssemblies = [string]::Join(" ", $testAssembliesPaths)

    return $testAssemblies
}

function Run-Tests
{
    [CmdLetBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$openCoverExe,
        [Parameter(Position=1,Mandatory=1)]$targetExe,
        [Parameter(Position=2,Mandatory=1)]$targetArgs,
        [Parameter(Position=3,Mandatory=1)]$coveragePath,
        [Parameter(Position=4,Mandatory=1)]$filter,
        [Parameter(Position=5,Mandatory=1)]$excludeByAttribute,
        [Parameter(Position=6,Mandatory=1)]$excludeByFile
    )

    Write-Host "Running tests"

    # register:user is related to COM objects OpenCover uses to work that need to be registered
    # skipautoprops: exclude autoimplemented properties, nothing useful to test there
    # mergebyhash: in case an object gets loaded for many places
    # mergeoutput: in case different test projects are testing the same code
    # Hide from results stuff filered by File, Filter, Attribute, MissingPDB
    # return the exit code of the target (i.e. test runner)
    Exec `
    { 
        & $openCoverExe -target:$targetExe `
                        -targetargs:$targetArgs `
                        -output:$coveragePath `
                        -register:user `
                        -filter:$filter `
                        -excludebyattribute:$excludeByAttribute `
                        -excludebyfile:$excludeByFile `
                        -skipautoprops `
                        -mergebyhash `
                        -mergeoutput `
                        -hideskipped:All `
                        -returntargetcode
    }
}
