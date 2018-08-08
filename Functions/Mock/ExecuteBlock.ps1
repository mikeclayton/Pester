function ExecuteBlock
{
    param (
        [object] $Block,
        [object] $Mock,
        [string] $CommandName,
        [string] $ModuleName,
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @()
    )

    $Block.Verifiable = $false

    $scope = if ($pester.InTest) { $null } else { $pester.CurrentTestGroup }
    $Mock.CallHistory += @{CommandName = "$ModuleName||$CommandName"; BoundParams = $BoundParameters; Args = $ArgumentList; Scope = $scope }

    $scriptBlock = {
        param (
            [Parameter(Mandatory = $true)]
            [scriptblock]
            ${Script Block},

            [hashtable]
            $___BoundParameters___ = @{},

            [object[]]
            $___ArgumentList___ = @(),

            [System.Management.Automation.CommandMetadata]
            ${Meta data},

            [System.Management.Automation.SessionState]
            ${Session State}
        )

        # This script block exists to hold variables without polluting the test script's current scope.
        # Dynamic parameters in functions, for some reason, only exist in $PSBoundParameters instead
        # of being assigned a local variable the way static parameters do.  By calling Set-DynamicParameterVariable,
        # we create these variables for the caller's use in a Parameter Filter or within the mock itself, and
        # by doing it inside this temporary script block, those variables don't stick around longer than they
        # should.

        Set-DynamicParameterVariable -SessionState ${Session State} -Parameters $___BoundParameters___ -Metadata ${Meta data}
        & ${Script Block} @___BoundParameters___ @___ArgumentList___
    }

    Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $mock.SessionState
    $splat = @{
        'Script Block' = $block.Mock
        '___ArgumentList___' = $ArgumentList
        '___BoundParameters___' = $BoundParameters
        'Meta data' = $mock.Metadata
        'Session State' = $mock.SessionState
    }

    & $scriptBlock @splat
}
