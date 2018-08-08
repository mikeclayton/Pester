function Set-DynamicParameterVariable
{
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [hashtable]
        $Parameters,

        [System.Management.Automation.CommandMetadata]
        $Metadata
    )

    if ($null -eq $Parameters) { $Parameters = @{} }

    foreach ($keyValuePair in $Parameters.GetEnumerator())
    {
        $variableName = $keyValuePair.Key

        if (-not (IsCommonParameter -Name $variableName -Metadata $Metadata))
        {
            if ($ExecutionContext.SessionState -eq $SessionState)
            {
                & $SafeCommands['Set-Variable'] -Scope 1 -Name $variableName -Value $keyValuePair.Value -Force -Confirm:$false -WhatIf:$false
            }
            else
            {
                $SessionState.PSVariable.Set($variableName, $keyValuePair.Value)
            }
        }
    }
}
