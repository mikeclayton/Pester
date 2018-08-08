function FindMock
{
    param (
        [string] $CommandName,
        [ref] $ModuleName
    )

    $mock = $mockTable["$($ModuleName.Value)||$CommandName"]

    if ($null -eq $mock)
    {
        $mock = $mockTable["||$CommandName"]
        if ($null -ne $mock)
        {
            $ModuleName.Value = ''
        }
    }

    return $mock
}
