﻿function Find-PackagePath
{
	[CmdLetBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)]$packagesPath,
		[Parameter(Position=1,Mandatory=1)]$packageName
	)

	return (Get-ChildItem($packagesPath + "\" + $packageName + "*")).FullName | Sort-Object $_ | select -Last 1
}