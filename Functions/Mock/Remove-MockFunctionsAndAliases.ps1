function Remove-MockFunctionsAndAliases {
    # when a test is terminated (e.g. by stopping at a breakpoint and then stoping the execution of the script)
    # the aliases and bootstrap functions for the currently mocked functions will remain in place
    # Then on subsequent runs the bootstrap function will be picked up instead of the real command,
    # because there is still an alias associated with it, and the test will fail.
    # So before putting Pester state in place we should make sure that all Pester mocks are gone
    # by deleting every alias pointing to a function that starts with PesterMock_. Then we also delete the
    # bootstrap function.
    foreach ($alias in (& $script:SafeCommands['Get-Alias'] -Definition "PesterMock_*"))
    {
        & $script:SafeCommands['Remove-Item'] "alias:/$($alias.Name)"
    }

    foreach ($bootstrapFunction in (& $script:SafeCommands['Get-Command'] -Name "PesterMock_*"))
    {
        & $script:SafeCommands['Remove-Item'] "function:/$($bootstrapFunction.Name)"
    }
}
