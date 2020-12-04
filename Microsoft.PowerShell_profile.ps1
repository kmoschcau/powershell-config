# vim: foldmethod=marker

# Load modules {{{1
Import-Module posh-git
Import-Module posh-sshell

# Automatically start the SSH agent
# This does not seem to work!
# Start-SshAgent -Quiet

# options {{{1
# PSReadLine {{{2

# Change the edit mode to Vi
Set-PSReadLineOption -EditMode Vi

# Set the text to change color in the prompt on syntax error
Set-PSReadLineOption -PromptText '> '

# Set the indicator style for Vi normal mode
# TODO: figure this out later
# Set-PSReadLineOption -ViModeIndicator 'Script'

# Enable auto suggestions like in fish
try {
  Set-PSReadLineOption -PredictionSource History
} catch [System.Management.Automation.ParameterBindingException] {
  # This means we deal with a version where this is not supported, just ignore it
}

# theming {{{1
# helper functions {{{2
function Pr_CssColorToSGRParameters {
  Param ([string]$CssColor)

  $MatchResult = [Regex]::Matches($CssColor, '^#([0-9a-fA-F]{2}){3}$')

  if (!$MatchResult.Success) {
    Write-Error "Not a valid CSS color: $CssColor"
  }

  $Red   = [uint32]"0x$($MatchResult.Groups[1].Captures[0])"
  $Green = [uint32]"0x$($MatchResult.Groups[1].Captures[1])"
  $Blue  = [uint32]"0x$($MatchResult.Groups[1].Captures[2])"

  "2;$Red;$Green;$Blue"
}

function Pr_Fg {
  Param ([string]$CssColor)

  "$([char]0x1b)[38;$(Pr_CssColorToSGRParameters($CssColor))m"
}

function Pr_Bg {
  Param ([string]$CssColor)

  "$([char]0x1b)[48;$(Pr_CssColorToSGRParameters($CssColor))m"
}

function Pr_Bold {
  "$([char]0x1b)[1m"
}

function Pr_Italic {
  "$([char]0x1b)[3m"
}

# color definitions {{{2
$Pink = '#ff00ff'
$Black = '#000000'

$Red500        = '#f44336'
$Blue50        = '#e3f2fd'
$Blue500       = '#2196f3'
$Blue600       = '#1e88e5'
$Cyan100       = '#b2ebf2'
$Teal500       = '#009688'
$Green50       = '#e8f5e9'
$Green500      = '#4caf50'
$Green600      = '#43a047'
$LightGreen500 = '#8bc34a'
$Yellow500     = '#ffeb3b'
$Orange500     = '#ff9800'
$Orange600     = '#fb8c00'
$Grey50        = '#fafafa'
$Grey400       = '#bdbdbd'
$Grey500       = '#9e9e9e'
$Grey700       = '#616161'

$Test = "$(Pr_Fg($Pink))$(Pr_Bg($Black))"
$Default = 'white'

# syntax colors {{{2
Set-PSReadLineOption -Colors @{
  Command = Pr_Fg($Teal500)
  Comment = Pr_Fg($Grey500)
  ContinuationPrompt = Pr_Fg($Grey400)
  Default = Pr_Fg($Grey700)
  Emphasis = Pr_Bg($Yellow500)
  Error = "$(Pr_Fg($Grey50))$(Pr_Bg($Red500))"
  InlinePrediction = Pr_Fg($Grey500)
  Keyword = "$(Pr_Bold)$(Pr_Fg($Orange600))"
  Member = Pr_Fg($Blue500)
  Number = "$(Pr_Fg($Blue600))$(Pr_Bg($Blue50))"
  Operator = Pr_Fg($Orange600)
  Parameter = "$(Pr_Italic)$(Pr_Fg($Orange500))"
  Selection = Pr_Bg($Cyan100)
  String = "$(Pr_Fg($Green600))$(Pr_Bg($Green50))"
  Type = Pr_Fg($Green500)
  Variable = Pr_Fg($LightGreen500)
}

# host private data colors {{{2
if ($PSVersionTable.PSVersion.Major -ge 7) {
  (Get-Host).PrivateData.FormatAccentColor       = 'Green'
  (Get-Host).PrivateData.ErrorAccentColor        = 'Cyan'
}
(Get-Host).PrivateData.ErrorForegroundColor    = 'White'
(Get-Host).PrivateData.ErrorBackgroundColor    = 'DarkRed'
(Get-Host).PrivateData.WarningForegroundColor  = 'White'
(Get-Host).PrivateData.WarningBackgroundColor  = 'DarkYellow'
(Get-Host).PrivateData.DebugForegroundColor    = 'Yellow'
(Get-Host).PrivateData.DebugBackgroundColor    = 'Black'
(Get-Host).PrivateData.VerboseForegroundColor  = 'Yellow'
(Get-Host).PrivateData.VerboseBackgroundColor  = 'Black'
(Get-Host).PrivateData.ProgressForegroundColor = 'Black'
(Get-Host).PrivateData.ProgressBackgroundColor = 'Cyan'

# Clean up {{{2
Remove-Item 'Function:Pr_*'

# Prompt {{{1
if ($env:TERM -match '^xterm-256color' -and $PSVersionTable.PSVersion.Major -ge 6) {
  $SeparatorChar = ""
} else {
  $SeparatorChar = ">"
}

Set-PSReadLineOption -ContinuationPrompt "$SeparatorChar"
