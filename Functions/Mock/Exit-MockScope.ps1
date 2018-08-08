function Exit-MockScope {
    param (
        [switch] $ExitTestCaseOnly
    )

    if ($null -eq $mockTable) { return }

    $removeMockStub =
    {
        param (
            [string] $CommandName,
            [string[]] $Aliases
        )

        $ExecutionContext.InvokeProvider.Item.Remove("Function:\$CommandName", $false, $true, $true)

        foreach ($alias in $Aliases)
        {
            if ($ExecutionContext.InvokeProvider.Item.Exists("Alias:$alias", $true, $true))
            {
                $ExecutionContext.InvokeProvider.Item.Remove("Alias:$alias", $false, $true, $true)
            }
        }
    }

    $mockKeys = [string[]]$mockTable.Keys

    foreach ($mockKey in $mockKeys)
    {
        $mock = $mockTable[$mockKey]

        $shouldRemoveMock = (-not $ExitTestCaseOnly) -and (ShouldRemoveMock -Mock $mock -ActivePesterState $pester)
        if ($shouldRemoveMock)
        {
            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $removeMockStub -ArgumentList $mock.BootstrapFunctionName, $mock.Aliases
            $mockTable.Remove($mockKey)
        }
        elseif ($mock.PesterState -eq $pester)
        {
            if (-not $ExitTestCaseOnly)
            {
                $mock.Blocks = @($mock.Blocks | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.CurrentTestGroup })
            }

            $testGroups = @($pester.TestGroups)

            $parentTestGroup = $null

            if ($testGroups.Count -gt 1)
            {
                $parentTestGroup = $testGroups[-2]
            }

            foreach ($historyEntry in $mock.CallHistory)
            {
                if ($ExitTestCaseOnly)
                {
                    if ($historyEntry.Scope -eq $null) { $historyEntry.Scope = $pester.CurrentTestGroup }
                }
                elseif ($parentTestGroup)
                {
                    if ($historyEntry.Scope -eq $pester.CurrentTestGroup) { $historyEntry.Scope = $parentTestGroup }
                }
            }
        }
    }
}
