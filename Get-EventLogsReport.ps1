Function Get-EventLogsReport {
<#
.SYNOPSIS
    Gets the event logs for the specified computers.
.DESCRIPTION
    This function gets the specified event logs for the specified computers.
    It will obtain the Error and Warning entry types for the specified previous
    number of hours.
.PARAMETER Hours
    Specify the number of hours to go back through logs for the report.
.PARAMETER LogName
    Specify the Event Log(s) to search through.  Example:  Application,System
.PARAMETER NoRemoting
    Switch parameter, performs search without using PSRemoting.
.PARAMETER ErrorLog
    Sepcifies the location and name of error log.  Defaults to C:\ELRerrors.txt.
.NOTES
    Version                 :  0.5
    Author                  :  @sukotto_san
    Disclaimer              :  If you run it, you take all responsibility for it.
#>
    [CmdletBinding()]

    param(
        [int]$Hours = 24,
        [string[]]$ComputerName,
        [string[]]$LogName,
        [switch]$NoRemoting = $False,
        [string]$ErrorLog = 'C:\ELRerrors.txt'
    )

    Begin {
        $AfterHours = (Get-Date).AddHours(-$Hours)
        $ErrorMessage = 'There was some error.  No con permiso.'
        Out-File -FilePath $ErrorLog -Append -InputObject ((Get-Date -Format g) + ' - Get-EventLogsReport Logging started: ' + $ErrorLog )

        if ($NoRemoting -eq $True) {
            Write-Verbose 'No remoting'
            Write-Warning 'This could take a very long time depending on the number of servers being queried...'
            foreach($computer in $ComputerName){
                foreach ($log in $LogName){
                    Try{
                        Write-Verbose "Getting $Log log on $Computer"
                        $EventLogs = Get-EventLog -LogName $Log -ComputerName $computer -EntryType Error,Warning -After $AfterHours -ErrorVariable LogError -ErrorAction SilentlyContinue
                        foreach ($event in $EventLogs){
                            Write-Verbose 'Creating object'
                            $prop = @{
                                'Category' = $event.Category
                                'CategoryNumber' = $event.CategoryNumber
                                'Container' = $event.Container
                                'Data' = $event.Data
                                'EntryType' = $event.EntryType
                                'Index' = $event.Index
                                'InstanceId' = $event.InstanceId
                                'MachineName' = $event.MachineName
                                'Message' = $event.Message
                                'ReplacementStrings' = $event.ReplacementStrings
                                'Site' = $event.Site
                                'Source' = $event.Source
                                'TimeGenerated' = $event.TimeGenerated
                                'TimeWritten' = $event.TimeWritten
                                'UserName' = $event.UserName
                                'EventID' = $event.EventID
                                'LogName' = $Log
                            }
                            $object = New-Object -TypeName PSObject -Property $prop
                            Write-Output $object
                        }
                    }
                    Catch {
                        Write-Verbose $ErrorMessage
                        $ErrorInfo = (Get-Date -Format g) + " - $Computer " + '- ' + $log + ' - ' + $LogError.Message 
                        Out-File -FilePath $ErrorLog -Append -InputObject $ErrorInfo
                    }
                }
            }
        }
        else {
            Write-Verbose 'Remoting'
            foreach ($log in $LogName){
                foreach ($computer in $ComputerName) {
                    Try {
                        Write-Verbose "Getting $Log from $computer"
                        $EventLogs = Invoke-Command -ComputerName $computer -ArgumentList $AfterHours,$log -ScriptBlock { 
                            param($ah,$l) Get-EventLog -LogName $l -EntryType Error,Warning -After $ah
                        } -ErrorVariable LogError -ErrorAction SilentlyContinue

                        if ($LogError) {
                            Write-Verbose $ErrorMessage
                            $ErrorInfo = (Get-Date -Format g) + " - $computer" + ' - ' + $log + ' - ' + $LogError.ErrorDetails.Message + ' - If statement'
                            Out-File -FilePath $ErrorLog -Append -InputObject $ErrorInfo
                        }

                        foreach ($event in $EventLogs){
                            Write-Verbose 'Creating object'
                            $prop = @{
                                'Category' = $event.Category
                                'CategoryNumber' = $event.CategoryNumber
                                'Container' = $event.Container
                                'Data' = $event.Data
                                'EntryType' = $event.EntryType
                                'Index' = $event.Index
                                'InstanceId' = $event.InstanceId
                                'MachineName' = $event.MachineName
                                'Message' = $event.Message
                                'ReplacementStrings' = $event.ReplacementStrings
                                'Site' = $event.Site
                                'Source' = $event.Source
                                'TimeGenerated' = $event.TimeGenerated
                                'TimeWritten' = $event.TimeWritten
                                'UserName' = $event.UserName
                                'EventID' = $event.EventID
                                'LogName' = $Log
                            }
                            $object = New-Object -TypeName PSObject -Property $prop
                            Write-Output $object
                        }
                    }
                    Catch {
                        Write-Verbose $ErrorMessage
                        $ErrorInfo = (Get-Date -Format g) + " - $computer" + ' - ' + $log + ' - ' + $LogError.ErrorDetails.Message 
                        Out-File -FilePath $ErrorLog -Append -InputObject $ErrorInfo
                    }
                }
            }
        }
        


    }

    Process {}
    End {
        Out-File -FilePath $ErrorLog -Append -InputObject ((Get-Date -Format g) + ' - Get-EventLogsReport Logging finished: ' + $ErrorLog )
    }

}