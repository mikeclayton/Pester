function MockPrototype {
    if ($PSVersionTable.PSVersion.Major -ge 3)
    {
        [string] ${ignore preference} = 'Ignore'
    }
    else
    {
        [string] ${ignore preference} = 'SilentlyContinue'
    }

    ${get Variable Command} = & (Pester\SafeGetCommand) -Name Get-Variable -Module Microsoft.PowerShell.Utility -CommandType Cmdlet

    [object] ${a r g s} = $null
    if (${#CANCAPTUREARGS#}) {
        ${a r g s} = & ${get Variable Command} -Name args -ValueOnly -Scope Local -ErrorAction ${ignore preference}
    }
    if ($null -eq ${a r g s}) { ${a r g s} = @() }

    ${p s cmdlet} = & ${get Variable Command} -Name PSCmdlet -ValueOnly -Scope Local -ErrorAction ${ignore preference}

    ${session state} = if (${p s cmdlet}) { ${p s cmdlet}.SessionState }

    # @{mock call state} initialization is injected only into the begin block by the code that uses this prototype.
    Invoke-Mock -CommandName '#FUNCTIONNAME#' -ModuleName '#MODULENAME#' -BoundParameters $PSBoundParameters -ArgumentList ${a r g s} -CallerSessionState ${session state} -FromBlock '#BLOCK#' -MockCallState ${mock call state} #INPUT#
}
