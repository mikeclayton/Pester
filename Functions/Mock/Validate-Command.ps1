function Validate-Command([string]$CommandName, [string]$ModuleName) {
    $module = $null
    $command = $null

    $scriptBlock = {
        $command = $ExecutionContext.InvokeCommand.GetCommand($args[0], 'All')
        while ($null -ne $command -and $command.CommandType -eq [System.Management.Automation.CommandTypes]::Alias)
        {
            $command = $command.ResolvedCommand
        }

        return $command
    }

    if ($ModuleName) {
        $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop
        $command = & $module $scriptBlock $CommandName
    }

    $session = $pester.SessionState

    if (-not $command) {
        Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $session
        $command = & $scriptBlock $commandName
    }

    if (-not $command) {
        throw ([System.Management.Automation.CommandNotFoundException] "Could not find Command $commandName")
    }

    if ($module) {
        $session = & $module { $ExecutionContext.SessionState }
    }

    $hash = @{Command = $command; Session = $session}

    if ($command.CommandType -eq 'Function')
    {
        foreach ($mock in $mockTable.Values)
        {
            if ($command.Name -eq $mock.BootstrapFunctionName)
            {
                return @{
                    Command = $mock.OriginalCommand
                    Session = $mock.SessionState
                }
            }
        }
    }

    return $hash
}
