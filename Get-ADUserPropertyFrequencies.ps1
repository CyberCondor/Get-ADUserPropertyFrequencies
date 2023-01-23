<#
.SYNOPSIS
To answer questions like -> e.g., how many departments are in this AD and how many users are in each department?
Analyze Active Directory users by frequency of assigned properties. 
Find out how many AD users are assigned a specifc property like "AdminCount" or "PasswordNotRequired".
Find out how many unique property assignments exist for a specific property.
.DESCRIPTION
Analyze Active Directory users by frequency of assigned properties.
.PARAMETER Server
Specifies the Active Directory server domain to query.
.EXAMPLE
PS C:\> Get-ADUserPropertyFrequencies.ps1 -Server CyberCondor.local
#>
param(
    [Parameter(mandatory=$True, Position=0, ValueFromPipeline=$false)]
    [system.String]$Server
)
Write-Host "`n`t`tAttempting to query Active Directory.'n" -BackgroundColor Black -ForegroundColor Yellow
try{Get-ADUser -server $Server -filter 'Title -like "*Admin*"' > $null -ErrorAction stop
}
catch{$errMsg = $_.Exception.message
    if($errMsg.Contains("is not recognized as the name of a cmdlet")){
        Write-Warning "`t $_.Exception"
        Write-Output "Ensure 'RSAT Active Directory DS-LDS Tools' are installed through 'Windows Features' & ActiveDirectory PS Module is installed"
    }
    elseif($errMsg.Contains("Unable to contact the server")){
        Write-Warning "`t $_.Exception"
        Write-Output "Check server name and that server is reachable, then try again."
    }
    else{Write-Warning "`t $_.Exception"}
    break
}

function Get-ExistingUsers_AD{
    try{$ExistingUsers = Get-ADUser -Server $Server -Filter * -Properties $Properties_AD | Select $Properties_AD -ErrorAction Stop
        return $ExistingUsers
    }
    catch{$errMsg = $_.Exception.message
        Write-Warning "`t $_.Exception"
        return $null
    }
}
function Get-UserRunningThisProgram($ExistingUsers_AD){
    foreach($ExistingUser in $ExistingUsers_AD){
        if($ExistingUser.SamAccountName -eq $env:UserName){return $ExistingUser}
    }
    Write-Warning "User Running this program not found."
    return $null
}
function SanitizeManagerPropertyFormat($ExistingUsers_AD){
    foreach($ExistingUser in $ExistingUsers_AD){
        [string]$UnsanitizedName = $ExistingUser.Manager
        $NameSanitized = $false
        if(($UnsanitizedName -ne $null) -and ($UnsanitizedName -ne "") -and ($UnsanitizedName -ne "`n") -and ($UnsanitizedName -match '[a-zA-Z]') -and ($UnsanitizedName.Length -ne 1)){
            $index = 0
            while($NameSanitized -eq $false){
                $SanitizedName = $ExistingUser.Manager.Substring(3,$index++)
                if($ExistingUser.Manager[$index] -eq ','){
                    $ExistingUser.Manager = $SanitizedName.Substring(0,$SanitizedName.Length - 2)
                    $NameSanitized = $true
                }
            }
        }
        else{$ExistingUser.Manager = "NULL"}
    }
}

function Get-PropertyFrequencies($Property, $Object){
    $Total = ($Object).count
    $ProgressCount = 0
    $AllUniquePropertyValues = $Object | select $Property | sort $Property | unique -AsString # Get All Uniques
    $PropertyFrequencies = @()                                                                # Init empty Object
    $isDate = $false                                                                                                                                                          
    foreach($UniqueValue in $AllUniquePropertyValues){
        if(!($isDate -eq $true)){
            if([string]$UniqueValue.$Property -as [DateTime]){
                $isDate = $true
            }
        }
        $PropertyFrequencies += New-Object -TypeName PSobject -Property @{$Property=$($UniqueValue.$Property);Count=0} # Copy Uniques to Object Array and Init Count as 0
    }
    if($isDate -eq $true){
        foreach($PropertyFrequency in $PropertyFrequencies){
            if(($PropertyFrequency.$Property) -and ([string]$PropertyFrequency.$Property -as [DateTime])){
                try{$PropertyFrequency.$Property = $PropertyFrequency.$Property.ToString("yyyy-MM")
                }
                catch{# Catch Nothing
                }
            }
        }
        foreach($PropertyName in $Object){
            if(($PropertyName.$Property) -and ([string]$PropertyName.$Property -as [DateTime])){
                try{$PropertyName.$Property = $PropertyName.$Property.ToString("yyyy-MM")
                }
                catch{# Catch Nothing
                }
            }
        }
    }
    foreach($PropertyName in $Object.$Property){                                                            # For each value in Object
        Write-Progress -id 1 -Activity "Finding $Property Frequencies -> ( $([int]$ProgressCount) / $Total )" -Status "$(($ProgressCount++/$Total).ToString("P")) Complete"
        foreach($PropertyFrequency in $PropertyFrequencies){                                                # Search through all existing Property values
            if(($PropertyName -eq $null) -and ($PropertyFrequency -eq $null)){$PropertyFrequency.Count++}   # If Property value is NULL, then add to count - still want to track this
            elseif($PropertyName -ceq $PropertyFrequency.$Property){$PropertyFrequency.Count++}             # Else If Property value is current value, then add to count
        }
    }
    Write-Progress -id 1 -Completed -Activity "Complete"
    
    return $PropertyFrequencies
}
function DisplayFrequencies($Property, $PropertyFrequencies){
    write-output "`n"
    $PropertyFrequencies | select Count,$Property | sort Count,$Property | unique -AsString | ft
    write-output "Total Number of Unique $($Property)(s): $(($PropertyFrequencies | select $Property,Count | sort Count,$Property | unique -AsString ).count)"
}

function main{
    $quitProgram = $false

    While($quitProgram -eq $false){
        write-Host "`n Active Directory USER Properties available to query:"
        foreach($Property in $Properties_AD){Write-Host "`t$Property"}

        $Property = Read-Host "`nEnter one of the properties listed above or 'q' to quit"

        $found = $false
        foreach($P in $Properties_AD){if($P -eq $Property){$found = $true}}
        if($found -eq $true){
            $Frequencies = Get-PropertyFrequencies $Property $ExistingUsers_AD
            DisplayFrequencies $Property $Frequencies 
            Read-Host "`nPress Enter for Main Menu"
            clear
        }
        elseif($Property -eq "q"){$quitProgram = $true}
        else{Write-Output "`nProperty '$Property' is not found in the list of properties available to query. `n"}
    }
}

$Properties_AD = @("Name",
                   "GivenName",
                   "Surname",
                   "DisplayName",
                   "SamAccountName",
                   "Division",
                   "telephoneNumber",
                   "Department",
                   "Title",
                   "Office",
                   "Description",
                   "Manager",
                   "Enabled",
                   "LockedOut",
                   "whenCreated",
                   "whenChanged",
                   "AccountExpirationDate",
                   "Deleted",             
                   "sDRightsEffective",                
                   "SIDHistory",                  
                   "Certificates",
                   "isCriticalSystemObject",
                   "SmartcardLogonRequired",
                   "TrustedForDelegation",
                   "TrustedToAuthForDelegation",
                   "ProtectedFromAccidentalDeletion",
                   "MNSLogonAccount",
                   "AllowReversiblePasswordEncryption",
                   "AuthenticationPolicy",
                   "logonCount"
                   "LastLogonDate",
                   "lastLogoff",
                   "LastBadPasswordAttempt",
                   "BadLogonCount",
                   "badPwdCount",
                   "badPasswordTime",
                   "CannotChangePassword",
                   "DoesNotRequirePreAuth",
                   "PasswordLastSet",
                   "PasswordExpired",
                   "PasswordNeverExpires",
                   "PasswordNotRequired",
                   "adminCount",
                   "ScriptPath")

$ExistingUsers_AD = Get-ExistingUsers_AD
if($ExistingUsers_AD -eq $null){break}
$UserRunningThisProgram = Get-UserRunningThisProgram $ExistingUsers_AD
if($UserRunningThisProgram -eq $null){
    Write-Host "`n`t`tHello 'STRANGER' I could not find you in this Active Directory Domain...`n"
}
else{Write-Host "`n`t`tHello '$($UserRunningThisProgram.Name) ($($UserRunningThisProgram.Title))'!" -ForegroundColor Green}

Write-Host "This program will display various property frequencies from 'AD Users'`n"

SanitizeManagerPropertyFormat $ExistingUsers_AD

main