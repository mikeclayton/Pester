function Invoke-InMockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]
        $ArgumentList = @()
    )

    if ($SessionState.Module)
    {
        $SessionState.Module.Invoke($ScriptBlock, $ArgumentList)
    }
    else
    {
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $SessionState
        & $ScriptBlock @ArgumentList
    }
}
