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
    [switch]$PreserveDesktopIniFile = $false
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

if ($OpenDestDirAfterCopy)
{
    Write-Debug "Opening $($destination)"
    Start-Process $destination
}
