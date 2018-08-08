function Get-DynamicParametersForCmdlet
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $CmdletName,

        [ValidateScript({
            if ($PSVersionTable.PSVersion.Major -ge 3 -and
                $null -ne $_ -and
                $_.GetType().FullName -ne 'System.Management.Automation.PSBoundParametersDictionary')
            {
                throw 'The -Parameters argument must be a PSBoundParametersDictionary object ($PSBoundParameters).'
            }

            return $true
        })]
        [System.Collections.IDictionary] $Parameters
    )

    try
    {
        $command = & $SafeCommands['Get-Command'] -Name $CmdletName -CommandType Cmdlet -ErrorAction Stop

        if (@($command).Count -gt 1)
        {
            throw "Name '$CmdletName' resolved to multiple Cmdlets"
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    if ($null -eq $command.ImplementingType.GetInterface('IDynamicParameters', $true))
    {
        return
    }

    if ('5.0.10586.122' -lt $PSVersionTable.PSVersion)
    {
        # Older version of PS required Reflection to do this.  It has run into problems on occasion with certain cmdlets,
        # such as ActiveDirectory and AzureRM, so we'll take advantage of the newer PSv5 engine features if at all possible.

        if ($null -eq $Parameters) { $paramsArg = @() } else { $paramsArg = @($Parameters) }

        $command = $ExecutionContext.InvokeCommand.GetCommand($CmdletName, [System.Management.Automation.CommandTypes]::Cmdlet, $paramsArg)
        $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()

        foreach ($param in $command.Parameters.Values)
        {
            if (-not $param.IsDynamic) { continue }
            if ($Parameters.ContainsKey($param.Name)) { continue }

            $dynParam = [System.Management.Automation.RuntimeDefinedParameter]::new($param.Name, $param.ParameterType, $param.Attributes)
            $paramDictionary.Add($param.Name, $dynParam)
        }

        return $paramDictionary
    }
    else
    {
        if ($null -eq $Parameters) { $Parameters = @{} }

        $cmdlet = & $SafeCommands['New-Object'] $command.ImplementingType.FullName

        $flags = [System.Reflection.BindingFlags]'Instance, Nonpublic'
        $context = $ExecutionContext.GetType().GetField('_context', $flags).GetValue($ExecutionContext)
        [System.Management.Automation.Cmdlet].GetProperty('Context', $flags).SetValue($cmdlet, $context, $null)

        foreach ($keyValuePair in $Parameters.GetEnumerator())
        {
            $property = $cmdlet.GetType().GetProperty($keyValuePair.Key)
            if ($null -eq $property -or -not $property.CanWrite) { continue }

            $isParameter = [bool]($property.GetCustomAttributes([System.Management.Automation.ParameterAttribute], $true))
            if (-not $isParameter) { continue }

            $property.SetValue($cmdlet, $keyValuePair.Value, $null)
        }

        try
        {
            # This unary comma is important in some cases.  On Windows 7 systems, the ActiveDirectory module cmdlets
            # return objects from this method which implement IEnumerable for some reason, and even cause PowerShell
            # to throw an exception when it tries to cast the object to that interface.

            # We avoid that problem by wrapping the result of GetDynamicParameters() in a one-element array with the
            # unary comma.  PowerShell enumerates that array instead of trying to enumerate the goofy object, and
            # everyone's happy.

            # Love the comma.  Don't delete it.  We don't have a test for this yet, unless we can get the AD module
            # on a Server 2008 R2 build server, or until we write some C# code to reproduce its goofy behavior.

            ,$cmdlet.GetDynamicParameters()
        }
        catch [System.NotImplementedException]
        {
            # Some cmdlets implement IDynamicParameters but then throw a NotImplementedException.  I have no idea why.  Ignore them.
        }
    }
}
