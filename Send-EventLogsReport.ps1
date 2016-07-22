Function Send-EventLogsReport {
<#
.SYNOPSIS
    Sends the report.
.DESCRIPTION
    This function will 'send' the report based on the appropriate switches
    and parameters.  It will also allow for filtering based on specified
    events.  See the specific parameters for details.
.PARAMETER InputObject
    Required paremeter, accepts input from Get-EventLogsReport.
.PARAMETER BlockSourceEventID
    Used to block a specific Source and Event ID combination.
.PARAMETER BlockSource
    Used to block a specific Source.
.PARAMETER BlockEventID
    Used to block a specific Event ID.
.PARAMETER To
    Specifies the recipient email address.
.PARAMETER From
    Specifies the sending email address.
.PARAMETER SmtpServer
    Specifies the SMTP server to be used.
.NOTES
    Version                 :  0.5
    Author                  :  @sukotto_san
    Disclaimer              :  If you run it, you take all responsibility for it.
    Thanks!                 :  @Ben0xA for the assist on the 'blacklist' component
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$true)]$InputObject,
        [string[]]$BlockSourceEventID, #= @('VMware Tools:1000'),
        [string]$BlockSource,
        $BlockEventID,
        [switch]$OutputFile,
        [string]$To,
        [string]$From,
        [string]$SmtpServer,
        [string]$ErrorLog = "C:\ELRerrors.txt"

    )

    Begin {
        Out-File -FilePath $ErrorLog -Append -InputObject ((Get-Date -Format g) + " - Send-EventLogsReport Logging started: " + $ErrorLog)
        $Events = @()
        $ErrorEvents = @()
        $WarningEvents = @()

    }

    Process {
        
        if (($BlockSource -contains $InputObject.Source) -or
            ($BlockEventID -contains $InputObject.EventID) -or
            ($BlockSourceEventID -contains $InputObject.Source + ":" + $InputObject.EventID)
        ) {
            Write-Verbose 'Pattern matched, skipping event.'
        }
        else {
            $Events += $InputObject
            if ( $InputObject.EntryType -like "Error" ) {
                Write-Verbose 'Event is an Error'
                $ErrorEvents += $InputObject
            }
            elseif ( $InputObject.EntryType -like "Warning" ) {
                Write-Verbose 'Event is a Warning'
                $WarningEvents += $InputObject
            }
            else{
                Write-Verbose 'Should not see this, but doing nothing if you do.'
            }
        }
    }
    
    End {

        $ErrorEvents = $ErrorEvents | Sort-Object -Property MachineName,Message -Unique | Select-Object -Property MachineName,LogName,EntryType,EventID,Source,Message
        $WarningEvents = $WarningEvents | Sort-Object -Property MachineName,Message -Unique | Select-Object -Property MachineName,LogName,EntryType,EventID,Source,Message
        $GroupedEvents = $Events | Group-Object -Property Message -NoElement | Select-Object -Property Count,Name | Sort-Object -Property Count -Descending

        $ErrorEventsHTML = $ErrorEvents | ConvertTo-Html -Fragment -PreContent '<H3>ERROR Events</H3>' | Out-String
        $WarningEventsHTML = $WarningEvents | ConvertTo-Html -Fragment -PreContent '<H3>WARNING Events</H3>' | Out-String
        $GroupedEventsHtml = $GroupedEvents | ConvertTo-Html -Fragment -PreContent '<H3>GROUPED Events</H3>' | Out-String

        $FooterHtml = ConvertTo-Html -Fragment -PostContent "<h6>This report was run from:  $env:COMPUTERNAME on $(Get-Date)</h6>" | Out-String
 
        $css = '<style>
            table { width:98%; }
            td { text-align:center; padding:5px; }
            th { background-color:blue; color:white; }
            h3 { text-align:center; color:blue }
            h4 { text-align:center }
            h6 { text-align:center }
            </style>'
        
        Write-Verbose 'Writing report...'

        if ($OutputFile -eq $True) {
            Try {
                $Report = ConvertTo-Html -Title "Server Event Logs Report" -Body "$ErrorEventsHTML $WarningEventsHTML $GroupedEventsHtml $FooterHtml $css" | 
                Out-File C:\Scripts\Events.html -ErrorAction Continue -ErrorVariable LogError

                Write-Verbose "HTML report available at C:\Scripts\Events.html"
            }
            Catch {
                $ErrorInfo = (Get-Date -Format g) + " - $computer" + " - " + $log + " - " + $LogError.ErrorDetails.Message 
                Out-File -FilePath $ErrorLog -Append -InputObject $ErrorInfo                
            }
        }
        else {
            Try {
                $Report = ConvertTo-Html -Title "Server Event Logs Report" -Body "$ErrorEventsHTML $WarningEventsHTML $GroupedEventsHtml $FooterHtml $css" |
                Out-File $env:TEMP\Events.html 
                Out-File -FilePath $ErrorLog -Append -InputObject ((Get-Date -Format g) + " - Send-EventLogsReport Logging finished: " + $ErrorLog)

                Send-MailMessage `
                    -To $To `
                    -From $From `
                    -SmtpServer $SmtpServer `
                    -Subject "Server Event Log Report" `
                    -Body "Please find attached the requested report." `
                    -Attachments "$env:TEMP\Events.html",$ErrorLog `
                    -ErrorAction Continue `
                    -ErrorVariable LogError

                Write-Verbose "HTML report available at $env:TEMP\Events.html." 
                Write-Verbose "Error log cleanup."
                Remove-Item $ErrorLog         

            }
            Catch {
                $ErrorInfo = (Get-Date -Format g) + " - $computer" + " - " + $log + " - " + $LogError.ErrorDetails.Message 
                Out-File -FilePath $ErrorLog -Append -InputObject $ErrorInfo
                Out-File -FilePath $ErrorLog -Append -InputObject ((Get-Date -Format g) + " - Send-EventLogsReport Logging finished: " + $ErrorLog)
                Write-Error "Errors encountered. File located at $ErrorLog."
            }
        }
    }

}