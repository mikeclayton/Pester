function Test-ParameterFilter
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [System.Collections.IDictionary]
        $BoundParameters,

        [object[]]
        $ArgumentList,

        [System.Management.Automation.CommandMetadata]
        $Metadata
    )

    if ($null -eq $BoundParameters)   { $BoundParameters = @{} }
    if ($null -eq $ArgumentList)      { $ArgumentList = @() }

    $paramBlock = Get-ParamBlockFromBoundParameters -BoundParameters $BoundParameters -Metadata $Metadata

    $scriptBlockString = "
        $paramBlock

        Set-StrictMode -Off
        $ScriptBlock
    "

    $cmd = [scriptblock]::Create($scriptBlockString)
    Set-ScriptBlockScope -ScriptBlock $cmd -SessionState $pester.SessionState

    & $cmd @BoundParameters @ArgumentList
}
