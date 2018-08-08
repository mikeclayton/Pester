function Mock {

<#
.SYNOPSIS
Mocks the behavior of an existing command with an alternate
implementation.

.DESCRIPTION
This creates new behavior for any existing command within the scope of a
Describe or Context block. The function allows you to specify a script block
that will become the command's new behavior.

Optionally, you may create a Parameter Filter which will examine the
parameters passed to the mocked command and will invoke the mocked
behavior only if the values of the parameter values pass the filter. If
they do not, the original command implementation will be invoked instead
of a mock.

You may create multiple mocks for the same command, each using a different
ParameterFilter. ParameterFilters will be evaluated in reverse order of
their creation. The last one created will be the first to be evaluated.
The mock of the first filter to pass will be used. The exception to this
rule are Mocks with no filters. They will always be evaluated last since
they will act as a "catch all" mock.

Mocks can be marked Verifiable. If so, the Assert-VerifiableMock command
can be used to check if all Verifiable mocks were actually called. If any
verifiable mock is not called, Assert-VerifiableMock will throw an
exception and indicate all mocks not called.

If you wish to mock commands that are called from inside a script module,
you can do so by using the -ModuleName parameter to the Mock command. This
injects the mock into the specified module. If you do not specify a
module name, the mock will be created in the same scope as the test script.
You may mock the same command multiple times, in different scopes, as needed.
Each module's mock maintains a separate call history and verified status.

.PARAMETER CommandName
The name of the command to be mocked.

.PARAMETER MockWith
A ScriptBlock specifying the behavior that will be used to mock CommandName.
The default is an empty ScriptBlock.
NOTE: Do not specify param or dynamicparam blocks in this script block.
These will be injected automatically based on the signature of the command
being mocked, and the MockWith script block can contain references to the
mocked commands parameter variables.

.PARAMETER Verifiable
When this is set, the mock will be checked when Assert-VerifiableMock is
called.

.PARAMETER ParameterFilter
An optional filter to limit mocking behavior only to usages of
CommandName where the values of the parameters passed to the command
pass the filter.

This ScriptBlock must return a boolean value. See examples for usage.

.PARAMETER ModuleName
Optional string specifying the name of the module where this command
is to be mocked.  This should be a module that _calls_ the mocked
command; it doesn't necessarily have to be the same module which
originally implemented the command.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Using this Mock, all calls to Get-ChildItem will return a hashtable with a
FullName property returning "A_File.TXT"

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

This Mock will only be applied to Get-ChildItem calls within the user's temp directory.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter { $Path -eq "some_path" -and $Value -eq "Expected Value" }

When this mock is used, if the Mock is never invoked and Assert-VerifiableMock is called, an exception will be thrown. The command behavior will do nothing since the ScriptBlock is empty.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\1) }
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\2) }
Mock Get-ChildItem { return @{FullName = "C_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\3) }

Multiple mocks of the same command may be used. The parameter filter determines which is invoked. Here, if Get-ChildItem is called on the "2" directory of the temp folder, then B_File.txt will be returned.

.EXAMPLE
Mock Get-ChildItem { return @{FullName="B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName="A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

Get-ChildItem $env:temp\me

Here, both mocks could apply since both filters will pass. A_File.TXT will be returned because it was the most recent Mock created.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem c:\windows

Here, A_File.TXT will be returned. Since no filter was specified, it will apply to any call to Get-ChildItem that does not pass another filter.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem $env:temp\me

Here, B_File.TXT will be returned. Even though the filterless mock was created more recently. This illustrates that filterless Mocks are always evaluated last regardless of their creation order.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ModuleName MyTestModule

Using this Mock, all calls to Get-ChildItem from within the MyTestModule module
will return a hashtable with a FullName property returning "A_File.TXT"

.EXAMPLE
Get-Module -Name ModuleMockExample | Remove-Module
New-Module -Name ModuleMockExample  -ScriptBlock {
    function Hidden { "Internal Module Function" }
    function Exported { Hidden }

    Export-ModuleMember -Function Exported
} | Import-Module -Force

Describe "ModuleMockExample" {

    It "Hidden function is not directly accessible outside the module" {
        { Hidden } | Should -Throw
    }

    It "Original Hidden function is called" {
        Exported | Should -Be "Internal Module Function"
    }

    It "Hidden is replaced with our implementation" {
        Mock Hidden { "Mocked" } -ModuleName ModuleMockExample
        Exported | Should -Be "Mocked"
    }
}

This example shows how calls to commands made from inside a module can be
mocked by using the -ModuleName parameter.


.LINK
Assert-MockCalled
Assert-VerifiableMock
Describe
Context
It
about_Should
about_Mocking
#>
    [CmdletBinding()]
    param(
        [string]$CommandName,
        [ScriptBlock]$MockWith={},
        [switch]$Verifiable,
        [ScriptBlock]$ParameterFilter = {$True},
        [string]$ModuleName
    )

    Assert-DescribeInProgress -CommandName Mock

    $contextInfo = Validate-Command $CommandName $ModuleName
    $CommandName = $contextInfo.Command.Name

    if ($contextInfo.Session.Module -and $contextInfo.Session.Module.Name)
    {
        $ModuleName = $contextInfo.Session.Module.Name
    }
    else
    {
        $ModuleName = ''
    }

    if (Test-IsClosure -ScriptBlock $MockWith)
    {
        # If the user went out of their way to call GetNewClosure(), go ahead and leave the block bound to that
        # dynamic module's scope.
        $mockWithCopy = $MockWith
    }
    else
    {
        $mockWithCopy = [scriptblock]::Create($MockWith.ToString())
        Set-ScriptBlockScope -ScriptBlock $mockWithCopy -SessionState $contextInfo.Session
    }

    $block = @{
        Mock       = $mockWithCopy
        Filter     = $ParameterFilter
        Verifiable = $Verifiable
        Scope      = $pester.CurrentTestGroup
    }

    $mock = $mockTable["$ModuleName||$CommandName"]

    if (-not $mock)
    {
        $metadata                = $null
        $cmdletBinding           = ''
        $paramBlock              = ''
        $dynamicParamBlock       = ''
        $dynamicParamScriptBlock = $null

        if ($contextInfo.Command.psobject.Properties['ScriptBlock'] -or $contextInfo.Command.CommandType -eq 'Cmdlet')
        {
            $metadata = [System.Management.Automation.CommandMetaData]$contextInfo.Command
            $null = $metadata.Parameters.Remove('Verbose')
            $null = $metadata.Parameters.Remove('Debug')
            $null = $metadata.Parameters.Remove('ErrorAction')
            $null = $metadata.Parameters.Remove('WarningAction')
            $null = $metadata.Parameters.Remove('ErrorVariable')
            $null = $metadata.Parameters.Remove('WarningVariable')
            $null = $metadata.Parameters.Remove('OutVariable')
            $null = $metadata.Parameters.Remove('OutBuffer')

            # Some versions of PowerShell may include dynamic parameters here
            # We will filter them out and add them at the end to be
            # compatible with both earlier and later versions
            $dynamicParams = $metadata.Parameters.Values | & $SafeCommands['Where-Object'] {$_.IsDynamic}
            if($dynamicParams -ne $null) {
                $dynamicparams | & $SafeCommands['ForEach-Object'] { $null = $metadata.Parameters.Remove($_.name) }
            }

            $cmdletBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
            if ($global:PSVersionTable.PSVersion.Major -ge 3 -and $contextInfo.Command.CommandType -eq 'Cmdlet') {
                if ($cmdletBinding -ne '[CmdletBinding()]') {
                    $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length-2, ',')
                }
                $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length-2, 'PositionalBinding=$false')
            }

            $paramBlock = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)

            if ($contextInfo.Command.CommandType -eq 'Cmdlet')
            {
                $dynamicParamBlock = "dynamicparam { Get-MockDynamicParameter -CmdletName '$($contextInfo.Command.Name)' -Parameters `$PSBoundParameters }"
            }
            else
            {
                $dynamicParamStatements = Get-DynamicParamBlock -ScriptBlock $contextInfo.Command.ScriptBlock

                if ($dynamicParamStatements -match '\S')
                {
                    $metadataSafeForDynamicParams = [System.Management.Automation.CommandMetaData]$contextInfo.Command
                    foreach ($param in $metadataSafeForDynamicParams.Parameters.Values)
                    {
                        $param.ParameterSets.Clear()
                    }

                    $paramBlockSafeForDynamicParams = [System.Management.Automation.ProxyCommand]::GetParamBlock($metadataSafeForDynamicParams)
                    $comma = if ($metadataSafeForDynamicParams.Parameters.Count -gt 0) { ',' } else { '' }
                    $dynamicParamBlock = "dynamicparam { Get-MockDynamicParameter -ModuleName '$ModuleName' -FunctionName '$CommandName' -Parameters `$PSBoundParameters -Cmdlet `$PSCmdlet }"

                    $code = @"
                        $cmdletBinding
                        param(
                            [object] `${P S Cmdlet}$comma
                            $paramBlockSafeForDynamicParams
                        )

                        `$PSCmdlet = `${P S Cmdlet}

                        $dynamicParamStatements
"@

                    $dynamicParamScriptBlock = [scriptblock]::Create($code)

                    $sessionStateInternal = Get-ScriptBlockScope -ScriptBlock $contextInfo.Command.ScriptBlock

                    if ($null -ne $sessionStateInternal)
                    {
                        Set-ScriptBlockScope -ScriptBlock $dynamicParamScriptBlock -SessionStateInternal $sessionStateInternal
                    }
                }
            }
        }

        $EscapeSingleQuotedStringContent =
        if ($global:PSVersionTable.PSVersion.Major -ge 5) {
            { [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($args[0]) }
        } else {
            { $args[0] -replace "['‘’‚‛]", '$&$&' }
        }

        $newContent = & $SafeCommands['Get-Content'] function:\MockPrototype
        $newContent = $newContent -replace '#FUNCTIONNAME#', (& $EscapeSingleQuotedStringContent $CommandName)
        $newContent = $newContent -replace '#MODULENAME#', (& $EscapeSingleQuotedStringContent $ModuleName)

        $canCaptureArgs = 'true'
        if ($contextInfo.Command.CommandType -eq 'Cmdlet' -or
            ($contextInfo.Command.CommandType -eq 'Function' -and $contextInfo.Command.CmdletBinding)) {
            $canCaptureArgs = 'false'
        }
        $newContent = $newContent -replace '#CANCAPTUREARGS#', $canCaptureArgs

        $code = @"
            $cmdletBinding
            param ( $paramBlock )
            $dynamicParamBlock
            begin
            {
                `${mock call state} = @{}
                $($newContent -replace '#BLOCK#', 'Begin' -replace '#INPUT#')
            }

            process
            {
                $($newContent -replace '#BLOCK#', 'Process' -replace '#INPUT#', '-InputObject @($input)')
            }

            end
            {
                $($newContent -replace '#BLOCK#', 'End' -replace '#INPUT#')
            }
"@

        $mockScript = [scriptblock]::Create($code)

        $mock = @{
            OriginalCommand         = $contextInfo.Command
            Blocks                  = @()
            CommandName             = $CommandName
            SessionState            = $contextInfo.Session
            Scope                   = $pester.CurrentTestGroup
            PesterState             = $pester
            Metadata                = $metadata
            CallHistory             = @()
            DynamicParamScriptBlock = $dynamicParamScriptBlock
            Aliases                 = @()
            BootstrapFunctionName   = 'PesterMock_' + [Guid]::NewGuid().Guid
        }

        $mockTable["$ModuleName||$CommandName"] = $mock

        $scriptBlock = { $ExecutionContext.InvokeProvider.Item.Set("Function:\script:$($args[0])", $args[1], $true, $true) }
        $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $Mock.BootstrapFunctionName, $mockScript

        $mock.Aliases += $CommandName

        $scriptBlock = {
            $setAlias = & (Pester\SafeGetCommand) -Name Set-Alias -CommandType Cmdlet -Module Microsoft.PowerShell.Utility
            & $setAlias -Name $args[0] -Value $args[1] -Scope Script
        }

        $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $CommandName, $mock.BootstrapFunctionName

        if ($mock.OriginalCommand.ModuleName)
        {
            $aliasName = "$($mock.OriginalCommand.ModuleName)\$($CommandName)"
            $mock.Aliases += $aliasName

            $scriptBlock = {
                $setAlias = & (Pester\SafeGetCommand) -Name Set-Alias -CommandType Cmdlet -Module Microsoft.PowerShell.Utility
                & $setAlias -Name $args[0] -Value $args[1] -Scope Script
            }

            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $aliasName, $mock.BootstrapFunctionName
        }
    }

    $mock.Blocks = @(
        $mock.Blocks | & $SafeCommands['Where-Object'] { $_.Filter.ToString() -eq '$True' }
        if ($block.Filter.ToString() -eq '$True') { $block }

        $mock.Blocks | & $SafeCommands['Where-Object'] { $_.Filter.ToString() -ne '$True' }
        if ($block.Filter.ToString() -ne '$True') { $block }
    )
}
