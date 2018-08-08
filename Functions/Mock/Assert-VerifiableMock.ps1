function Assert-VerifiableMock {
<#
.SYNOPSIS
Checks if any Verifiable Mock has not been invoked. If so, this will throw an exception.

.DESCRIPTION
This can be used in tandem with the -Verifiable switch of the Mock
function. Mock can be used to mock the behavior of an existing command
and optionally take a -Verifiable switch. When Assert-VerifiableMock
is called, it checks to see if any Mock marked Verifiable has not been
invoked. If any mocks have been found that specified -Verifiable and
have not been invoked, an exception will be thrown.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

{ ...some code that never calls Set-Content some_path -Value "Expected Value"... }

Assert-VerifiableMock

This will throw an exception and cause the test to fail.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

Set-Content some_path -Value "Expected Value"

Assert-VerifiableMock

This will not throw an exception because the mock was invoked.

#>
    [CmdletBinding()]param()
    Assert-DescribeInProgress -CommandName Assert-VerifiableMock

    $unVerified=@{}
    $mockTable.Keys | & $SafeCommands['ForEach-Object'] {
        $m=$_;

        $mockTable[$m].blocks |
        & $SafeCommands['Where-Object'] { $_.Verifiable } |
        & $SafeCommands['ForEach-Object'] { $unVerified[$m]=$_ }
    }
    if($unVerified.Count -gt 0) {
        foreach($mock in $unVerified.Keys){
            $array = $mock -split '\|\|'
            $function = $array[1]
            $module = $array[0]

            $message = "$([System.Environment]::NewLine) Expected $function "
            if ($module) { $message += "in module $module " }
            $message += "to be called with $($unVerified[$mock].Filter)"
        }
        throw $message
    }
}
