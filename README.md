# Get-ADUserPropertyFrequencies.ps1
### SYNOPSIS
Analyze Active Directory users by frequency of assigned properties.
To answer questions like: *e.g., how many departments are in this AD and how many users are in each department?* <br>
Find out how many AD users are assigned a specific property like "AdminCount" or "PasswordNotRequired".<br>
Find out how many unique property assignments exist for a specific property.<br>
### DESCRIPTION
Analyze Active Directory users by frequency of assigned properties.
### SYNTAX
```Get-ADUserPropertyFrequencies.ps1 [[-Server] <String>] [<CommonParameters>]```
### PARAMETER Server
Mandatory. Specifies the Active Directory server domain to query.
### EXAMPLE
 ```Get-ADUserPropertyFrequencies.ps1 -Server CyberCondor.local```

# Main Object
```Get-ADUser -Server $Server -Filter * -Properties $Properties_AD | Select $Properties_AD```

---
# **Get-PropertyFrequencies**
The bread and butter of this script is the function **Get-PropertyFrequencies**<br>
This function takes two mandatory arguments ```([string]$Property, [PSObject]$Object)``` - given ```[string]$Property``` is an existing property in ```[PSObject]$Object```

### Logic
Get all unique values of a property found in the object<br>
Initialize a new object with a property of the specified property and a property of Count

For each unique value in all the unique values found for the property in the object,
- If unique value is found to be of type ```[DateTime]```, then take note for later
- Copy unique value to new object and set count to 0

If unique value of property found to be of type ```[DateTime]```, then change the format to "yyyy-MM". *This is done to actually receive useful information for analysis instead of compare included minutes.*

For each value in the object:
- Search through all unique values found in the object
	- If the value of the current object is equal to the current unique value, then add to Count

Return the new object that contains unique values, a count, and occurring frequency of those values found in the original object

### Code

```PowerShell
function Get-PropertyFrequencies($Property, $Object){
    $Total = ($Object).count
    $ProgressCount = 0
    $AllUniquePropertyValues = $Object | select $Property | sort $Property | unique -AsString # Get All Uniques
    $PropertyFrequencies = @()                                                                # Init empty Object
    $isDate = $false                                                                                                                                                          
    foreach($UniqueValue in $AllUniquePropertyValues){
        if(!($isDate -eq $true)){
            if([string]$UniqueValue.$Property -as [DateTime]){$isDate = $true}
        }
        $PropertyFrequencies += New-Object -TypeName PSobject -Property @{$Property=$($UniqueValue.$Property);Count=0;Frequency="100%"} # Copy Uniques to Object Array and Init Count as 0
    }
    if(($isDate -eq $true) -and (($Object | Select $Property | Get-Member).Definition -like "*datetime*")){
        foreach($PropertyFrequency in $PropertyFrequencies){
            if(($PropertyFrequency.$Property) -and ([string]$PropertyFrequency.$Property -as [DateTime])){
                try{$PropertyFrequency.$Property = $PropertyFrequency.$Property.ToString("yyyy-MM")}
                catch{# Nothing
                }
            }
        }
        foreach($PropertyName in $Object.$Property){                                                            # For each value in Object
            if($Total -gt 0){Write-Progress -id 1 -Activity "Finding $Property Frequencies -> ( $([int]$ProgressCount) / $Total )" -Status "$(($ProgressCount++/$Total).ToString("P")) Complete"}
            foreach($PropertyFrequency in $PropertyFrequencies){                                                # Search through all existing Property values
                if(($PropertyName -eq $null) -and ($PropertyFrequency -eq $null)){$PropertyFrequency.Count++}   # If Property value is NULL, then add to count - still want to track this
                elseif($PropertyName -ceq $PropertyFrequency.$Property){$PropertyFrequency.Count++}             # Else If Property value is current value, then add to count
                else{
                    try{if($PropertyName.ToString("yyyy-MM") -ceq $PropertyFrequency.$Property){$PropertyFrequency.Count++}}
                    catch{# Nothing
                    }
                }
            }
        }
    }
    else{
        foreach($PropertyName in $Object.$Property){                                                            # For each value in Object
            if($Total -gt 0){Write-Progress -id 1 -Activity "Finding $Property Frequencies -> ( $([int]$ProgressCount) / $Total )" -Status "$(($ProgressCount++/$Total).ToString("P")) Complete"}
            foreach($PropertyFrequency in $PropertyFrequencies){                                                # Search through all existing Property values
                if(($PropertyName -eq $null) -and ($PropertyFrequency -eq $null)){$PropertyFrequency.Count++}   # If Property value is NULL, then add to count - still want to track this
                elseif($PropertyName -ceq $PropertyFrequency.$Property){$PropertyFrequency.Count++}             # Else If Property value is current value, then add to count
            }
        }
    }
    Write-Progress -id 1 -Completed -Activity "Complete"
    if($Total -gt 0){
        foreach($PropertyFrequency in $PropertyFrequencies){$PropertyFrequency.Frequency = ($PropertyFrequency.Count/$Total).ToString("P")}
    }
    return $PropertyFrequencies | select Count,$Property,Frequency | sort Count,$Property | Unique -AsString
}
```
