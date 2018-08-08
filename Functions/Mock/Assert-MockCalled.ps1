function Assert-MockCalled {
<#
.SYNOPSIS
Checks if a Mocked command has been called a certain number of times
and throws an exception if it has not.

.DESCRIPTION
This command verifies that a mocked command has been called a certain number
of times.  If the call history of the mocked command does not match the parameters
passed to Assert-MockCalled, Assert-MockCalled will throw an exception.

.PARAMETER CommandName
The mocked command whose call history should be checked.

.PARAMETER ModuleName
The module where the mock being checked was injected.  This is optional,
and must match the ModuleName that was used when setting up the Mock.

.PARAMETER Times
The number of times that the mock must be called to avoid an exception
from throwing.

.PARAMETER Exactly
If this switch is present, the number specified in Times must match
exactly the number of times the mock has been called. Otherwise it
must match "at least" the number of times specified.  If the value
passed to the Times parameter is zero, the Exactly switch is implied.

.PARAMETER ParameterFilter
An optional filter to qualify wich calls should be counted. Only those
calls to the mock whose parameters cause this filter to return true
will be counted.

.PARAMETER ExclusiveFilter
Like ParameterFilter, except when you use ExclusiveFilter, and there
were any calls to the mocked command which do not match the filter,
an exception will be thrown.  This is a convenient way to avoid needing
to have two calls to Assert-MockCalled like this:

Assert-MockCalled SomeCommand -Times 1 -ParameterFilter { $something -eq $true }
Assert-MockCalled SomeCommand -Times 0 -ParameterFilter { $something -ne $true }

.PARAMETER Scope
An optional parameter specifying the Pester scope in which to check for
calls to the mocked command.  By default, Assert-MockCalled will find
all calls to the mocked command in the current Context block (if present),
or the current Describe block (if there is no active Context.)  Valid
values are Describe, Context and It. If you use a scope of Describe or
Context, the command will identify all calls to the mocked command in the
current Describe / Context block, as well as all child scopes of that block.

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content

This will throw an exception and cause the test to fail if Set-Content is not called in Some Code.

.EXAMPLE
C:\PS>Mock Set-Content -parameterFilter {$path.StartsWith("$env:temp\")}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 2 { $path -eq "$env:temp\test.txt" }

This will throw an exception if some code calls Set-Content on $path=$env:temp\test.txt less than 2 times

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 0

This will throw an exception if some code calls Set-Content at all

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content -Exactly 2

This will throw an exception if some code does not call Set-Content Exactly two times.

.EXAMPLE
Describe 'Assert-MockCalled Scope behavior' {
    Mock Set-Content { }

    It 'Calls Set-Content at least once in the It block' {
        {... Some Code ...}

        Assert-MockCalled Set-Content -Exactly 0 -Scope It
    }
}

Checks for calls only within the current It block.

.EXAMPLE
Describe 'Describe' {
    Mock -ModuleName SomeModule Set-Content { }

    {... Some Code ...}

    It 'Calls Set-Content at least once in the Describe block' {
        Assert-MockCalled -ModuleName SomeModule Set-Content
    }
}

Checks for calls to the mock within the SomeModule module.  Note that both the Mock
and Assert-MockCalled commands use the same module name.

.EXAMPLE
Assert-MockCalled Get-ChildItem -ExclusiveFilter { $Path -eq 'C:\' }

Checks to make sure that Get-ChildItem was called at least one time with
the -Path parameter set to 'C:\', and that it was not called at all with
the -Path parameter set to any other value.

.NOTES
The parameter filter passed to Assert-MockCalled does not necessarily have to match the parameter filter
(if any) which was used to create the Mock.  Assert-MockCalled will find any entry in the command history
which matches its parameter filter, regardless of how the Mock was created.  However, if any calls to the
mocked command are made which did not match any mock's parameter filter (resulting in the original command
being executed instead of a mock), these calls to the original command are not tracked in the call history.
In other words, Assert-MockCalled can only be used to check for calls to the mocked implementation, not
to the original.

#>

[CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$CommandName,

    [Parameter(Position = 1)]
    [int]$Times=1,

    [Parameter(ParameterSetName = 'ParameterFilter', Position = 2)]
    [ScriptBlock]$ParameterFilter = {$True},

    [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
    [scriptblock] $ExclusiveFilter,

    [Parameter(Position = 3)]
    [string] $ModuleName,

    [Parameter(Position = 4)]
    [ValidateScript({
        if ([uint32]::TryParse($_, [ref] $null) -or
            $_ -eq 'Describe' -or
            $_ -eq 'Context' -or
            $_ -eq 'It')
        {
            return $true
        }

        throw "Scope argument must either be an unsigned integer, or one of the words 'Describe', 'Context', or 'It'."
    })]
    [string] $Scope,

    [switch]$Exactly
)

    if ($PSCmdlet.ParameterSetName -eq 'ParameterFilter')
    {
        $filter = $ParameterFilter
        $filterIsExclusive = $false
    }
    else
    {
        $filter = $ExclusiveFilter
        $filterIsExclusive = $true
    }

    Assert-DescribeInProgress -CommandName Assert-MockCalled

    if (-not $PSBoundParameters.ContainsKey('ModuleName') -and $null -ne $pester.SessionState.Module)
    {
        $ModuleName = $pester.SessionState.Module.Name
    }

    $contextInfo = Validate-Command $CommandName $ModuleName
    $CommandName = $contextInfo.Command.Name

    $mock = $script:mockTable["$ModuleName||$CommandName"]

    $moduleMessage = ''
    if ($ModuleName)
    {
        $moduleMessage = " in module $ModuleName"
    }

    if (-not $mock)
    {
        throw "You did not declare a mock of the $commandName Command${moduleMessage}."
    }

    if (-not $PSBoundParameters.ContainsKey('Scope'))
    {
        $scope = 1
    }

    $matchingCalls = & $SafeCommands['New-Object'] System.Collections.ArrayList
    $nonMatchingCalls = & $SafeCommands['New-Object'] System.Collections.ArrayList

    foreach ($historyEntry in $mock.CallHistory)
    {
        if (-not (Test-MockCallScope -CallScope $historyEntry.Scope -DesiredScope $Scope)) { continue }

        $params = @{
            ScriptBlock     = $filter
            BoundParameters = $historyEntry.BoundParams
            ArgumentList    = $historyEntry.Args
            Metadata        = $mock.Metadata
        }


        if (Test-ParameterFilter @params)
        {
            $null = $matchingCalls.Add($historyEntry)
        }
        else
        {
            $null = $nonMatchingCalls.Add($historyEntry)
        }
    }

    $lineText = $MyInvocation.Line.TrimEnd("$([System.Environment]::NewLine)")
    $line = $MyInvocation.ScriptLineNumber

    if($matchingCalls.Count -ne $times -and ($Exactly -or ($times -eq 0)))
    {
        $failureMessage = "Expected ${commandName}${moduleMessage} to be called $times times exactly but was called $($matchingCalls.Count) times"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
    elseif($matchingCalls.Count -lt $times)
    {
        $failureMessage = "Expected ${commandName}${moduleMessage} to be called at least $times times but was called $($matchingCalls.Count) times"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
    elseif ($filterIsExclusive -and $nonMatchingCalls.Count -gt 0)
    {
        $failureMessage = "Expected ${commandName}${moduleMessage} to only be called with with parameters matching the specified filter, but $($nonMatchingCalls.Count) non-matching calls were made"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
}
