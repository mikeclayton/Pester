function Get-ParamBlockFromBoundParameters
{
    param (
        [System.Collections.IDictionary] $BoundParameters,
        [System.Management.Automation.CommandMetadata] $Metadata
    )

    $params = foreach ($paramName in $BoundParameters.get_Keys())
    {
        if (IsCommonParameter -Name $paramName -Metadata $Metadata)
        {
            continue
        }

        "`${$paramName}"
    }

    $params = $params -join ','

    if ($null -ne $Metadata)
    {
        $cmdletBinding = [System.Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($Metadata)
    }
    else
    {
        $cmdletBinding = ''
    }

    return "$cmdletBinding param ($params)"
}
