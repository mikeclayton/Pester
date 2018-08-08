function FindMatchingBlock
{
    param (
        [object] $Mock,
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @()
    )

    for ($idx = $mock.Blocks.Length; $idx -gt 0; $idx--)
    {
        $block = $mock.Blocks[$idx - 1]

        $params = @{
            ScriptBlock     = $block.Filter
            BoundParameters = $BoundParameters
            ArgumentList    = $ArgumentList
            Metadata        = $mock.Metadata
        }

        if (Test-ParameterFilter @params)
        {
            return $block
        }
    }

    return $null
}
