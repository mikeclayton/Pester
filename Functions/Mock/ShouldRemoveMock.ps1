function ShouldRemoveMock($Mock, $ActivePesterState)
{
    if ($ActivePesterState -ne $mock.PesterState) { return $false }
    if ($mock.Scope -eq $ActivePesterState.CurrentTestGroup) { return $true }

    # These two should conditions should _probably_ never happen, because the above condition should
    # catch it, but just in case:
    if ($ActivePesterState.TestGroups.Count -eq 1) { return $true }
    if ($ActivePesterState.TestGroups[-2].Hint -eq 'Root') { return $true }

    return $false
}
