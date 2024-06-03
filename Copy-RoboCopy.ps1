param
(
    [Parameter(Mandatory=$true)]
    [string]$source,
    
    [Parameter(Mandatory=$true)]
    [string]$destination,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFileLocation = $null,

    [Parameter(Mandatory=$false)]
    [switch]$NewDestSubDir = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SameSrcNameDir = $false,

    [Parameter(Mandatory=$false)]
    [switch]$OpenDestDirAfterCopy = $false,

    [Parameter(Mandatory=$false)]
    [switch]$RemoveSrcDirAfterCopy = $false,

    [Parameter(Mandatory=$false)]
    [switch]$PreserveDesktopIniFile = $false,

    [Parameter(Mandatory=$false)]
    [switch]$KeepActiveCodePage = $false
)

function Get-ThreadCountForCopy()
{
    $threadCount = (Get-CimInstance -Class Win32_ComputerSystem).NumberOfLogicalProcessors

    if ($threadCount -lt 8)
    {
        $threadCount = 8
    }

    return $threadCount
}

function Get-ActiveCodePage()
{
    if (!((chcp) -match '(?<cp>\d+)'))
    {
        Write-Error -Message "Failed to get active code page." `
        -Category InvalidOperation `

        Write-Warning "Try to change code page to 65001 (UTF-8)"
        chcp 65001

        return "65001"
    }

    Write-Debug "Active code page: $($Matches.cp)"
    return $Matches.cp
}

if ((Get-ActiveCodePage) -ne "65001")
{
    Write-Warning "Your active code page is not UTF-8."
    
    if (!$KeepActiveCodePage)
    {
        Write-Warning "Changing code page to 65001 (UTF-8)"
        chcp 65001
    }
}

# Check OS of the machine
if (!$IsWindows)
{
    Write-Error -Message "This script is only supported on Windows because of Robocopy." `
    -Category InvalidOperation `
    -RecommendedAction "Run this script on Windows machine."
    exit
}

# Check PowerShell version; This script requires PowerShell 5.1 or later
if ($PSVersionTable.PSVersion.Major -lt 5 -or `
($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1))
{
    Write-Error -Message "This script requires PowerShell version 5.1 or later." `
    -Category InvalidOperation `
    -RecommendedAction "Update PowerShell to version 5.1 or later. We recommend to use the latest version of PowerShell."
    exit
}

if ($NewDestSubDir -and $SameSrcNameDir)
{
    Write-Error -Message "Cannot use both NewDestSubDir and SameSrcNameDir switches." `
    -Category InvalidOperation `
    -RecommendedAction "Use either NewDestSubDir or SameSrcNameDir switch."
    exit
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

if (!(Test-Path -Path $source))
{
    Write-Error -Message "Source path does not exist." `
    -Category ObjectNotFound `
    -RecommendedAction "Check the source path."
    exit
}

# if (!(Test-Path -Path $destination) -and $NewDestSubDir -eq $false)
# {
#     Write-Host "Destination path does not exist."
#     exit
# }
# elseif ((Test-Path -Path $destination) -and $NewDestSubDir)
# {
#     New-Item -Type Directory -Path $destination
# }

if (!(Test-Path -Path $destination))
{
    New-Item -Type Directory -Path $destination
}

if ($NewDestSubDir)
{
    $destination += "\copied_$($timestamp)\"
    New-Item -Type Directory -Path $destination
}
Write-Debug "Destination: $($destination)"

if ($SameSrcNameDir)
{
    $destination += "\$((Get-Item $source).Name)"
    New-Item -Type Directory -Path $destination
}

if ($LogFileLocation -eq "")
{
    $LogFileLocation = "$($destination)\log_$($timestamp).txt"
}

Write-Host $LogFileLocation

## TODO: We need to workaround log file encoding bug in RoboCopy

Write-Host "Start copying $($source) to $($destination) with log file $($LogFileLocation)"

Robocopy.exe $source $destination *.* `
    /e `
    /zb `
    /j `
    /copy:DATS `
    /dcopy:DATE `
    /a-:R `
    /pf `
    /mt:"$(Get-ThreadCountForCopy)" `
    /xa:ST `
    /xd "System Volume Information" `
    /r:1000000 `
    /w:300 `
    /v `
    /ts `
    /eta `
    /unilog:"$($LogFileLocation)" `
    /tee `
    /unicode

$robocopyExitCode = $LASTEXITCODE
Write-Debug "Robocopy returned exit code $($robocopyExitCode)"

# Re-save Log file to UTF-8
Write-Debug "Opening $($LogFileLocation) for UTF-8 without BOM re-encoding."
$logFileContent = Get-Content -Path $LogFileLocation -Encoding unicode

Write-Debug "Saving $($LogFileLocation) with UTF-8 (No BOM)"
$logFileContent | Set-Content -Path $LogFileLocation -Encoding utf8NoBOM

if ($robocopyExitCode -ge 8)
{
    Write-Error -Message "Robocopy may encountered fatal errors. Please make sure to check log file created. All source files will NOT be deleted." `
    -Category InvalidOperation `
    -RecommendedAction "Check the log file on $($destination)"
    exit
}

if ($OpenDestDirAfterCopy)
{
    Write-Debug "Opening $($destination)"
    Start-Process $destination
}
