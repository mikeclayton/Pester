function Invoke-Mock {
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName,

        [Parameter(Mandatory = $true)]
        [hashtable] $MockCallState,

        [string]
        $ModuleName,

        [hashtable]
        $BoundParameters = @{},

        [object[]]
        $ArgumentList = @(),

        [object] $CallerSessionState,

        [ValidateSet('Begin', 'Process', 'End')]
        [string] $FromBlock,

        [object] $InputObject
    )

    $detectedModule = $ModuleName
    $mock = FindMock -CommandName $CommandName -ModuleName ([ref]$detectedModule)

    if ($null -eq $mock)
    {
        # If this ever happens, it's a bug in Pester.  The scriptBlock that calls Invoke-Mock should be removed at the same time as the entry in the mock table.
        throw "Internal error detected:  Mock for '$CommandName' in module '$ModuleName' was called, but does not exist in the mock table."
    }

    switch ($FromBlock)
    {
        Begin
        {
            $MockCallState['InputObjects'] = & $SafeCommands['New-Object'] System.Collections.ArrayList
            $MockCallState['ShouldExecuteOriginalCommand'] = $false
            $MockCallState['BeginBoundParameters'] = $BoundParameters.Clone()
            $MockCallState['BeginArgumentList'] = $ArgumentList

            return
        }

        Process
        {
            $block = $null
            if ($detectedModule -eq $ModuleName)
            {
                $block = FindMatchingBlock -Mock $mock -BoundParameters $BoundParameters -ArgumentList $ArgumentList
            }

            if ($null -ne $block)
            {
                ExecuteBlock -Block $block `
                             -CommandName $CommandName `
                             -ModuleName $ModuleName `
                             -BoundParameters $BoundParameters `
                             -ArgumentList $ArgumentList `
                             -Mock $mock

                return
            }
            else
            {
                $MockCallState['ShouldExecuteOriginalCommand'] = $true
                if ($null -ne $InputObject)
                {
                    $null = $MockCallState['InputObjects'].AddRange(@($InputObject))
                }

                return
            }
        }

        End
        {
            if ($MockCallState['ShouldExecuteOriginalCommand'])
            {
                if ($MockCallState['InputObjects'].Count -gt 0)
                {
                    $scriptBlock = {
                        param ($Command, $ArgumentList, $BoundParameters, $InputObjects)
                        $InputObjects | & $Command @ArgumentList @BoundParameters
                    }
                }
                else
                {
                    $scriptBlock = {
                        param ($Command, $ArgumentList, $BoundParameters, $InputObjects)
                        & $Command @ArgumentList @BoundParameters
                    }
                }

                $state = if ($CallerSessionState) { $CallerSessionState } else { $mock.SessionState }

                Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $state

                & $scriptBlock -Command $mock.OriginalCommand `
                               -ArgumentList $MockCallState['BeginArgumentList'] `
                               -BoundParameters $MockCallState['BeginBoundParameters'] `
                               -InputObjects $MockCallState['InputObjects']
            }
        }
    }
}
