$Global:DSCModuleName   = 'cWSMan'
$Global:DSCResourceName = 'BMD_cWSManListener'

#region HEADER
if ( (-not (Test-Path -Path '.\DSCResource.Tests\')) -or `
     (-not (Test-Path -Path '.\DSCResource.Tests\TestHelper.psm1')) )
{
    & git @('clone','https://github.com/PlagueHO/DscResource.Tests.git')
}
Import-Module .\DSCResource.Tests\TestHelper.psm1 -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Integration 
#endregion

# Using try/finally to always cleanup even if something awful happens.
try
{
    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($Global:DSCResourceName).config.ps1"
    . $ConfigFile

    Describe "$($Global:DSCResourceName)_Integration" {
        #region DEFAULT TESTS
        It 'Should compile without throwing' {
            {
                Invoke-Expression -Command "$($Global:DSCResourceName)_Config -OutputPath `$TestEnvironment.WorkingFolder"
                Start-DscConfiguration -Path $TestEnvironment.WorkingFolder -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            # Get the Rule details
            $Listeners = @(Get-WSManInstance `
                -ResourceURI winrm/config/Listener `
                -Enumerate)
            if ($Listeners)
            {
                $NewListener = $Listeners.Where( {$_.Transport -eq $Listener.Transport } )
            }
            $NewListener                    | Should Not Be $null
            $NewListener.Port               | Should Be $Listener.Port
            $NewListener.Address            | Should Be $Listener.Address
        }
        
        # Clean up
        Remove-WSManInstance `
            -ResourceURI winrm/config/Listener `
            -SelectorSet @{ Transport=$Listener.Transport;Address=$Listener.Address }
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}