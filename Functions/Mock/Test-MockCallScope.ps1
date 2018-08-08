function Test-MockCallScope
{
    [CmdletBinding()]
    param (
        [object] $CallScope,
        [string] $DesiredScope
    )

    if ($null -eq $CallScope)
    {
        # This indicates a call from the current test case ("It" block), which always passes Test-MockCallScope
        return $true
    }

    $testGroups = $pester.TestGroups
    [Array]::Reverse($testGroups)

    $target = 0
    $isNumberedScope = [int]::TryParse($DesiredScope, [ref] $target)

    # The Describe / Context stuff here is for backward compatibility.  May be deprecated / removed in the future.
    $actualScopeNumber = -1
    $describe = -1
    $context = -1

    for ($i = 0; $i -lt $testGroups.Count; $i++)
    {
        if ($CallScope -eq $testGroups[$i])
        {
            $actualScopeNumber = $i
            if ($isNumberedScope) { break }
        }

        if ($describe -lt 0 -and $testGroups[$i].Hint -eq 'Describe') { $describe = $i }
        if ($context -lt 0 -and $testGroups[$i].Hint -eq 'Context') { $context = $i }
    }

    if ($actualScopeNumber -lt 0)
    {
        # this should never happen; if we get here, it's a Pester bug.

        throw "Pester error: Corrupted mock call history table."
    }

    if ($isNumberedScope)
    {
        # For this, we consider scope 0 to be the current test case / It block, scope 1 to be the first Test Group up the stack, etc.
        # $actualScopeNumber currently off by one from that scale (zero-indexed for test groups only; we already checked for the 0 case
        # farther up, which only applies if $CallScope is $null).
        return $target -gt $actualScopeNumber
    }
    else
    {
        if ($DesiredScope -eq 'Describe') { return $describe -ge $actualScopeNumber }
        if ($DesiredScope -eq 'Context')  { return $context -ge $actualScopeNumber }
    }

    return $false
}
