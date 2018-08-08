function Get-DynamicParamBlock
{
    param (
        [scriptblock] $ScriptBlock
    )

    if ($PSVersionTable.PSVersion.Major -le 2)
    {
        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $dynamicParams = [scriptblock].GetField('_dynamicParams', $flags).GetValue($ScriptBlock)

        if ($null -ne $dynamicParams)
        {
            return $dynamicParams.ToString()

        }
    }
    else
    {
        If ( $ScriptBlock.AST.psobject.Properties.Name -match "Body")
        {
            if ($null -ne $ScriptBlock.Ast.Body.DynamicParamBlock)
            {
                $statements = $ScriptBlock.Ast.Body.DynamicParamBlock.Statements |
                            & $SafeCommands['Select-Object'] -ExpandProperty Extent |
                            & $SafeCommands['Select-Object'] -ExpandProperty Text

                return $statements -join "$([System.Environment]::NewLine)"
            }
        }
    }
}
