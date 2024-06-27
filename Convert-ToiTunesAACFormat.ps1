param
(
    [Parameter(Mandatory=$true)]
    [string[]]$Targets,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory=$false)]
    [bool]$CopyAlbumArts = $true,

    [Parameter(Mandatory=$false)]
    [switch]$Log = $false
)

function Find-RecursiveFiles
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $files = Get-ChildItem -Path $Path -Recurse | Where-Object {$_.extension -in ".wav", ".flac"}
    return $files
}

# Find QAAC
$qaac = (Get-Command -Name qaac -ErrorAction SilentlyContinue).Path
$qaac64 = (Get-Command -Name qaac64 -ErrorAction SilentlyContinue).Path
if ($null -eq $qaac -and $null -eq $qaac64)
{
    Write-Error "QAAC is not found. Please install QAAC first."
    exit
}

# Check architecture
if ([System.Environment]::Is64BitOperatingSystem -and $null -ne $qaac64)
{
    $qaac = $qaac64
}

$finalTargets = @()
# Check targets with for loop. If the target is not exist, remove from the list and skip
for ($i = $Targets.Count - 1; $i -ge 0; $i--)
{
    if (-not (Test-Path -Path $Targets[$i]))
    {
        Write-Warning "The target '$($Targets[$i])' is not found. Skip this target."
        continue
    }
    elseif ((Test-Path -Path $Targets[$i] -PathType Container))
    {
        $targets = Find-RecursiveFiles -Path (Resolve-Path -Path $Targets[$i]).Path
        foreach ($target in $targets)
        {
            $finalTargets += "`"{0}`"" -f $target
        }
    }
    elseif ((Test-Path -Path $Targets[$i] -PathType Leaf))
    {
        if ($targets[$i].extension -in ".wav", ".flac")
        {
            $finalTargets += "`"{0}`"" -f $Targets[$i]
        }
        else
        {
            Write-Warning "The target '$($Targets[$i])' is not a valid audio file for qaac. Skip this target."
        }
    }
}
$targetString = $finalTargets -join " "

if ($Log)
{
    $date = Get-Date -Format "yyyyMMdd_HHmmss"

    $LogFileBaseDir = Convert-Path -Path $OutputDirectory
    $LogFileName = Join-Path -Path $LogFileBaseDir -ChildPath ("qaac_" + $date + ".log")
    $LogOption = "--log `"$LogFileName`""
    Write-Output "Logfile location: $LogFileName"
    Write-Debug $LogFileName
}

# Execute QAAC with array input and shows processing output to console
$qaacCommand = "$qaac -v256 -q2 --copy-artwork --verbose $LogOption -d $OutputDirectory $targetString"
Write-Debug "The final Qaac command is:"
Write-Debug $qaacCommand
Invoke-Expression $qaacCommand
