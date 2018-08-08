function Get-DynamicParametersForMockedFunction
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FunctionName,

        [string]
        $ModuleName,

        [System.Collections.IDictionary]
        $Parameters,

        [object]
        $Cmdlet
    )

    $mock = $mockTable["$ModuleName||$FunctionName"]

    if (-not $mock)
    {
        throw "Internal error detected:  Mock for '$FunctionName' in module '$ModuleName' was called, but does not exist in the mock table."
    }

    if ($mock.DynamicParamScriptBlock)
    {
        $splat = @{ 'P S Cmdlet' = $Cmdlet }
        return & $mock.DynamicParamScriptBlock @Parameters @splat
    }
}
