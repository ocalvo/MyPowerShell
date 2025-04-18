
using namespace System.Management.Automation
using namespace System.Collections.ObjectModel
function Add-Theme {
    [cmdletbinding(DefaultParameterSetName = 'Path', SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName  = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [switch]$Force,

        [ValidateSet('Color', 'Icon')]
        [Parameter(Mandatory)]
        [string]$Type
    )

    process {
        # Resolve path(s)
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $paths = Resolve-Path -Path $Path | Select-Object -ExpandProperty Path
        } elseif ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
            $paths = Resolve-Path -LiteralPath $LiteralPath | Select-Object -ExpandProperty Path
        }

        foreach ($resolvedPath in $paths) {
            if (Test-Path $resolvedPath) {
                $item = Get-Item -LiteralPath $resolvedPath

                $statusMsg  = "Adding $($type.ToLower()) theme [$($item.BaseName)]"
                $confirmMsg = "Are you sure you want to add file [$resolvedPath]?"
                $operation  = "Add $($Type.ToLower())"
                if ($PSCmdlet.ShouldProcess($statusMsg, $confirmMsg, $operation) -or $Force.IsPresent) {
                    if (-not $script:userThemeData.Themes.$Type.ContainsKey($item.BaseName) -or $Force.IsPresent) {

                        $theme = Import-PowerShellDataFile $item.FullName

                        # Convert color theme into escape sequences for lookup later
                        if ($Type -eq 'Color') {
                            # Add empty color theme
                            if (-not $script:colorSequences.ContainsKey($theme.Name)) {
                                $script:colorSequences[$theme.Name] = New-EmptyColorTheme
                            }

                            # Directories
                            $theme.Types.Directories.WellKnown.GetEnumerator().ForEach({
                                $script:colorSequences[$theme.Name].Types.Directories[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
                            })
                            # Wellknown files
                            $theme.Types.Files.WellKnown.GetEnumerator().ForEach({
                                $script:colorSequences[$theme.Name].Types.Files.WellKnown[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
                            })
                            # File extensions
                            $theme.Types.Files.GetEnumerator().Where({$_.Name -ne 'WellKnown'}).ForEach({
                                $script:colorSequences[$theme.Name].Types.Files[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
                            })
                        }

                        $script:userThemeData.Themes.$Type[$theme.Name] = $theme
                        Save-Theme -Theme $theme -Type $Type
                    } else {
                        Write-Error "$Type theme [$($theme.Name)] already exists. Use the -Force switch to overwrite."
                    }
                }
            } else {
                Write-Error "Path [$resolvedPath] is not valid."
            }
        }
    }
}
function ConvertFrom-ColorEscapeSequence {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Sequence
    )

    process {
        # Example input sequence: 'e[38;2;135;206;250m'
        $arr = $Sequence.Split(';')
        $r   = '{0:x}' -f [int]$arr[2]
        $g   = '{0:x}' -f [int]$arr[3]
        $b   = '{0:x}' -f [int]$arr[4].TrimEnd('m')

        ($r + $g + $b).ToUpper()
    }
}
function ConvertFrom-RGBColor {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$RGB
    )

    process {
        $RGB = $RGB.Replace('#', '')
        $r   = [convert]::ToInt32($RGB.SubString(0,2), 16)
        $g   = [convert]::ToInt32($RGB.SubString(2,2), 16)
        $b   = [convert]::ToInt32($RGB.SubString(4,2), 16)

        "${script:escape}[38;2;$r;$g;$b`m"
    }
}
function ConvertTo-ColorSequence {
    [cmdletbinding()]
    param(
        [parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$ColorData
    )

    process {
        $cs      = New-EmptyColorTheme
        $cs.Name = $ColorData.Name

        # Directories
        if ($ColorData.Types.Directories['symlink']) {
            $cs.Types.Directories['symlink']  = ConvertFrom-RGBColor -RGB $ColorData.Types.Directories['symlink']
        }
        if ($ColorData.Types.Directories['junction']) {
            $cs.Types.Directories['junction'] = ConvertFrom-RGBColor -RGB $ColorData.Types.Directories['junction']
        }
        $ColorData.Types.Directories.WellKnown.GetEnumerator().ForEach({
            $cs.Types.Directories[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
        })

        # Wellknown files
        if ($ColorData.Types.Files['symlink']) {
            $cs.Types.Files['symlink']  = ConvertFrom-RGBColor -RGB $ColorData.Types.Files['symlink']
        }
        if ($ColorData.Types.Files['junction']) {
            $cs.Types.Files['junction'] = ConvertFrom-RGBColor -RGB $ColorData.Types.Files['junction']
        }
        $ColorData.Types.Files.WellKnown.GetEnumerator().ForEach({
            $cs.Types.Files.WellKnown[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
        })

        # File extensions
        $ColorData.Types.Files.GetEnumerator().Where({$_.Name -ne 'WellKnown' -and $_.Name -ne ''}).ForEach({
            $cs.Types.Files[$_.Name] = ConvertFrom-RGBColor -RGB $_.Value
        })

        $cs
    }
}
function Get-ThemeStoragePath {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    if ($IsLinux -or $IsMacOs) {
        if (-not ($basePath = $env:XDG_CONFIG_HOME)) {
            $basePath = [IO.Path]::Combine($HOME, '.local', 'share')
        }
    } else {
        if (-not ($basePath = $env:APPDATA)) {
            $basePath = [Environment]::GetFolderPath('ApplicationData')
        }
    }

    if ($basePath) {
        $storagePath = [IO.Path]::Combine($basePath, 'powershell', 'Community', 'Terminal-Icons')
        if (-not (Test-Path $storagePath)) {
            New-Item -Path $storagePath -ItemType Directory -Force > $null
        }
        $storagePath
    }
}
function Import-ColorTheme {
    [OutputType([hashtable])]
    [cmdletbinding()]
    param()

    $hash = @{}
    (Get-ChildItem -Path $moduleRoot/Data/colorThemes).ForEach({
        $colorData = Import-PowerShellDataFile $_.FullName
        $hash[$colorData.Name] = $colorData
        $hash[$colorData.Name].Types.Directories[''] = $colorReset
        $hash[$colorData.Name].Types.Files['']       = $colorReset
    })
    $hash
}
function Import-IconTheme {
    [OutputType([hashtable])]
    [cmdletbinding()]
    param()

    $hash = @{}
    (Get-ChildItem -Path $moduleRoot/Data/iconThemes).ForEach({
        $hash.Add($_.Basename, (Import-PowerShellDataFile $_.FullName))
    })
    $hash
}
function Import-Preferences {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [OutputType([hashtable])]
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]
        [string]$Path = (Join-Path (Get-ThemeStoragePath) 'prefs.xml'),

        [string]$DefaultThemeName = $script:defaultTheme
    )

    begin {
        $defaultPrefs = @{
            CurrentColorTheme = $DefaultThemeName
            CurrentIconTheme  = $DefaultThemeName
        }
    }

    process {
        if (Test-Path $Path) {
            try {
                Import-Clixml -Path $Path -ErrorAction Stop
            } catch {
                Write-Warning "Unable to parse [$Path]. Setting default preferences."
                $defaultPrefs
            }
        } else {
            $defaultPrefs
        }
    }
}
function New-EmptyColorTheme {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [OutputType([hashtable])]
    [cmdletbinding()]
    param()

    @{
        Name = ''
        Types = @{
            Directories = @{
                #''        = "`e[0m"
                symlink  = ''
                junction = ''
                WellKnown = @{}
            }
            Files = @{
                #''        = "`e[0m"
                symlink  = ''
                junction = ''
                WellKnown = @{}
            }
        }
    }
}
function Resolve-Icon {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [IO.FileSystemInfo]$FileInfo,

        [string]$IconTheme = $script:userThemeData.CurrentIconTheme,

        [string]$ColorTheme = $script:userThemeData.CurrentColorTheme
    )

    begin {
        $icons  = $script:userThemeData.Themes.Icon[$IconTheme]
        $colors = $script:colorSequences[$ColorTheme]
    }

    process {
        $displayInfo = @{
            Icon     = $null
            Color    = $null
            Target   = ''
        }

        if ($FileInfo.PSIsContainer) {
            $type = 'Directories'
        } else {
            $type = 'Files'
        }

        switch ($FileInfo.LinkType) {
            # Determine symlink or junction icon and color
            'Junction' {
                if ($icons) {
                    $iconName = $icons.Types.($type)['junction']
                } else {
                    $iconName = $null
                }
                if ($colors) {
                    $colorSeq = $colors.Types.($type)['junction']
                } else {
                    $colorSet = $script:colorReset
                }
                $displayInfo['Target'] = ' ' + $glyphs['nf-md-arrow_right_thick'] + ' ' + $FileInfo.Target
                break
            }
            'SymbolicLink' {
                if ($icons) {
                    $iconName = $icons.Types.($type)['symlink']
                } else {
                    $iconName = $null
                }
                if ($colors) {
                    $colorSeq = $colors.Types.($type)['symlink']
                } else {
                    $colorSet = $script:colorReset
                }
                $displayInfo['Target'] = ' ' + $glyphs['nf-md-arrow_right_thick'] + ' ' + $FileInfo.Target
                break
            } default {
                if ($icons) {
                    # Determine normal directory icon and color
                    $iconName = $icons.Types.$type.WellKnown[$FileInfo.Name]
                    if (-not $iconName) {
                        if ($FileInfo.PSIsContainer) {
                            $iconName = $icons.Types.$type[$FileInfo.Name]
                        } elseif ($icons.Types.$type.ContainsKey($FileInfo.Extension)) {
                            $iconName = $icons.Types.$type[$FileInfo.Extension]
                        } else {
                            # File probably has multiple extensions
                            # Fallback to computing the full extension
                            $firstDot = $FileInfo.Name.IndexOf('.')
                            if ($firstDot -ne -1) {
                                $fullExtension = $FileInfo.Name.Substring($firstDot)
                                $iconName = $icons.Types.$type[$fullExtension]
                            }
                        }
                        if (-not $iconName) {
                            $iconName = $icons.Types.$type['']
                        }

                        # Fallback if everything has gone horribly wrong
                        if (-not $iconName) {
                            if ($FileInfo.PSIsContainer) {
                                $iconName = 'nf-oct-file_directory'
                            } else {
                                $iconName = 'nf-fa-file'
                            }
                        }
                    }
                } else {
                    $iconName = $null
                }
                if ($colors) {
                    $colorSeq = $colors.Types.$type.WellKnown[$FileInfo.Name]
                    if (-not $colorSeq) {
                        if ($FileInfo.PSIsContainer) {
                            $colorSeq = $colors.Types.$type[$FileInfo.Name]
                        } elseif ($colors.Types.$type.ContainsKey($FileInfo.Extension)) {
                            $colorSeq = $colors.Types.$type[$FileInfo.Extension]
                        } else {
                            # File probably has multiple extensions
                            # Fallback to computing the full extension
                            $firstDot = $FileInfo.Name.IndexOf('.')
                            if ($firstDot -ne -1) {
                                $fullExtension = $FileInfo.Name.Substring($firstDot)
                                $colorSeq = $colors.Types.$type[$fullExtension]
                            }
                        }
                        if (-not $colorSeq) {
                            $colorSeq = $colors.Types.$type['']
                        }

                        # Fallback if everything has gone horribly wrong
                        if (-not $colorSeq) {
                            $colorSeq = $script:colorReset
                        }
                    }
                } else {
                    $colorSeq = $script:colorReset
                }
            }
        }
        if ($iconName) {
            $displayInfo['Icon'] = $glyphs[$iconName]
        } else {
            $displayInfo['Icon'] = $null
        }
        $displayInfo['Color'] = $colorSeq
        $displayInfo
    }
}
function Save-Preferences {
    [cmdletbinding()]
    param(
        [parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Preferences,

        [string]$Path = (Join-Path (Get-ThemeStoragePath) 'prefs.xml')
    )

    process {
        Write-Debug ('Saving preferendces to [{0}]' -f $Path)
        $Preferences | Export-CliXml -Path $Path -Force
    }
}
function Save-Theme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Theme,

        [ValidateSet('color', 'icon')]
        [string]$Type,

        [string]$Path = (Get-ThemeStoragePath)
    )

    process {
        $themePath = Join-Path $Path "$($Theme.Name)_$($Type.ToLower()).xml"
        Write-Debug ('Saving [{0}] theme [{1}] to [{2}]' -f $type, $theme.Name, $themePath)
        $Theme | Export-CliXml -Path $themePath -Force
    }
}
function Set-Theme {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Name,

        [ValidateSet('Color', 'Icon')]
        [Parameter(Mandatory)]
        [string]$Type
    )

    if ([string]::IsNullOrEmpty($Name)) {
        $script:userThemeData."Current$($Type)Theme" = $null
        $script:prefs."Current$($Type)Theme" = ''
        Save-Preferences $script:prefs
    } else {
        if (-not $script:userThemeData.Themes.$Type.ContainsKey($Name)) {
            Write-Error "$Type theme [$Name] not found."
        } else {
            $script:userThemeData."Current$($Type)Theme" = $Name
            $script:prefs."Current$($Type)Theme" = $Name
            Save-Theme -Theme $userThemeData.Themes.$Type[$Name] -Type $type
            Save-Preferences $script:prefs
        }
    }
}
function Add-TerminalIconsColorTheme {
    <#
    .SYNOPSIS
        Add a Terminal-Icons color theme for the current user.
    .DESCRIPTION
        Add a Terminal-Icons color theme for the current user. The theme data
        is stored in the user's profile
    .PARAMETER Path
        The path to the Terminal-Icons color theme file.
    .PARAMETER LiteralPath
        The literal path to the Terminal-Icons color theme file.
    .PARAMETER Force
        Overwrite the color theme if it already exists in the profile.
    .EXAMPLE
        PS> Add-TerminalIconsColorTheme -Path ./my_color_theme.psd1

        Add the color theme contained in ./my_color_theme.psd1.
    .EXAMPLE
        PS> Get-ChildItem ./path/to/colorthemes | Add-TerminalIconsColorTheme -Force

        Add all color themes contained in the folder ./path/to/colorthemes and add them,
        overwriting existing ones if needed.
    .INPUTS
        System.String

        You can pipe a string that contains a path to 'Add-TerminalIconsColorTheme'.
    .OUTPUTS
        None.
    .NOTES
        'Add-TerminalIconsColorTheme' will not overwrite an existing theme by default.
        Add the -Force switch to overwrite.
    .LINK
        Add-TerminalIconsIconTheme
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification='Implemented in private function')]
    [CmdletBinding(DefaultParameterSetName = 'Path', SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName  = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [switch]$Force
    )

    process {
        Add-Theme @PSBoundParameters -Type Color
    }
}
function Add-TerminalIconsIconTheme {
    <#
    .SYNOPSIS
        Add a Terminal-Icons icon theme for the current user.
    .DESCRIPTION
        Add a Terminal-Icons icon theme for the current user. The theme data
        is stored in the user's profile
    .PARAMETER Path
        The path to the Terminal-Icons icon theme file.
    .PARAMETER LiteralPath
        The literal path to the Terminal-Icons icon theme file.
    .PARAMETER Force
        Overwrite the icon theme if it already exists in the profile.
    .EXAMPLE
        PS> Add-Terminal-IconsIconTHeme -Path ./my_icon_theme.psd1

        Add the icon theme contained in ./my_icon_theme.psd1.
    .EXAMPLE
        PS> Get-ChildItem ./path/to/iconthemes | Add-TerminalIconsIconTheme -Force

        Add all icon themes contained in the folder ./path/to/iconthemes and add them,
        overwriting existing ones if needed.
    .INPUTS
        System.String

        You can pipe a string that contains a path to 'Add-TerminalIconsIconTheme'.
    .OUTPUTS
        None.
    .NOTES
        'Add-TerminalIconsIconTheme' will not overwrite an existing theme by default.
        Add the -Force switch to overwrite.
    .LINK
        Add-TerminalIconsColorTheme
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification='Implemented in private function')]
    [CmdletBinding(DefaultParameterSetName = 'Path', SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName  = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [switch]$Force
    )

    process {
        Add-Theme @PSBoundParameters -Type Icon
    }
}
function Format-TerminalIcons {
    <#
    .SYNOPSIS
        Prepend a custom icon (with color) to the provided file or folder object when displayed.
    .DESCRIPTION
        Take the provided file or folder object and look up the appropriate icon and color to display.
    .PARAMETER FileInfo
        The file or folder to display
    .EXAMPLE
        Get-ChildItem

        List a directory. Terminal-Icons will be invoked automatically for display.
    .EXAMPLE
        Get-Item ./README.md | Format-TerminalIcons

        Get a file object and pass directly to Format-TerminalIcons.
    .INPUTS
        System.IO.FileSystemInfo

        You can pipe an objects that derive from System.IO.FileSystemInfo (System.IO.DIrectoryInfo and System.IO.FileInfo) to 'Format-TerminalIcons'.
    .OUTPUTS
        System.String

        Outputs a colorized string with an icon prepended.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [IO.FileSystemInfo]$FileInfo
    )

    process {
        $displayInfo = Resolve-Icon $FileInfo
        if ($displayInfo.Icon) {
            "$($displayInfo.Color)$($displayInfo.Icon)  $($FileInfo.Name)$($displayInfo.Target)$($script:colorReset)"
        } else {
            "$($displayInfo.Color)$($FileInfo.Name)$($displayInfo.Target)$($script:colorReset)"
        }
    }
}
function Get-TerminalIconsColorTheme {
    <#
    .SYNOPSIS
        List the available color themes.
    .DESCRIPTION
        List the available color themes.
    .Example
        PS> Get-TerminalIconsColorTheme

        Get the list of available color themes.
    .INPUTS
        None.
    .OUTPUTS
        System.Collections.Hashtable

        An array of hashtables representing available color themes.
    .LINK
        Get-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsTheme
    #>
    $script:userThemeData.Themes.Color
}
function Get-TerminalIconsGlyphs {
    <#
    .SYNOPSIS
        Gets the list of glyphs known to Terminal-Icons.
    .DESCRIPTION
        Gets a hashtable with the available glyph names and icons. Useful in creating a custom theme.
    .EXAMPLE
        PS> Get-TerminalIconsGlyphs

        Gets the table of glyph names and icons.
    .INPUTS
        None.
    .OUTPUTS
        None.
    .LINK
        Get-TerminalIconsIconTheme
    .LINK
        Set-TerminalIconsIcon
    #>
    [cmdletbinding()]
    param()

    # This is also helpful for argument completers needing glyphs -
    # ArgumentCompleterAttribute isn't able to access script variables but it
    # CAN call commands.
    $script:glyphs.GetEnumerator() | Sort-Object Name
}
function Get-TerminalIconsIconTheme {
    <#
    .SYNOPSIS
        List the available icon themes.
    .DESCRIPTION
        List the available icon themes.
    .Example
        PS> Get-TerminalIconsIconTheme

        Get the list of available icon themes.
    .INPUTS
        None.
    .OUTPUTS
        System.Collections.Hashtable

        An array of hashtables representing available icon themes.
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsTheme
    #>
    $script:userThemeData.Themes.Icon
}
function Get-TerminalIconsTheme {
    <#
    .SYNOPSIS
        Get the currently applied color and icon theme.
    .DESCRIPTION
        Get the currently applied color and icon theme.
    .EXAMPLE
        PS> Get-TerminalIconsTheme

        Get the currently applied Terminal-Icons color and icon theme.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject

        An object representing the currently applied color and icon theme.
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsIconTheme
    #>
    [CmdletBinding()]
    param()

    $iconTheme = if ($script:userThemeData.CurrentIconTheme) {
        [pscustomobject]$script:userThemeData.Themes.Icon[$script:userThemeData.CurrentIconTheme]
    } else {
        $null
    }

    $colorTheme = if ($script:userThemeData.CurrentColorTheme) {
        [pscustomobject]$script:userThemeData.Themes.Color[$script:userThemeData.CurrentColorTheme]
    } else {
        $null
    }

    [pscustomobject]@{
        PSTypeName = 'TerminalIconsTheme'
        Color      = $colorTheme
        Icon       = $iconTheme
    }
}
function Invoke-TerminalIconsThemeMigration {
    <#
    .SYNOPSIS
        Used to migrate your terminal icon themes to Nerd Fonts v3.
    .DESCRIPTION
        Used to migrate your terminal icon themes to Nerd Fonts v3.
    .PARAMETER Path
        The path to the Terminal-Icons icon theme file.
    .PARAMETER LiteralPath
        The literal path to the Terminal-Icons icon theme file.
    .EXAMPLE
        PS> Invoke-TerminalIconsThemeMigration -Path ./my_icon_theme.psd1 | Out-File ./migrated_icon_theme.psd1

        Loads the theme, migrates classes and then saves the newly migrated theme using the Out-File command.
    .INPUTS
        None.
    .OUTPUTS
        System.String

        The theme that has been fully migrated.
    .LINK
        Invoke-TerminalIconsThemeMigration
    .LINK
        Invoke-TerminalIconsThemeMigration
    #>
    param(
        [Parameter(
            Mandatory,
            ParameterSetName = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]$LiteralPath
    )
    $MigrationMap = @{
        'nf-oct-file_symlink_directory'                  = 'nf-cod-file_symlink_directory'
        'nf-mdi-access_point'                            = 'nf-md-access_point'
        'nf-mdi-access_point_network'                    = 'nf-md-access_point_network'
        'nf-mdi-account'                                 = 'nf-md-account'
        'nf-mdi-account_alert'                           = 'nf-md-account_alert'
        'nf-mdi-account_box'                             = 'nf-md-account_box'
        'nf-mdi-account_box_outline'                     = 'nf-md-account_box_outline'
        'nf-mdi-account_check'                           = 'nf-md-account_check'
        'nf-mdi-account_circle'                          = 'nf-md-account_circle'
        'nf-mdi-account_convert'                         = 'nf-md-account_convert'
        'nf-mdi-account_edit'                            = 'nf-md-account_edit'
        'nf-mdi-account_key'                             = 'nf-md-account_key'
        'nf-mdi-account_minus'                           = 'nf-md-account_minus'
        'nf-mdi-account_multiple'                        = 'nf-md-account_multiple'
        'nf-mdi-account_multiple_minus'                  = 'nf-md-account_multiple_minus'
        'nf-mdi-account_multiple_outline'                = 'nf-md-account_multiple_outline'
        'nf-mdi-account_multiple_plus'                   = 'nf-md-account_multiple_plus'
        'nf-mdi-account_multiple_plus_outline'           = 'nf-md-account_multiple_plus_outline'
        'nf-mdi-account_network'                         = 'nf-md-account_network'
        'nf-mdi-account_off'                             = 'nf-md-account_off'
        'nf-mdi-account_outline'                         = 'nf-md-account_outline'
        'nf-mdi-account_plus'                            = 'nf-md-account_plus'
        'nf-mdi-account_plus_outline'                    = 'nf-md-account_plus_outline'
        'nf-mdi-account_remove'                          = 'nf-md-account_remove'
        'nf-mdi-account_search'                          = 'nf-md-account_search'
        'nf-mdi-account_settings'                        = 'nf-md-account_settings'
        'nf-mdi-account_star'                            = 'nf-md-account_star'
        'nf-mdi-account_switch'                          = 'nf-md-account_switch'
        'nf-mdi-adjust'                                  = 'nf-md-adjust'
        'nf-mdi-air_conditioner'                         = 'nf-md-air_conditioner'
        'nf-mdi-airballoon'                              = 'nf-md-airballoon'
        'nf-mdi-airplane'                                = 'nf-md-airplane'
        'nf-mdi-airplane_landing'                        = 'nf-md-airplane_landing'
        'nf-mdi-airplane_off'                            = 'nf-md-airplane_off'
        'nf-mdi-airplane_takeoff'                        = 'nf-md-airplane_takeoff'
        'nf-mdi-alarm'                                   = 'nf-md-alarm'
        'nf-mdi-alarm_bell'                              = 'nf-md-alarm_bell'
        'nf-mdi-alarm_check'                             = 'nf-md-alarm_check'
        'nf-mdi-alarm_light'                             = 'nf-md-alarm_light'
        'nf-mdi-alarm_multiple'                          = 'nf-md-alarm_multiple'
        'nf-mdi-alarm_off'                               = 'nf-md-alarm_off'
        'nf-mdi-alarm_plus'                              = 'nf-md-alarm_plus'
        'nf-mdi-alarm_snooze'                            = 'nf-md-alarm_snooze'
        'nf-mdi-album'                                   = 'nf-md-album'
        'nf-mdi-alert'                                   = 'nf-md-alert'
        'nf-mdi-alert_box'                               = 'nf-md-alert_box'
        'nf-mdi-alert_circle'                            = 'nf-md-alert_circle'
        'nf-mdi-alert_circle_outline'                    = 'nf-md-alert_circle_outline'
        'nf-mdi-alert_decagram'                          = 'nf-md-alert_decagram'
        'nf-mdi-alert_octagon'                           = 'nf-md-alert_octagon'
        'nf-mdi-alert_octagram'                          = 'nf-md-alert_octagram'
        'nf-mdi-alert_outline'                           = 'nf-md-alert_outline'
        'nf-mdi-all_inclusive'                           = 'nf-md-all_inclusive'
        'nf-mdi-alpha'                                   = 'nf-md-alpha'
        'nf-mdi-alphabetical'                            = 'nf-md-alphabetical'
        'nf-mdi-altimeter'                               = 'nf-md-altimeter'
        'nf-mdi-ambulance'                               = 'nf-md-ambulance'
        'nf-mdi-amplifier'                               = 'nf-md-amplifier'
        'nf-mdi-anchor'                                  = 'nf-md-anchor'
        'nf-mdi-android'                                 = 'nf-md-android'
        'nf-mdi-android_studio'                          = 'nf-md-android_studio'
        'nf-mdi-angular'                                 = 'nf-md-angular'
        'nf-mdi-angularjs'                               = 'nf-md-angularjs'
        'nf-mdi-animation'                               = 'nf-md-animation'
        'nf-mdi-apple'                                   = 'nf-md-apple'
        'nf-mdi-apple_finder'                            = 'nf-md-apple_finder'
        'nf-mdi-apple_ios'                               = 'nf-md-apple_ios'
        'nf-mdi-apple_keyboard_caps'                     = 'nf-md-apple_keyboard_caps'
        'nf-mdi-apple_keyboard_command'                  = 'nf-md-apple_keyboard_command'
        'nf-mdi-apple_keyboard_control'                  = 'nf-md-apple_keyboard_control'
        'nf-mdi-apple_keyboard_option'                   = 'nf-md-apple_keyboard_option'
        'nf-mdi-apple_keyboard_shift'                    = 'nf-md-apple_keyboard_shift'
        'nf-mdi-apple_safari'                            = 'nf-md-apple_safari'
        'nf-mdi-application'                             = 'nf-md-application'
        'nf-mdi-apps'                                    = 'nf-md-apps'
        'nf-mdi-archive'                                 = 'nf-md-archive'
        'nf-mdi-arrange_bring_forward'                   = 'nf-md-arrange_bring_forward'
        'nf-mdi-arrange_bring_to_front'                  = 'nf-md-arrange_bring_to_front'
        'nf-mdi-arrange_send_backward'                   = 'nf-md-arrange_send_backward'
        'nf-mdi-arrange_send_to_back'                    = 'nf-md-arrange_send_to_back'
        'nf-mdi-arrow_all'                               = 'nf-md-arrow_all'
        'nf-mdi-arrow_bottom_left'                       = 'nf-md-arrow_bottom_left'
        'nf-mdi-arrow_bottom_right'                      = 'nf-md-arrow_bottom_right'
        'nf-mdi-arrow_collapse'                          = 'nf-md-arrow_collapse'
        'nf-mdi-arrow_collapse_all'                      = 'nf-md-arrow_collapse_all'
        'nf-mdi-arrow_collapse_down'                     = 'nf-md-arrow_collapse_down'
        'nf-mdi-arrow_collapse_left'                     = 'nf-md-arrow_collapse_left'
        'nf-mdi-arrow_collapse_right'                    = 'nf-md-arrow_collapse_right'
        'nf-mdi-arrow_collapse_up'                       = 'nf-md-arrow_collapse_up'
        'nf-mdi-arrow_down'                              = 'nf-md-arrow_down'
        'nf-mdi-arrow_down_bold'                         = 'nf-md-arrow_down_bold'
        'nf-mdi-arrow_down_bold_box'                     = 'nf-md-arrow_down_bold_box'
        'nf-mdi-arrow_down_bold_box_outline'             = 'nf-md-arrow_down_bold_box_outline'
        'nf-mdi-arrow_down_bold_circle'                  = 'nf-md-arrow_down_bold_circle'
        'nf-mdi-arrow_down_bold_circle_outline'          = 'nf-md-arrow_down_bold_circle_outline'
        'nf-mdi-arrow_down_bold_hexagon_outline'         = 'nf-md-arrow_down_bold_hexagon_outline'
        'nf-mdi-arrow_down_box'                          = 'nf-md-arrow_down_box'
        'nf-mdi-arrow_down_drop_circle'                  = 'nf-md-arrow_down_drop_circle'
        'nf-mdi-arrow_down_drop_circle_outline'          = 'nf-md-arrow_down_drop_circle_outline'
        'nf-mdi-arrow_down_thick'                        = 'nf-md-arrow_down_thick'
        'nf-mdi-arrow_expand'                            = 'nf-md-arrow_expand'
        'nf-mdi-arrow_expand_all'                        = 'nf-md-arrow_expand_all'
        'nf-mdi-arrow_expand_down'                       = 'nf-md-arrow_expand_down'
        'nf-mdi-arrow_expand_left'                       = 'nf-md-arrow_expand_left'
        'nf-mdi-arrow_expand_right'                      = 'nf-md-arrow_expand_right'
        'nf-mdi-arrow_expand_up'                         = 'nf-md-arrow_expand_up'
        'nf-mdi-arrow_left'                              = 'nf-md-arrow_left'
        'nf-mdi-arrow_left_bold'                         = 'nf-md-arrow_left_bold'
        'nf-mdi-arrow_left_bold_box'                     = 'nf-md-arrow_left_bold_box'
        'nf-mdi-arrow_left_bold_box_outline'             = 'nf-md-arrow_left_bold_box_outline'
        'nf-mdi-arrow_left_bold_circle'                  = 'nf-md-arrow_left_bold_circle'
        'nf-mdi-arrow_left_bold_circle_outline'          = 'nf-md-arrow_left_bold_circle_outline'
        'nf-mdi-arrow_left_bold_hexagon_outline'         = 'nf-md-arrow_left_bold_hexagon_outline'
        'nf-mdi-arrow_left_box'                          = 'nf-md-arrow_left_box'
        'nf-mdi-arrow_left_drop_circle'                  = 'nf-md-arrow_left_drop_circle'
        'nf-mdi-arrow_left_drop_circle_outline'          = 'nf-md-arrow_left_drop_circle_outline'
        'nf-mdi-arrow_left_thick'                        = 'nf-md-arrow_left_thick'
        'nf-mdi-arrow_right'                             = 'nf-md-arrow_right'
        'nf-mdi-arrow_right_bold'                        = 'nf-md-arrow_right_bold'
        'nf-mdi-arrow_right_bold_box'                    = 'nf-md-arrow_right_bold_box'
        'nf-mdi-arrow_right_bold_box_outline'            = 'nf-md-arrow_right_bold_box_outline'
        'nf-mdi-arrow_right_bold_circle'                 = 'nf-md-arrow_right_bold_circle'
        'nf-mdi-arrow_right_bold_circle_outline'         = 'nf-md-arrow_right_bold_circle_outline'
        'nf-mdi-arrow_right_bold_hexagon_outline'        = 'nf-md-arrow_right_bold_hexagon_outline'
        'nf-mdi-arrow_right_box'                         = 'nf-md-arrow_right_box'
        'nf-mdi-arrow_right_drop_circle'                 = 'nf-md-arrow_right_drop_circle'
        'nf-mdi-arrow_right_drop_circle_outline'         = 'nf-md-arrow_right_drop_circle_outline'
        'nf-mdi-arrow_right_thick'                       = 'nf-md-arrow_right_thick'
        'nf-mdi-arrow_top_left'                          = 'nf-md-arrow_top_left'
        'nf-mdi-arrow_top_right'                         = 'nf-md-arrow_top_right'
        'nf-mdi-arrow_up'                                = 'nf-md-arrow_up'
        'nf-mdi-arrow_up_bold'                           = 'nf-md-arrow_up_bold'
        'nf-mdi-arrow_up_bold_box'                       = 'nf-md-arrow_up_bold_box'
        'nf-mdi-arrow_up_bold_box_outline'               = 'nf-md-arrow_up_bold_box_outline'
        'nf-mdi-arrow_up_bold_circle'                    = 'nf-md-arrow_up_bold_circle'
        'nf-mdi-arrow_up_bold_circle_outline'            = 'nf-md-arrow_up_bold_circle_outline'
        'nf-mdi-arrow_up_bold_hexagon_outline'           = 'nf-md-arrow_up_bold_hexagon_outline'
        'nf-mdi-arrow_up_box'                            = 'nf-md-arrow_up_box'
        'nf-mdi-arrow_up_drop_circle'                    = 'nf-md-arrow_up_drop_circle'
        'nf-mdi-arrow_up_drop_circle_outline'            = 'nf-md-arrow_up_drop_circle_outline'
        'nf-mdi-arrow_up_thick'                          = 'nf-md-arrow_up_thick'
        'nf-mdi-assistant'                               = 'nf-md-assistant'
        'nf-mdi-asterisk'                                = 'nf-md-asterisk'
        'nf-mdi-at'                                      = 'nf-md-at'
        'nf-mdi-atlassian'                               = 'nf-md-atlassian'
        'nf-mdi-atom'                                    = 'nf-md-atom'
        'nf-mdi-attachment'                              = 'nf-md-attachment'
        'nf-mdi-auto_fix'                                = 'nf-md-auto_fix'
        'nf-mdi-auto_upload'                             = 'nf-md-auto_upload'
        'nf-mdi-autorenew'                               = 'nf-md-autorenew'
        'nf-mdi-av_timer'                                = 'nf-md-av_timer'
        'nf-mdi-azure'                                   = 'nf-md-microsoft_azure'
        'nf-mdi-baby'                                    = 'nf-md-baby'
        'nf-mdi-baby_buggy'                              = 'nf-md-baby_buggy'
        'nf-mdi-backburger'                              = 'nf-md-backburger'
        'nf-mdi-backspace'                               = 'nf-md-backspace'
        'nf-mdi-backup_restore'                          = 'nf-md-backup_restore'
        'nf-mdi-bank'                                    = 'nf-md-bank'
        'nf-mdi-barcode'                                 = 'nf-md-barcode'
        'nf-mdi-barcode_scan'                            = 'nf-md-barcode_scan'
        'nf-mdi-barley'                                  = 'nf-md-barley'
        'nf-mdi-barrel'                                  = 'nf-md-barrel'
        'nf-mdi-basket'                                  = 'nf-md-basket'
        'nf-mdi-basket_fill'                             = 'nf-md-basket_fill'
        'nf-mdi-basket_unfill'                           = 'nf-md-basket_unfill'
        'nf-mdi-basketball'                              = 'nf-md-basketball'
        'nf-mdi-battery'                                 = 'nf-md-battery'
        'nf-mdi-battery_10'                              = 'nf-md-battery_10'
        'nf-mdi-battery_20'                              = 'nf-md-battery_20'
        'nf-mdi-battery_30'                              = 'nf-md-battery_30'
        'nf-mdi-battery_40'                              = 'nf-md-battery_40'
        'nf-mdi-battery_50'                              = 'nf-md-battery_50'
        'nf-mdi-battery_60'                              = 'nf-md-battery_60'
        'nf-mdi-battery_70'                              = 'nf-md-battery_70'
        'nf-mdi-battery_80'                              = 'nf-md-battery_80'
        'nf-mdi-battery_90'                              = 'nf-md-battery_90'
        'nf-mdi-battery_alert'                           = 'nf-md-battery_alert'
        'nf-mdi-battery_charging'                        = 'nf-md-battery_charging'
        'nf-mdi-battery_charging_100'                    = 'nf-md-battery_charging_100'
        'nf-mdi-battery_charging_20'                     = 'nf-md-battery_charging_20'
        'nf-mdi-battery_charging_30'                     = 'nf-md-battery_charging_30'
        'nf-mdi-battery_charging_40'                     = 'nf-md-battery_charging_40'
        'nf-mdi-battery_charging_60'                     = 'nf-md-battery_charging_60'
        'nf-mdi-battery_charging_80'                     = 'nf-md-battery_charging_80'
        'nf-mdi-battery_charging_90'                     = 'nf-md-battery_charging_90'
        'nf-mdi-battery_charging_wireless'               = 'nf-md-battery_charging_wireless'
        'nf-mdi-battery_charging_wireless_10'            = 'nf-md-battery_charging_wireless_10'
        'nf-mdi-battery_charging_wireless_20'            = 'nf-md-battery_charging_wireless_20'
        'nf-mdi-battery_charging_wireless_30'            = 'nf-md-battery_charging_wireless_30'
        'nf-mdi-battery_charging_wireless_40'            = 'nf-md-battery_charging_wireless_40'
        'nf-mdi-battery_charging_wireless_50'            = 'nf-md-battery_charging_wireless_50'
        'nf-mdi-battery_charging_wireless_60'            = 'nf-md-battery_charging_wireless_60'
        'nf-mdi-battery_charging_wireless_70'            = 'nf-md-battery_charging_wireless_70'
        'nf-mdi-battery_charging_wireless_80'            = 'nf-md-battery_charging_wireless_80'
        'nf-mdi-battery_charging_wireless_90'            = 'nf-md-battery_charging_wireless_90'
        'nf-mdi-battery_charging_wireless_alert'         = 'nf-md-battery_charging_wireless_alert'
        'nf-mdi-battery_charging_wireless_outline'       = 'nf-md-battery_charging_wireless_outline'
        'nf-mdi-battery_minus'                           = 'nf-md-battery_minus'
        'nf-mdi-battery_negative'                        = 'nf-md-battery_negative'
        'nf-mdi-battery_outline'                         = 'nf-md-battery_outline'
        'nf-mdi-battery_plus'                            = 'nf-md-battery_plus'
        'nf-mdi-battery_positive'                        = 'nf-md-battery_positive'
        'nf-mdi-battery_unknown'                         = 'nf-md-battery_unknown'
        'nf-mdi-beach'                                   = 'nf-md-beach'
        'nf-mdi-beaker'                                  = 'nf-md-beaker'
        'nf-mdi-beer'                                    = 'nf-md-beer'
        'nf-mdi-bell'                                    = 'nf-md-bell'
        'nf-mdi-bell_off'                                = 'nf-md-bell_off'
        'nf-mdi-bell_outline'                            = 'nf-md-bell_outline'
        'nf-mdi-bell_plus'                               = 'nf-md-bell_plus'
        'nf-mdi-bell_ring'                               = 'nf-md-bell_ring'
        'nf-mdi-bell_ring_outline'                       = 'nf-md-bell_ring_outline'
        'nf-mdi-bell_sleep'                              = 'nf-md-bell_sleep'
        'nf-mdi-beta'                                    = 'nf-md-beta'
        'nf-mdi-bike'                                    = 'nf-md-bike'
        'nf-mdi-binoculars'                              = 'nf-md-binoculars'
        'nf-mdi-bio'                                     = 'nf-md-bio'
        'nf-mdi-biohazard'                               = 'nf-md-biohazard'
        'nf-mdi-bitbucket'                               = 'nf-md-bitbucket'
        'nf-mdi-bitcoin'                                 = 'nf-md-bitcoin'
        'nf-mdi-black_mesa'                              = 'nf-md-black_mesa'
        'nf-mdi-blender'                                 = 'nf-md-blender'
        'nf-mdi-blinds'                                  = 'nf-md-blinds'
        'nf-mdi-block_helper'                            = 'nf-md-block_helper'
        'nf-mdi-bluetooth'                               = 'nf-md-bluetooth'
        'nf-mdi-bluetooth_audio'                         = 'nf-md-bluetooth_audio'
        'nf-mdi-bluetooth_connect'                       = 'nf-md-bluetooth_connect'
        'nf-mdi-bluetooth_off'                           = 'nf-md-bluetooth_off'
        'nf-mdi-bluetooth_settings'                      = 'nf-md-bluetooth_settings'
        'nf-mdi-bluetooth_transfer'                      = 'nf-md-bluetooth_transfer'
        'nf-mdi-blur'                                    = 'nf-md-blur'
        'nf-mdi-blur_linear'                             = 'nf-md-blur_linear'
        'nf-mdi-blur_off'                                = 'nf-md-blur_off'
        'nf-mdi-blur_radial'                             = 'nf-md-blur_radial'
        'nf-mdi-bomb'                                    = 'nf-md-bomb'
        'nf-mdi-bomb_off'                                = 'nf-md-bomb_off'
        'nf-mdi-bone'                                    = 'nf-md-bone'
        'nf-mdi-book'                                    = 'nf-md-book'
        'nf-mdi-book_minus'                              = 'nf-md-book_minus'
        'nf-mdi-book_multiple'                           = 'nf-md-book_multiple'
        'nf-mdi-book_open'                               = 'nf-md-book_open'
        'nf-mdi-book_open_page_variant'                  = 'nf-md-book_open_page_variant'
        'nf-mdi-book_open_variant'                       = 'nf-md-book_open_variant'
        'nf-mdi-book_plus'                               = 'nf-md-book_plus'
        'nf-mdi-book_variant'                            = 'nf-md-book_variant'
        'nf-mdi-bookmark'                                = 'nf-md-bookmark'
        'nf-mdi-bookmark_check'                          = 'nf-md-bookmark_check'
        'nf-mdi-bookmark_music'                          = 'nf-md-bookmark_music'
        'nf-mdi-bookmark_outline'                        = 'nf-md-bookmark_outline'
        'nf-mdi-bookmark_plus'                           = 'nf-md-bookmark_plus'
        'nf-mdi-bookmark_plus_outline'                   = 'nf-md-bookmark_plus_outline'
        'nf-mdi-bookmark_remove'                         = 'nf-md-bookmark_remove'
        'nf-mdi-boombox'                                 = 'nf-md-boombox'
        'nf-mdi-bootstrap'                               = 'nf-md-bootstrap'
        'nf-mdi-border_all'                              = 'nf-md-border_all'
        'nf-mdi-border_bottom'                           = 'nf-md-border_bottom'
        'nf-mdi-border_color'                            = 'nf-md-border_color'
        'nf-mdi-border_horizontal'                       = 'nf-md-border_horizontal'
        'nf-mdi-border_inside'                           = 'nf-md-border_inside'
        'nf-mdi-border_left'                             = 'nf-md-border_left'
        'nf-mdi-border_none'                             = 'nf-md-border_none'
        'nf-mdi-border_outside'                          = 'nf-md-border_outside'
        'nf-mdi-border_right'                            = 'nf-md-border_right'
        'nf-mdi-border_style'                            = 'nf-md-border_style'
        'nf-mdi-border_top'                              = 'nf-md-border_top'
        'nf-mdi-border_vertical'                         = 'nf-md-border_vertical'
        'nf-mdi-bow_tie'                                 = 'nf-md-bow_tie'
        'nf-mdi-bowl'                                    = 'nf-md-bowl'
        'nf-mdi-bowling'                                 = 'nf-md-bowling'
        'nf-mdi-box'                                     = 'nf-md-box'
        'nf-mdi-box_cutter'                              = 'nf-md-box_cutter'
        'nf-mdi-box_shadow'                              = 'nf-md-box_shadow'
        'nf-mdi-bridge'                                  = 'nf-md-bridge'
        'nf-mdi-briefcase'                               = 'nf-md-briefcase'
        'nf-mdi-briefcase_check'                         = 'nf-md-briefcase_check'
        'nf-mdi-briefcase_download'                      = 'nf-md-briefcase_download'
        'nf-mdi-briefcase_outline'                       = 'nf-md-briefcase_outline'
        'nf-mdi-briefcase_upload'                        = 'nf-md-briefcase_upload'
        'nf-mdi-brightness_1'                            = 'nf-md-brightness_1'
        'nf-mdi-brightness_2'                            = 'nf-md-brightness_2'
        'nf-mdi-brightness_3'                            = 'nf-md-brightness_3'
        'nf-mdi-brightness_4'                            = 'nf-md-brightness_4'
        'nf-mdi-brightness_5'                            = 'nf-md-brightness_5'
        'nf-mdi-brightness_6'                            = 'nf-md-brightness_6'
        'nf-mdi-brightness_7'                            = 'nf-md-brightness_7'
        'nf-mdi-brightness_auto'                         = 'nf-md-brightness_auto'
        'nf-mdi-broom'                                   = 'nf-md-broom'
        'nf-mdi-brush'                                   = 'nf-md-brush'
        'nf-mdi-bug'                                     = 'nf-md-bug'
        'nf-mdi-bulletin_board'                          = 'nf-md-bulletin_board'
        'nf-mdi-bullhorn'                                = 'nf-md-bullhorn'
        'nf-mdi-bullseye'                                = 'nf-md-bullseye'
        'nf-mdi-bus'                                     = 'nf-md-bus'
        'nf-mdi-bus_articulated_end'                     = 'nf-md-bus_articulated_end'
        'nf-mdi-bus_articulated_front'                   = 'nf-md-bus_articulated_front'
        'nf-mdi-bus_double_decker'                       = 'nf-md-bus_double_decker'
        'nf-mdi-bus_school'                              = 'nf-md-bus_school'
        'nf-mdi-bus_side'                                = 'nf-md-bus_side'
        'nf-mdi-cached'                                  = 'nf-md-cached'
        'nf-mdi-cake'                                    = 'nf-md-cake'
        'nf-mdi-cake_layered'                            = 'nf-md-cake_layered'
        'nf-mdi-cake_variant'                            = 'nf-md-cake_variant'
        'nf-mdi-calculator'                              = 'nf-md-calculator'
        'nf-mdi-calendar'                                = 'nf-md-calendar'
        'nf-mdi-calendar_blank'                          = 'nf-md-calendar_blank'
        'nf-mdi-calendar_check'                          = 'nf-md-calendar_check'
        'nf-mdi-calendar_clock'                          = 'nf-md-calendar_clock'
        'nf-mdi-calendar_multiple'                       = 'nf-md-calendar_multiple'
        'nf-mdi-calendar_multiple_check'                 = 'nf-md-calendar_multiple_check'
        'nf-mdi-calendar_plus'                           = 'nf-md-calendar_plus'
        'nf-mdi-calendar_question'                       = 'nf-md-calendar_question'
        'nf-mdi-calendar_range'                          = 'nf-md-calendar_range'
        'nf-mdi-calendar_remove'                         = 'nf-md-calendar_remove'
        'nf-mdi-calendar_text'                           = 'nf-md-calendar_text'
        'nf-mdi-calendar_today'                          = 'nf-md-calendar_today'
        'nf-mdi-call_made'                               = 'nf-md-call_made'
        'nf-mdi-call_merge'                              = 'nf-md-call_merge'
        'nf-mdi-call_missed'                             = 'nf-md-call_missed'
        'nf-mdi-call_received'                           = 'nf-md-call_received'
        'nf-mdi-call_split'                              = 'nf-md-call_split'
        'nf-mdi-camcorder'                               = 'nf-md-camcorder'
        'nf-mdi-camcorder_off'                           = 'nf-md-camcorder_off'
        'nf-mdi-camera'                                  = 'nf-md-camera'
        'nf-mdi-camera_burst'                            = 'nf-md-camera_burst'
        'nf-mdi-camera_enhance'                          = 'nf-md-camera_enhance'
        'nf-mdi-camera_front'                            = 'nf-md-camera_front'
        'nf-mdi-camera_front_variant'                    = 'nf-md-camera_front_variant'
        'nf-mdi-camera_gopro'                            = 'nf-md-camera_gopro'
        'nf-mdi-camera_iris'                             = 'nf-md-camera_iris'
        'nf-mdi-camera_metering_center'                  = 'nf-md-camera_metering_center'
        'nf-mdi-camera_metering_matrix'                  = 'nf-md-camera_metering_matrix'
        'nf-mdi-camera_metering_partial'                 = 'nf-md-camera_metering_partial'
        'nf-mdi-camera_metering_spot'                    = 'nf-md-camera_metering_spot'
        'nf-mdi-camera_off'                              = 'nf-md-camera_off'
        'nf-mdi-camera_party_mode'                       = 'nf-md-camera_party_mode'
        'nf-mdi-camera_rear'                             = 'nf-md-camera_rear'
        'nf-mdi-camera_rear_variant'                     = 'nf-md-camera_rear_variant'
        'nf-mdi-camera_switch'                           = 'nf-md-camera_switch'
        'nf-mdi-camera_timer'                            = 'nf-md-camera_timer'
        'nf-mdi-cancel'                                  = 'nf-md-cancel'
        'nf-mdi-candle'                                  = 'nf-md-candle'
        'nf-mdi-candycane'                               = 'nf-md-candycane'
        'nf-mdi-cannabis'                                = 'nf-md-cannabis'
        'nf-mdi-car'                                     = 'nf-md-car'
        'nf-mdi-car_battery'                             = 'nf-md-car_battery'
        'nf-mdi-car_connected'                           = 'nf-md-car_connected'
        'nf-mdi-car_convertible'                         = 'nf-md-car_convertible'
        'nf-mdi-car_estate'                              = 'nf-md-car_estate'
        'nf-mdi-car_hatchback'                           = 'nf-md-car_hatchback'
        'nf-mdi-car_pickup'                              = 'nf-md-car_pickup'
        'nf-mdi-car_side'                                = 'nf-md-car_side'
        'nf-mdi-car_sports'                              = 'nf-md-car_sports'
        'nf-mdi-car_wash'                                = 'nf-md-car_wash'
        'nf-mdi-caravan'                                 = 'nf-md-caravan'
        'nf-mdi-cards'                                   = 'nf-md-cards'
        'nf-mdi-cards_outline'                           = 'nf-md-cards_outline'
        'nf-mdi-cards_playing_outline'                   = 'nf-md-cards_playing_outline'
        'nf-mdi-cards_variant'                           = 'nf-md-cards_variant'
        'nf-mdi-carrot'                                  = 'nf-md-carrot'
        'nf-mdi-cart'                                    = 'nf-md-cart'
        'nf-mdi-cart_off'                                = 'nf-md-cart_off'
        'nf-mdi-cart_outline'                            = 'nf-md-cart_outline'
        'nf-mdi-cart_plus'                               = 'nf-md-cart_plus'
        'nf-mdi-case_sensitive_alt'                      = 'nf-md-case_sensitive_alt'
        'nf-mdi-cash'                                    = 'nf-md-cash'
        'nf-mdi-cash_100'                                = 'nf-md-cash_100'
        'nf-mdi-cash_multiple'                           = 'nf-md-cash_multiple'
        'nf-mdi-cast'                                    = 'nf-md-cast'
        'nf-mdi-cast_connected'                          = 'nf-md-cast_connected'
        'nf-mdi-cast_off'                                = 'nf-md-cast_off'
        'nf-mdi-castle'                                  = 'nf-md-castle'
        'nf-mdi-cat'                                     = 'nf-md-cat'
        'nf-mdi-cctv'                                    = 'nf-md-cctv'
        'nf-mdi-ceiling_light'                           = 'nf-md-ceiling_light'
        'nf-mdi-cellphone'                               = 'nf-md-cellphone'
        'nf-mdi-cellphone_basic'                         = 'nf-md-cellphone_basic'
        'nf-mdi-cellphone_dock'                          = 'nf-md-cellphone_dock'
        'nf-mdi-cellphone_link'                          = 'nf-md-cellphone_link'
        'nf-mdi-cellphone_link_off'                      = 'nf-md-cellphone_link_off'
        'nf-mdi-cellphone_settings'                      = 'nf-md-cellphone_settings'
        'nf-mdi-cellphone_wireless'                      = 'nf-md-cellphone_wireless'
        'nf-mdi-certificate'                             = 'nf-md-certificate'
        'nf-mdi-chair_school'                            = 'nf-md-chair_school'
        'nf-mdi-chart_arc'                               = 'nf-md-chart_arc'
        'nf-mdi-chart_areaspline'                        = 'nf-md-chart_areaspline'
        'nf-mdi-chart_bar'                               = 'nf-md-chart_bar'
        'nf-mdi-chart_bar_stacked'                       = 'nf-md-chart_bar_stacked'
        'nf-mdi-chart_bubble'                            = 'nf-md-chart_bubble'
        'nf-mdi-chart_donut'                             = 'nf-md-chart_donut'
        'nf-mdi-chart_donut_variant'                     = 'nf-md-chart_donut_variant'
        'nf-mdi-chart_gantt'                             = 'nf-md-chart_gantt'
        'nf-mdi-chart_histogram'                         = 'nf-md-chart_histogram'
        'nf-mdi-chart_line'                              = 'nf-md-chart_line'
        'nf-mdi-chart_line_stacked'                      = 'nf-md-chart_line_stacked'
        'nf-mdi-chart_line_variant'                      = 'nf-md-chart_line_variant'
        'nf-mdi-chart_pie'                               = 'nf-md-chart_pie'
        'nf-mdi-chart_timeline'                          = 'nf-md-chart_timeline'
        'nf-mdi-check'                                   = 'nf-md-check'
        'nf-mdi-check_all'                               = 'nf-md-check_all'
        'nf-mdi-check_circle'                            = 'nf-md-check_circle'
        'nf-mdi-check_circle_outline'                    = 'nf-md-check_circle_outline'
        'nf-mdi-checkbox_blank'                          = 'nf-md-checkbox_blank'
        'nf-mdi-checkbox_blank_circle'                   = 'nf-md-checkbox_blank_circle'
        'nf-mdi-checkbox_blank_circle_outline'           = 'nf-md-checkbox_blank_circle_outline'
        'nf-mdi-checkbox_blank_outline'                  = 'nf-md-checkbox_blank_outline'
        'nf-mdi-checkbox_marked'                         = 'nf-md-checkbox_marked'
        'nf-mdi-checkbox_marked_circle'                  = 'nf-md-checkbox_marked_circle'
        'nf-mdi-checkbox_marked_circle_outline'          = 'nf-md-checkbox_marked_circle_outline'
        'nf-mdi-checkbox_marked_outline'                 = 'nf-md-checkbox_marked_outline'
        'nf-mdi-checkbox_multiple_blank'                 = 'nf-md-checkbox_multiple_blank'
        'nf-mdi-checkbox_multiple_blank_circle'          = 'nf-md-checkbox_multiple_blank_circle'
        'nf-mdi-checkbox_multiple_blank_circle_outline'  = 'nf-md-checkbox_multiple_blank_circle_outline'
        'nf-mdi-checkbox_multiple_blank_outline'         = 'nf-md-checkbox_multiple_blank_outline'
        'nf-mdi-checkbox_multiple_marked'                = 'nf-md-checkbox_multiple_marked'
        'nf-mdi-checkbox_multiple_marked_circle'         = 'nf-md-checkbox_multiple_marked_circle'
        'nf-mdi-checkbox_multiple_marked_circle_outline' = 'nf-md-checkbox_multiple_marked_circle_outline'
        'nf-mdi-checkbox_multiple_marked_outline'        = 'nf-md-checkbox_multiple_marked_outline'
        'nf-mdi-checkerboard'                            = 'nf-md-checkerboard'
        'nf-mdi-chemical_weapon'                         = 'nf-md-chemical_weapon'
        'nf-mdi-chevron_double_down'                     = 'nf-md-chevron_double_down'
        'nf-mdi-chevron_double_left'                     = 'nf-md-chevron_double_left'
        'nf-mdi-chevron_double_right'                    = 'nf-md-chevron_double_right'
        'nf-mdi-chevron_double_up'                       = 'nf-md-chevron_double_up'
        'nf-mdi-chevron_down'                            = 'nf-md-chevron_down'
        'nf-mdi-chevron_left'                            = 'nf-md-chevron_left'
        'nf-mdi-chevron_right'                           = 'nf-md-chevron_right'
        'nf-mdi-chevron_up'                              = 'nf-md-chevron_up'
        'nf-mdi-chili_hot'                               = 'nf-md-chili_hot'
        'nf-mdi-chili_medium'                            = 'nf-md-chili_medium'
        'nf-mdi-chili_mild'                              = 'nf-md-chili_mild'
        'nf-mdi-chip'                                    = 'nf-md-chip'
        'nf-mdi-church'                                  = 'nf-md-church'
        'nf-mdi-city'                                    = 'nf-md-city'
        'nf-mdi-clipboard'                               = 'nf-md-clipboard'
        'nf-mdi-clipboard_account'                       = 'nf-md-clipboard_account'
        'nf-mdi-clipboard_alert'                         = 'nf-md-clipboard_alert'
        'nf-mdi-clipboard_arrow_down'                    = 'nf-md-clipboard_arrow_down'
        'nf-mdi-clipboard_arrow_left'                    = 'nf-md-clipboard_arrow_left'
        'nf-mdi-clipboard_check'                         = 'nf-md-clipboard_check'
        'nf-mdi-clipboard_flow'                          = 'nf-md-clipboard_flow'
        'nf-mdi-clipboard_outline'                       = 'nf-md-clipboard_outline'
        'nf-mdi-clipboard_plus'                          = 'nf-md-clipboard_plus'
        'nf-mdi-clipboard_text'                          = 'nf-md-clipboard_text'
        'nf-mdi-clippy'                                  = 'nf-md-clippy'
        'nf-mdi-clock'                                   = 'nf-md-clock'
        'nf-mdi-clock_alert'                             = 'nf-md-clock_alert'
        'nf-mdi-clock_end'                               = 'nf-md-clock_end'
        'nf-mdi-clock_fast'                              = 'nf-md-clock_fast'
        'nf-mdi-clock_in'                                = 'nf-md-clock_in'
        'nf-mdi-clock_out'                               = 'nf-md-clock_out'
        'nf-mdi-clock_start'                             = 'nf-md-clock_start'
        'nf-mdi-close'                                   = 'nf-md-close'
        'nf-mdi-close_box'                               = 'nf-md-close_box'
        'nf-mdi-close_box_outline'                       = 'nf-md-close_box_outline'
        'nf-mdi-close_circle'                            = 'nf-md-close_circle'
        'nf-mdi-close_circle_outline'                    = 'nf-md-close_circle_outline'
        'nf-mdi-close_network'                           = 'nf-md-close_network'
        'nf-mdi-close_octagon'                           = 'nf-md-close_octagon'
        'nf-mdi-close_octagon_outline'                   = 'nf-md-close_octagon_outline'
        'nf-mdi-close_outline'                           = 'nf-md-close_outline'
        'nf-mdi-closed_caption'                          = 'nf-md-closed_caption'
        'nf-mdi-cloud'                                   = 'nf-md-cloud'
        'nf-mdi-cloud_braces'                            = 'nf-md-cloud_braces'
        'nf-mdi-cloud_check'                             = 'nf-md-cloud_check'
        'nf-mdi-cloud_circle'                            = 'nf-md-cloud_circle'
        'nf-mdi-cloud_download'                          = 'nf-md-cloud_download'
        'nf-mdi-cloud_off_outline'                       = 'nf-md-cloud_off_outline'
        'nf-mdi-cloud_outline'                           = 'nf-md-cloud_outline'
        'nf-mdi-cloud_print'                             = 'nf-md-cloud_print'
        'nf-mdi-cloud_print_outline'                     = 'nf-md-cloud_print_outline'
        'nf-mdi-cloud_sync'                              = 'nf-md-cloud_sync'
        'nf-mdi-cloud_tags'                              = 'nf-md-cloud_tags'
        'nf-mdi-cloud_upload'                            = 'nf-md-cloud_upload'
        'nf-mdi-clover'                                  = 'nf-md-clover'
        'nf-mdi-code_array'                              = 'nf-md-code_array'
        'nf-mdi-code_braces'                             = 'nf-md-code_braces'
        'nf-mdi-code_brackets'                           = 'nf-md-code_brackets'
        'nf-mdi-code_equal'                              = 'nf-md-code_equal'
        'nf-mdi-code_greater_than'                       = 'nf-md-code_greater_than'
        'nf-mdi-code_greater_than_or_equal'              = 'nf-md-code_greater_than_or_equal'
        'nf-mdi-code_less_than'                          = 'nf-md-code_less_than'
        'nf-mdi-code_less_than_or_equal'                 = 'nf-md-code_less_than_or_equal'
        'nf-mdi-code_not_equal'                          = 'nf-md-code_not_equal'
        'nf-mdi-code_not_equal_variant'                  = 'nf-md-code_not_equal_variant'
        'nf-mdi-code_parentheses'                        = 'nf-md-code_parentheses'
        'nf-mdi-code_string'                             = 'nf-md-code_string'
        'nf-mdi-code_tags'                               = 'nf-md-code_tags'
        'nf-mdi-code_tags_check'                         = 'nf-md-code_tags_check'
        'nf-mdi-codepen'                                 = 'nf-md-codepen'
        'nf-mdi-coffee'                                  = 'nf-md-coffee'
        'nf-mdi-coffee_outline'                          = 'nf-md-coffee_outline'
        'nf-mdi-coffee_to_go'                            = 'nf-md-coffee_to_go'
        'nf-mdi-collage'                                 = 'nf-md-collage'
        'nf-mdi-color_helper'                            = 'nf-md-color_helper'
        'nf-mdi-comment'                                 = 'nf-md-comment'
        'nf-mdi-comment_account'                         = 'nf-md-comment_account'
        'nf-mdi-comment_account_outline'                 = 'nf-md-comment_account_outline'
        'nf-mdi-comment_alert'                           = 'nf-md-comment_alert'
        'nf-mdi-comment_alert_outline'                   = 'nf-md-comment_alert_outline'
        'nf-mdi-comment_check'                           = 'nf-md-comment_check'
        'nf-mdi-comment_check_outline'                   = 'nf-md-comment_check_outline'
        'nf-mdi-comment_multiple_outline'                = 'nf-md-comment_multiple_outline'
        'nf-mdi-comment_outline'                         = 'nf-md-comment_outline'
        'nf-mdi-comment_plus_outline'                    = 'nf-md-comment_plus_outline'
        'nf-mdi-comment_processing'                      = 'nf-md-comment_processing'
        'nf-mdi-comment_processing_outline'              = 'nf-md-comment_processing_outline'
        'nf-mdi-comment_question'                        = 'nf-md-comment_question'
        'nf-mdi-comment_question_outline'                = 'nf-md-comment_question_outline'
        'nf-mdi-comment_remove'                          = 'nf-md-comment_remove'
        'nf-mdi-comment_remove_outline'                  = 'nf-md-comment_remove_outline'
        'nf-mdi-comment_text'                            = 'nf-md-comment_text'
        'nf-mdi-comment_text_outline'                    = 'nf-md-comment_text_outline'
        'nf-mdi-compare'                                 = 'nf-md-compare'
        'nf-mdi-compass'                                 = 'nf-md-compass'
        'nf-mdi-compass_outline'                         = 'nf-md-compass_outline'
        'nf-mdi-console'                                 = 'nf-md-console'
        'nf-mdi-console_line'                            = 'nf-md-console_line'
        'nf-mdi-contacts'                                = 'nf-md-contacts'
        'nf-mdi-content_copy'                            = 'nf-md-content_copy'
        'nf-mdi-content_cut'                             = 'nf-md-content_cut'
        'nf-mdi-content_duplicate'                       = 'nf-md-content_duplicate'
        'nf-mdi-content_paste'                           = 'nf-md-content_paste'
        'nf-mdi-content_save'                            = 'nf-md-content_save'
        'nf-mdi-content_save_all'                        = 'nf-md-content_save_all'
        'nf-mdi-content_save_outline'                    = 'nf-md-content_save_outline'
        'nf-mdi-content_save_settings'                   = 'nf-md-content_save_settings'
        'nf-mdi-contrast'                                = 'nf-md-contrast'
        'nf-mdi-contrast_box'                            = 'nf-md-contrast_box'
        'nf-mdi-contrast_circle'                         = 'nf-md-contrast_circle'
        'nf-mdi-cookie'                                  = 'nf-md-cookie'
        'nf-mdi-copyright'                               = 'nf-md-copyright'
        'nf-mdi-corn'                                    = 'nf-md-corn'
        'nf-mdi-counter'                                 = 'nf-md-counter'
        'nf-mdi-cow'                                     = 'nf-md-cow'
        'nf-mdi-creation'                                = 'nf-md-creation'
        'nf-mdi-credit_card'                             = 'nf-md-credit_card'
        'nf-mdi-credit_card_multiple'                    = 'nf-md-credit_card_multiple'
        'nf-mdi-credit_card_off'                         = 'nf-md-credit_card_off'
        'nf-mdi-credit_card_plus'                        = 'nf-md-credit_card_plus'
        'nf-mdi-credit_card_scan'                        = 'nf-md-credit_card_scan'
        'nf-mdi-crop'                                    = 'nf-md-crop'
        'nf-mdi-crop_free'                               = 'nf-md-crop_free'
        'nf-mdi-crop_landscape'                          = 'nf-md-crop_landscape'
        'nf-mdi-crop_portrait'                           = 'nf-md-crop_portrait'
        'nf-mdi-crop_rotate'                             = 'nf-md-crop_rotate'
        'nf-mdi-crop_square'                             = 'nf-md-crop_square'
        'nf-mdi-crosshairs'                              = 'nf-md-crosshairs'
        'nf-mdi-crosshairs_gps'                          = 'nf-md-crosshairs_gps'
        'nf-mdi-crown'                                   = 'nf-md-crown'
        'nf-mdi-cube'                                    = 'nf-md-cube'
        'nf-mdi-cube_outline'                            = 'nf-md-cube_outline'
        'nf-mdi-cube_send'                               = 'nf-md-cube_send'
        'nf-mdi-cube_unfolded'                           = 'nf-md-cube_unfolded'
        'nf-mdi-cup'                                     = 'nf-md-cup'
        'nf-mdi-cup_off'                                 = 'nf-md-cup_off'
        'nf-mdi-cup_water'                               = 'nf-md-cup_water'
        'nf-mdi-currency_btc'                            = 'nf-md-currency_btc'
        'nf-mdi-currency_cny'                            = 'nf-md-currency_cny'
        'nf-mdi-currency_eth'                            = 'nf-md-currency_eth'
        'nf-mdi-currency_eur'                            = 'nf-md-currency_eur'
        'nf-mdi-currency_gbp'                            = 'nf-md-currency_gbp'
        'nf-mdi-currency_inr'                            = 'nf-md-currency_inr'
        'nf-mdi-currency_jpy'                            = 'nf-md-currency_jpy'
        'nf-mdi-currency_krw'                            = 'nf-md-currency_krw'
        'nf-mdi-currency_ngn'                            = 'nf-md-currency_ngn'
        'nf-mdi-currency_rub'                            = 'nf-md-currency_rub'
        'nf-mdi-currency_sign'                           = 'nf-md-currency_sign'
        'nf-mdi-currency_try'                            = 'nf-md-currency_try'
        'nf-mdi-currency_twd'                            = 'nf-md-currency_twd'
        'nf-mdi-currency_usd'                            = 'nf-md-currency_usd'
        'nf-mdi-currency_usd_off'                        = 'nf-md-currency_usd_off'
        'nf-mdi-cursor_default'                          = 'nf-md-cursor_default'
        'nf-mdi-cursor_default_outline'                  = 'nf-md-cursor_default_outline'
        'nf-mdi-cursor_move'                             = 'nf-md-cursor_move'
        'nf-mdi-cursor_pointer'                          = 'nf-md-cursor_pointer'
        'nf-mdi-cursor_text'                             = 'nf-md-cursor_text'
        'nf-mdi-database'                                = 'nf-md-database'
        'nf-mdi-database_minus'                          = 'nf-md-database_minus'
        'nf-mdi-database_plus'                           = 'nf-md-database_plus'
        'nf-mdi-debug_step_into'                         = 'nf-md-debug_step_into'
        'nf-mdi-debug_step_out'                          = 'nf-md-debug_step_out'
        'nf-mdi-debug_step_over'                         = 'nf-md-debug_step_over'
        'nf-mdi-decagram'                                = 'nf-md-decagram'
        'nf-mdi-decagram_outline'                        = 'nf-md-decagram_outline'
        'nf-mdi-decimal_decrease'                        = 'nf-md-decimal_decrease'
        'nf-mdi-decimal_increase'                        = 'nf-md-decimal_increase'
        'nf-mdi-delete'                                  = 'nf-md-delete'
        'nf-mdi-delete_circle'                           = 'nf-md-delete_circle'
        'nf-mdi-delete_empty'                            = 'nf-md-delete_empty'
        'nf-mdi-delete_forever'                          = 'nf-md-delete_forever'
        'nf-mdi-delete_restore'                          = 'nf-md-delete_restore'
        'nf-mdi-delete_sweep'                            = 'nf-md-delete_sweep'
        'nf-mdi-delete_variant'                          = 'nf-md-delete_variant'
        'nf-mdi-delta'                                   = 'nf-md-delta'
        'nf-mdi-deskphone'                               = 'nf-md-deskphone'
        'nf-mdi-desktop_classic'                         = 'nf-md-desktop_classic'
        'nf-mdi-desktop_mac'                             = 'nf-md-desktop_mac'
        'nf-mdi-desktop_tower'                           = 'nf-md-desktop_tower'
        'nf-mdi-details'                                 = 'nf-md-details'
        'nf-mdi-developer_board'                         = 'nf-md-developer_board'
        'nf-mdi-deviantart'                              = 'nf-md-deviantart'
        'nf-mdi-dialpad'                                 = 'nf-md-dialpad'
        'nf-mdi-diamond'                                 = 'nf-md-diamond'
        'nf-mdi-dice_1'                                  = 'nf-md-dice_1'
        'nf-mdi-dice_2'                                  = 'nf-md-dice_2'
        'nf-mdi-dice_3'                                  = 'nf-md-dice_3'
        'nf-mdi-dice_4'                                  = 'nf-md-dice_4'
        'nf-mdi-dice_5'                                  = 'nf-md-dice_5'
        'nf-mdi-dice_6'                                  = 'nf-md-dice_6'
        'nf-mdi-dice_d10'                                = 'nf-md-dice_d10'
        'nf-mdi-dice_d20'                                = 'nf-md-dice_d20'
        'nf-mdi-dice_d4'                                 = 'nf-md-dice_d4'
        'nf-mdi-dice_d6'                                 = 'nf-md-dice_d6'
        'nf-mdi-dice_d8'                                 = 'nf-md-dice_d8'
        'nf-mdi-dice_multiple'                           = 'nf-md-dice_multiple'
        'nf-mdi-dip_switch'                              = 'nf-md-dip_switch'
        'nf-mdi-directions'                              = 'nf-md-directions'
        'nf-mdi-directions_fork'                         = 'nf-md-directions_fork'
        'nf-mdi-discord'                                 = 'nf-md-discord'
        'nf-mdi-disqus'                                  = 'nf-md-disqus'
        'nf-mdi-division'                                = 'nf-md-division'
        'nf-mdi-division_box'                            = 'nf-md-division_box'
        'nf-mdi-dna'                                     = 'nf-md-dna'
        'nf-mdi-dns'                                     = 'nf-md-dns'
        'nf-mdi-dolby'                                   = 'nf-md-dolby'
        'nf-mdi-domain'                                  = 'nf-md-domain'
        'nf-mdi-donkey'                                  = 'nf-md-donkey'
        'nf-mdi-door'                                    = 'nf-md-door'
        'nf-mdi-door_closed'                             = 'nf-md-door_closed'
        'nf-mdi-door_open'                               = 'nf-md-door_open'
        'nf-mdi-dots_horizontal'                         = 'nf-md-dots_horizontal'
        'nf-mdi-dots_horizontal_circle'                  = 'nf-md-dots_horizontal_circle'
        'nf-mdi-dots_vertical'                           = 'nf-md-dots_vertical'
        'nf-mdi-dots_vertical_circle'                    = 'nf-md-dots_vertical_circle'
        'nf-mdi-download'                                = 'nf-md-download'
        'nf-mdi-download_network'                        = 'nf-md-download_network'
        'nf-mdi-drag'                                    = 'nf-md-drag'
        'nf-mdi-drag_horizontal'                         = 'nf-md-drag_horizontal'
        'nf-mdi-drag_vertical'                           = 'nf-md-drag_vertical'
        'nf-mdi-drawing'                                 = 'nf-md-drawing'
        'nf-mdi-drawing_box'                             = 'nf-md-drawing_box'
        'nf-mdi-drone'                                   = 'nf-md-drone'
        'nf-mdi-dropbox'                                 = 'nf-md-dropbox'
        'nf-mdi-drupal'                                  = 'nf-md-drupal'
        'nf-mdi-duck'                                    = 'nf-md-duck'
        'nf-mdi-dumbbell'                                = 'nf-md-dumbbell'
        'nf-mdi-ear_hearing'                             = 'nf-md-ear_hearing'
        'nf-mdi-earth'                                   = 'nf-md-earth'
        'nf-mdi-earth_box'                               = 'nf-md-earth_box'
        'nf-mdi-earth_box_off'                           = 'nf-md-earth_box_off'
        'nf-mdi-earth_off'                               = 'nf-md-earth_off'
        'nf-mdi-eject'                                   = 'nf-md-eject'
        'nf-mdi-elephant'                                = 'nf-md-elephant'
        'nf-mdi-elevation_decline'                       = 'nf-md-elevation_decline'
        'nf-mdi-elevation_rise'                          = 'nf-md-elevation_rise'
        'nf-mdi-elevator'                                = 'nf-md-elevator'
        'nf-mdi-email'                                   = 'nf-md-email'
        'nf-mdi-email_alert'                             = 'nf-md-email_alert'
        'nf-mdi-email_open'                              = 'nf-md-email_open'
        'nf-mdi-email_open_outline'                      = 'nf-md-email_open_outline'
        'nf-mdi-email_outline'                           = 'nf-md-email_outline'
        'nf-mdi-email_variant'                           = 'nf-md-email_variant'
        'nf-mdi-emby'                                    = 'nf-md-emby'
        'nf-mdi-emoticon'                                = 'nf-md-emoticon'
        'nf-mdi-emoticon_cool'                           = 'nf-md-emoticon_cool'
        'nf-mdi-emoticon_dead'                           = 'nf-md-emoticon_dead'
        'nf-mdi-emoticon_devil'                          = 'nf-md-emoticon_devil'
        'nf-mdi-emoticon_excited'                        = 'nf-md-emoticon_excited'
        'nf-mdi-emoticon_happy'                          = 'nf-md-emoticon_happy'
        'nf-mdi-emoticon_neutral'                        = 'nf-md-emoticon_neutral'
        'nf-mdi-emoticon_poop'                           = 'nf-md-emoticon_poop'
        'nf-mdi-emoticon_sad'                            = 'nf-md-emoticon_sad'
        'nf-mdi-emoticon_tongue'                         = 'nf-md-emoticon_tongue'
        'nf-mdi-engine'                                  = 'nf-md-engine'
        'nf-mdi-engine_outline'                          = 'nf-md-engine_outline'
        'nf-mdi-equal'                                   = 'nf-md-equal'
        'nf-mdi-equal_box'                               = 'nf-md-equal_box'
        'nf-mdi-eraser'                                  = 'nf-md-eraser'
        'nf-mdi-eraser_variant'                          = 'nf-md-eraser_variant'
        'nf-mdi-escalator'                               = 'nf-md-escalator'
        'nf-mdi-ethernet'                                = 'nf-md-ethernet'
        'nf-mdi-ethernet_cable'                          = 'nf-md-ethernet_cable'
        'nf-mdi-ethernet_cable_off'                      = 'nf-md-ethernet_cable_off'
        'nf-mdi-ev_station'                              = 'nf-md-ev_station'
        'nf-mdi-evernote'                                = 'nf-md-evernote'
        'nf-mdi-exclamation'                             = 'nf-md-exclamation'
        'nf-mdi-exit_to_app'                             = 'nf-md-exit_to_app'
        'nf-mdi-export'                                  = 'nf-md-export'
        'nf-mdi-eye'                                     = 'nf-md-eye'
        'nf-mdi-eye_off'                                 = 'nf-md-eye_off'
        'nf-mdi-eye_off_outline'                         = 'nf-md-eye_off_outline'
        'nf-mdi-eye_outline'                             = 'nf-md-eye_outline'
        'nf-mdi-eyedropper'                              = 'nf-md-eyedropper'
        'nf-mdi-eyedropper_variant'                      = 'nf-md-eyedropper_variant'
        'nf-mdi-facebook'                                = 'nf-md-facebook'
        'nf-mdi-facebook_messenger'                      = 'nf-md-facebook_messenger'
        'nf-mdi-factory'                                 = 'nf-md-factory'
        'nf-mdi-fan'                                     = 'nf-md-fan'
        'nf-mdi-fan_off'                                 = 'nf-md-fan_off'
        'nf-mdi-fast_forward'                            = 'nf-md-fast_forward'
        'nf-mdi-fast_forward_outline'                    = 'nf-md-fast_forward_outline'
        'nf-mdi-fax'                                     = 'nf-md-fax'
        'nf-mdi-feather'                                 = 'nf-md-feather'
        'nf-mdi-ferry'                                   = 'nf-md-ferry'
        'nf-mdi-file'                                    = 'nf-md-file'
        'nf-mdi-file_account'                            = 'nf-md-file_account'
        'nf-mdi-file_chart'                              = 'nf-md-file_chart'
        'nf-mdi-file_check'                              = 'nf-md-file_check'
        'nf-mdi-file_cloud'                              = 'nf-md-file_cloud'
        'nf-mdi-file_delimited'                          = 'nf-md-file_delimited'
        'nf-mdi-file_document'                           = 'nf-md-file_document'
        'nf-mdi-file_excel'                              = 'nf-md-file_excel'
        'nf-mdi-file_excel_box'                          = 'nf-md-file_excel_box'
        'nf-mdi-file_export'                             = 'nf-md-file_export'
        'nf-mdi-file_find'                               = 'nf-md-file_find'
        'nf-mdi-file_hidden'                             = 'nf-md-file_hidden'
        'nf-mdi-file_image'                              = 'nf-md-file_image'
        'nf-mdi-file_import'                             = 'nf-md-file_import'
        'nf-mdi-file_lock'                               = 'nf-md-file_lock'
        'nf-mdi-file_multiple'                           = 'nf-md-file_multiple'
        'nf-mdi-file_music'                              = 'nf-md-file_music'
        'nf-mdi-file_outline'                            = 'nf-md-file_outline'
        'nf-mdi-file_pdf'                                = 'nf-fa-file_pdf_o'
        'nf-mdi-file_pdf_box'                            = 'nf-md-file_pdf_box'
        'nf-mdi-file_percent'                            = 'nf-md-file_percent'
        'nf-mdi-file_plus'                               = 'nf-md-file_plus'
        'nf-mdi-file_powerpoint'                         = 'nf-md-file_powerpoint'
        'nf-mdi-file_powerpoint_box'                     = 'nf-md-file_powerpoint_box'
        'nf-mdi-file_presentation_box'                   = 'nf-md-file_presentation_box'
        'nf-mdi-file_restore'                            = 'nf-md-file_restore'
        'nf-mdi-file_send'                               = 'nf-md-file_send'
        'nf-mdi-file_tree'                               = 'nf-md-file_tree'
        'nf-mdi-file_video'                              = 'nf-md-file_video'
        'nf-mdi-file_word'                               = 'nf-md-file_word'
        'nf-mdi-file_word_box'                           = 'nf-md-file_word_box'
        'nf-mdi-file_xml'                                = 'nf-md-xml'
        'nf-mdi-film'                                    = 'nf-md-film'
        'nf-mdi-filmstrip'                               = 'nf-md-filmstrip'
        'nf-mdi-filmstrip_off'                           = 'nf-md-filmstrip_off'
        'nf-mdi-filter'                                  = 'nf-md-filter'
        'nf-mdi-filter_outline'                          = 'nf-md-filter_outline'
        'nf-mdi-filter_remove'                           = 'nf-md-filter_remove'
        'nf-mdi-filter_remove_outline'                   = 'nf-md-filter_remove_outline'
        'nf-mdi-filter_variant'                          = 'nf-md-filter_variant'
        'nf-mdi-finance'                                 = 'nf-md-finance'
        'nf-mdi-find_replace'                            = 'nf-md-find_replace'
        'nf-mdi-fingerprint'                             = 'nf-md-fingerprint'
        'nf-mdi-fire'                                    = 'nf-md-fire'
        'nf-mdi-firefox'                                 = 'nf-md-firefox'
        'nf-mdi-fish'                                    = 'nf-md-fish'
        'nf-mdi-flag'                                    = 'nf-md-flag'
        'nf-mdi-flag_checkered'                          = 'nf-md-flag_checkered'
        'nf-mdi-flag_outline'                            = 'nf-md-flag_outline'
        'nf-mdi-flag_triangle'                           = 'nf-md-flag_triangle'
        'nf-mdi-flag_variant'                            = 'nf-md-flag_variant'
        'nf-mdi-flag_variant_outline'                    = 'nf-md-flag_variant_outline'
        'nf-mdi-flash'                                   = 'nf-md-flash'
        'nf-mdi-flash_auto'                              = 'nf-md-flash_auto'
        'nf-mdi-flash_off'                               = 'nf-md-flash_off'
        'nf-mdi-flash_outline'                           = 'nf-md-flash_outline'
        'nf-mdi-flash_red_eye'                           = 'nf-md-flash_red_eye'
        'nf-mdi-flashlight'                              = 'nf-md-flashlight'
        'nf-mdi-flashlight_off'                          = 'nf-md-flashlight_off'
        'nf-mdi-flask'                                   = 'nf-md-flask'
        'nf-mdi-flask_empty'                             = 'nf-md-flask_empty'
        'nf-mdi-flask_empty_outline'                     = 'nf-md-flask_empty_outline'
        'nf-mdi-flask_outline'                           = 'nf-md-flask_outline'
        'nf-mdi-flip_to_back'                            = 'nf-md-flip_to_back'
        'nf-mdi-flip_to_front'                           = 'nf-md-flip_to_front'
        'nf-mdi-floor_plan'                              = 'nf-md-floor_plan'
        'nf-mdi-floppy'                                  = 'nf-md-floppy'
        'nf-mdi-flower'                                  = 'nf-md-flower'
        'nf-mdi-folder'                                  = 'nf-md-folder'
        'nf-mdi-folder_account'                          = 'nf-md-folder_account'
        'nf-mdi-folder_download'                         = 'nf-md-folder_download'
        'nf-mdi-folder_google_drive'                     = 'nf-md-folder_google_drive'
        'nf-mdi-folder_image'                            = 'nf-md-folder_image'
        'nf-mdi-folder_lock'                             = 'nf-md-folder_lock'
        'nf-mdi-folder_lock_open'                        = 'nf-md-folder_lock_open'
        'nf-mdi-folder_move'                             = 'nf-md-folder_move'
        'nf-mdi-folder_multiple'                         = 'nf-md-folder_multiple'
        'nf-mdi-folder_multiple_image'                   = 'nf-md-folder_multiple_image'
        'nf-mdi-folder_multiple_outline'                 = 'nf-md-folder_multiple_outline'
        'nf-mdi-folder_open'                             = 'nf-md-folder_open'
        'nf-mdi-folder_outline'                          = 'nf-md-folder_outline'
        'nf-mdi-folder_plus'                             = 'nf-md-folder_plus'
        'nf-mdi-folder_remove'                           = 'nf-md-folder_remove'
        'nf-mdi-folder_star'                             = 'nf-md-folder_star'
        'nf-mdi-folder_upload'                           = 'nf-md-folder_upload'
        'nf-mdi-font_awesome'                            = 'nf-md-font_awesome'
        'nf-mdi-food'                                    = 'nf-md-food'
        'nf-mdi-food_apple'                              = 'nf-md-food_apple'
        'nf-mdi-food_croissant'                          = 'nf-md-food_croissant'
        'nf-mdi-food_fork_drink'                         = 'nf-md-food_fork_drink'
        'nf-mdi-food_off'                                = 'nf-md-food_off'
        'nf-mdi-food_variant'                            = 'nf-md-food_variant'
        'nf-mdi-football'                                = 'nf-md-football'
        'nf-mdi-football_australian'                     = 'nf-md-football_australian'
        'nf-mdi-football_helmet'                         = 'nf-md-football_helmet'
        'nf-mdi-forklift'                                = 'nf-md-forklift'
        'nf-mdi-format_align_bottom'                     = 'nf-md-format_align_bottom'
        'nf-mdi-format_align_center'                     = 'nf-md-format_align_center'
        'nf-mdi-format_align_justify'                    = 'nf-md-format_align_justify'
        'nf-mdi-format_align_left'                       = 'nf-md-format_align_left'
        'nf-mdi-format_align_middle'                     = 'nf-md-format_align_middle'
        'nf-mdi-format_align_right'                      = 'nf-md-format_align_right'
        'nf-mdi-format_align_top'                        = 'nf-md-format_align_top'
        'nf-mdi-format_annotation_plus'                  = 'nf-md-format_annotation_plus'
        'nf-mdi-format_bold'                             = 'nf-md-format_bold'
        'nf-mdi-format_clear'                            = 'nf-md-format_clear'
        'nf-mdi-format_color_fill'                       = 'nf-md-format_color_fill'
        'nf-mdi-format_color_text'                       = 'nf-md-format_color_text'
        'nf-mdi-format_float_center'                     = 'nf-md-format_float_center'
        'nf-mdi-format_float_left'                       = 'nf-md-format_float_left'
        'nf-mdi-format_float_none'                       = 'nf-md-format_float_none'
        'nf-mdi-format_float_right'                      = 'nf-md-format_float_right'
        'nf-mdi-format_font'                             = 'nf-md-format_font'
        'nf-mdi-format_header_1'                         = 'nf-md-format_header_1'
        'nf-mdi-format_header_2'                         = 'nf-md-format_header_2'
        'nf-mdi-format_header_3'                         = 'nf-md-format_header_3'
        'nf-mdi-format_header_4'                         = 'nf-md-format_header_4'
        'nf-mdi-format_header_5'                         = 'nf-md-format_header_5'
        'nf-mdi-format_header_6'                         = 'nf-md-format_header_6'
        'nf-mdi-format_header_decrease'                  = 'nf-md-format_header_decrease'
        'nf-mdi-format_header_equal'                     = 'nf-md-format_header_equal'
        'nf-mdi-format_header_increase'                  = 'nf-md-format_header_increase'
        'nf-mdi-format_header_pound'                     = 'nf-md-format_header_pound'
        'nf-mdi-format_horizontal_align_center'          = 'nf-md-format_horizontal_align_center'
        'nf-mdi-format_horizontal_align_left'            = 'nf-md-format_horizontal_align_left'
        'nf-mdi-format_horizontal_align_right'           = 'nf-md-format_horizontal_align_right'
        'nf-mdi-format_indent_decrease'                  = 'nf-md-format_indent_decrease'
        'nf-mdi-format_indent_increase'                  = 'nf-md-format_indent_increase'
        'nf-mdi-format_italic'                           = 'nf-md-format_italic'
        'nf-mdi-format_line_spacing'                     = 'nf-md-format_line_spacing'
        'nf-mdi-format_line_style'                       = 'nf-md-format_line_style'
        'nf-mdi-format_line_weight'                      = 'nf-md-format_line_weight'
        'nf-mdi-format_list_bulleted'                    = 'nf-md-format_list_bulleted'
        'nf-mdi-format_list_bulleted_type'               = 'nf-md-format_list_bulleted_type'
        'nf-mdi-format_list_checks'                      = 'nf-md-format_list_checks'
        'nf-mdi-format_page_break'                       = 'nf-md-format_page_break'
        'nf-mdi-format_paint'                            = 'nf-md-format_paint'
        'nf-mdi-format_paragraph'                        = 'nf-md-format_paragraph'
        'nf-mdi-format_pilcrow'                          = 'nf-md-format_pilcrow'
        'nf-mdi-format_quote_close'                      = 'nf-md-format_quote_close'
        'nf-mdi-format_quote_open'                       = 'nf-md-format_quote_open'
        'nf-mdi-format_rotate_90'                        = 'nf-md-format_rotate_90'
        'nf-mdi-format_section'                          = 'nf-md-format_section'
        'nf-mdi-format_size'                             = 'nf-md-format_size'
        'nf-mdi-format_strikethrough'                    = 'nf-md-format_strikethrough'
        'nf-mdi-format_strikethrough_variant'            = 'nf-md-format_strikethrough_variant'
        'nf-mdi-format_subscript'                        = 'nf-md-format_subscript'
        'nf-mdi-format_superscript'                      = 'nf-md-format_superscript'
        'nf-mdi-format_text'                             = 'nf-md-format_text'
        'nf-mdi-format_textdirection_l_to_r'             = 'nf-md-format_textdirection_l_to_r'
        'nf-mdi-format_textdirection_r_to_l'             = 'nf-md-format_textdirection_r_to_l'
        'nf-mdi-format_title'                            = 'nf-md-format_title'
        'nf-mdi-format_underline'                        = 'nf-md-format_underline'
        'nf-mdi-format_vertical_align_bottom'            = 'nf-md-format_vertical_align_bottom'
        'nf-mdi-format_vertical_align_center'            = 'nf-md-format_vertical_align_center'
        'nf-mdi-format_vertical_align_top'               = 'nf-md-format_vertical_align_top'
        'nf-mdi-format_wrap_inline'                      = 'nf-md-format_wrap_inline'
        'nf-mdi-format_wrap_square'                      = 'nf-md-format_wrap_square'
        'nf-mdi-format_wrap_tight'                       = 'nf-md-format_wrap_tight'
        'nf-mdi-format_wrap_top_bottom'                  = 'nf-md-format_wrap_top_bottom'
        'nf-mdi-forum'                                   = 'nf-md-forum'
        'nf-mdi-forum_outline'                           = 'nf-md-forum_outline'
        'nf-mdi-forward'                                 = 'nf-md-forward'
        'nf-mdi-fridge'                                  = 'nf-md-fridge'
        'nf-mdi-fuel'                                    = 'nf-md-fuel'
        'nf-mdi-fullscreen'                              = 'nf-md-fullscreen'
        'nf-mdi-fullscreen_exit'                         = 'nf-md-fullscreen_exit'
        'nf-mdi-function'                                = 'nf-md-function'
        'nf-mdi-gamepad'                                 = 'nf-md-gamepad'
        'nf-mdi-gamepad_variant'                         = 'nf-md-gamepad_variant'
        'nf-mdi-garage'                                  = 'nf-md-garage'
        'nf-mdi-garage_open'                             = 'nf-md-garage_open'
        'nf-mdi-gas_cylinder'                            = 'nf-md-gas_cylinder'
        'nf-mdi-gas_station'                             = 'nf-md-gas_station'
        'nf-mdi-gate'                                    = 'nf-md-gate'
        'nf-mdi-gauge'                                   = 'nf-md-gauge'
        'nf-mdi-gavel'                                   = 'nf-md-gavel'
        'nf-mdi-gender_female'                           = 'nf-md-gender_female'
        'nf-mdi-gender_male'                             = 'nf-md-gender_male'
        'nf-mdi-gender_male_female'                      = 'nf-md-gender_male_female'
        'nf-mdi-gender_transgender'                      = 'nf-md-gender_transgender'
        'nf-mdi-gesture'                                 = 'nf-md-gesture'
        'nf-mdi-gesture_double_tap'                      = 'nf-md-gesture_double_tap'
        'nf-mdi-gesture_swipe_down'                      = 'nf-md-gesture_swipe_down'
        'nf-mdi-gesture_swipe_left'                      = 'nf-md-gesture_swipe_left'
        'nf-mdi-gesture_swipe_right'                     = 'nf-md-gesture_swipe_right'
        'nf-mdi-gesture_swipe_up'                        = 'nf-md-gesture_swipe_up'
        'nf-mdi-gesture_tap'                             = 'nf-md-gesture_tap'
        'nf-mdi-gesture_two_double_tap'                  = 'nf-md-gesture_two_double_tap'
        'nf-mdi-gesture_two_tap'                         = 'nf-md-gesture_two_tap'
        'nf-mdi-ghost'                                   = 'nf-md-ghost'
        'nf-mdi-gift'                                    = 'nf-md-gift'
        'nf-mdi-git'                                     = 'nf-md-git'
        'nf-mdi-github_face'                             = 'nf-dev-github_alt'
        'nf-mdi-glass_flute'                             = 'nf-md-glass_flute'
        'nf-mdi-glass_mug'                               = 'nf-md-glass_mug'
        'nf-mdi-glass_stange'                            = 'nf-md-glass_stange'
        'nf-mdi-glass_tulip'                             = 'nf-md-glass_tulip'
        'nf-mdi-glasses'                                 = 'nf-md-glasses'
        'nf-mdi-gmail'                                   = 'nf-md-gmail'
        'nf-mdi-gnome'                                   = 'nf-md-gnome'
        'nf-mdi-golf'                                    = 'nf-md-golf'
        'nf-mdi-gondola'                                 = 'nf-md-gondola'
        'nf-mdi-google'                                  = 'nf-md-google'
        'nf-mdi-google_analytics'                        = 'nf-md-google_analytics'
        'nf-mdi-google_assistant'                        = 'nf-md-google_assistant'
        'nf-mdi-google_cardboard'                        = 'nf-md-google_cardboard'
        'nf-mdi-google_chrome'                           = 'nf-md-google_chrome'
        'nf-mdi-google_circles'                          = 'nf-md-google_circles'
        'nf-mdi-google_circles_communities'              = 'nf-md-google_circles_communities'
        'nf-mdi-google_circles_extended'                 = 'nf-md-google_circles_extended'
        'nf-mdi-google_circles_group'                    = 'nf-md-google_circles_group'
        'nf-mdi-google_controller'                       = 'nf-md-google_controller'
        'nf-mdi-google_controller_off'                   = 'nf-md-google_controller_off'
        'nf-mdi-google_drive'                            = 'nf-md-google_drive'
        'nf-mdi-google_earth'                            = 'nf-md-google_earth'
        'nf-mdi-google_glass'                            = 'nf-md-google_glass'
        'nf-mdi-google_home'                             = 'nf-md-google_home'
        'nf-mdi-google_keep'                             = 'nf-md-google_keep'
        'nf-mdi-google_maps'                             = 'nf-md-google_maps'
        'nf-mdi-google_nearby'                           = 'nf-md-google_nearby'
        'nf-mdi-google_play'                             = 'nf-md-google_play'
        'nf-mdi-google_plus'                             = 'nf-md-google_plus'
        'nf-mdi-google_translate'                        = 'nf-md-google_translate'
        'nf-mdi-grease_pencil'                           = 'nf-md-grease_pencil'
        'nf-mdi-grid'                                    = 'nf-md-grid'
        'nf-mdi-grid_large'                              = 'nf-md-grid_large'
        'nf-mdi-grid_off'                                = 'nf-md-grid_off'
        'nf-mdi-group'                                   = 'nf-md-group'
        'nf-mdi-guitar_acoustic'                         = 'nf-md-guitar_acoustic'
        'nf-mdi-guitar_electric'                         = 'nf-md-guitar_electric'
        'nf-mdi-guitar_pick'                             = 'nf-md-guitar_pick'
        'nf-mdi-guitar_pick_outline'                     = 'nf-md-guitar_pick_outline'
        'nf-mdi-guy_fawkes_mask'                         = 'nf-md-guy_fawkes_mask'
        'nf-mdi-hamburger'                               = 'nf-md-hamburger'
        'nf-mdi-hand_pointing_right'                     = 'nf-md-hand_pointing_right'
        'nf-mdi-hanger'                                  = 'nf-md-hanger'
        'nf-mdi-harddisk'                                = 'nf-md-harddisk'
        'nf-mdi-headphones'                              = 'nf-md-headphones'
        'nf-mdi-headphones_box'                          = 'nf-md-headphones_box'
        'nf-mdi-headphones_off'                          = 'nf-md-headphones_off'
        'nf-mdi-headphones_settings'                     = 'nf-md-headphones_settings'
        'nf-mdi-headset'                                 = 'nf-md-headset'
        'nf-mdi-headset_dock'                            = 'nf-md-headset_dock'
        'nf-mdi-headset_off'                             = 'nf-md-headset_off'
        'nf-mdi-heart'                                   = 'nf-md-heart'
        'nf-mdi-heart_box'                               = 'nf-md-heart_box'
        'nf-mdi-heart_box_outline'                       = 'nf-md-heart_box_outline'
        'nf-mdi-heart_broken'                            = 'nf-md-heart_broken'
        'nf-mdi-heart_half'                              = 'nf-md-heart_half'
        'nf-mdi-heart_half_full'                         = 'nf-md-heart_half_full'
        'nf-mdi-heart_half_outline'                      = 'nf-md-heart_half_outline'
        'nf-mdi-heart_off'                               = 'nf-md-heart_off'
        'nf-mdi-heart_outline'                           = 'nf-md-heart_outline'
        'nf-mdi-heart_pulse'                             = 'nf-md-heart_pulse'
        'nf-mdi-help'                                    = 'nf-md-help'
        'nf-mdi-help_box'                                = 'nf-md-help_box'
        'nf-mdi-help_circle'                             = 'nf-md-help_circle'
        'nf-mdi-help_circle_outline'                     = 'nf-md-help_circle_outline'
        'nf-mdi-help_network'                            = 'nf-md-help_network'
        'nf-mdi-hexagon'                                 = 'nf-md-hexagon'
        'nf-mdi-hexagon_multiple'                        = 'nf-md-hexagon_multiple'
        'nf-mdi-hexagon_outline'                         = 'nf-md-hexagon_outline'
        'nf-mdi-high_definition'                         = 'nf-md-high_definition'
        'nf-mdi-highway'                                 = 'nf-md-highway'
        'nf-mdi-history'                                 = 'nf-md-history'
        'nf-mdi-hololens'                                = 'nf-md-hololens'
        'nf-mdi-home'                                    = 'nf-md-home'
        'nf-mdi-home_account'                            = 'nf-md-home_account'
        'nf-mdi-home_assistant'                          = 'nf-md-home_assistant'
        'nf-mdi-home_automation'                         = 'nf-md-home_automation'
        'nf-mdi-home_circle'                             = 'nf-md-home_circle'
        'nf-mdi-home_heart'                              = 'nf-md-home_heart'
        'nf-mdi-home_map_marker'                         = 'nf-md-home_map_marker'
        'nf-mdi-home_modern'                             = 'nf-md-home_modern'
        'nf-mdi-home_outline'                            = 'nf-md-home_outline'
        'nf-mdi-home_variant'                            = 'nf-md-home_variant'
        'nf-mdi-hook'                                    = 'nf-md-hook'
        'nf-mdi-hook_off'                                = 'nf-md-hook_off'
        'nf-mdi-hops'                                    = 'nf-md-hops'
        'nf-mdi-hospital'                                = 'nf-md-hospital'
        'nf-mdi-hospital_building'                       = 'nf-md-hospital_building'
        'nf-mdi-hospital_marker'                         = 'nf-md-hospital_marker'
        'nf-mdi-hot_tub'                                 = 'nf-md-hot_tub'
        'nf-mdi-hulu'                                    = 'nf-md-hulu'
        'nf-mdi-human'                                   = 'nf-md-human'
        'nf-mdi-human_child'                             = 'nf-md-human_child'
        'nf-mdi-human_female'                            = 'nf-md-human_female'
        'nf-mdi-human_greeting'                          = 'nf-md-human_greeting'
        'nf-mdi-human_handsdown'                         = 'nf-md-human_handsdown'
        'nf-mdi-human_handsup'                           = 'nf-md-human_handsup'
        'nf-mdi-human_male'                              = 'nf-md-human_male'
        'nf-mdi-human_male_female'                       = 'nf-md-human_male_female'
        'nf-mdi-human_pregnant'                          = 'nf-md-human_pregnant'
        'nf-mdi-humble_bundle'                           = 'nf-md-humble_bundle'
        'nf-mdi-ice_cream'                               = 'nf-md-ice_cream'
        'nf-mdi-image'                                   = 'nf-md-image'
        'nf-mdi-image_album'                             = 'nf-md-image_album'
        'nf-mdi-image_area'                              = 'nf-md-image_area'
        'nf-mdi-image_area_close'                        = 'nf-md-image_area_close'
        'nf-mdi-image_broken'                            = 'nf-md-image_broken'
        'nf-mdi-image_broken_variant'                    = 'nf-md-image_broken_variant'
        'nf-mdi-image_filter_black_white'                = 'nf-md-image_filter_black_white'
        'nf-mdi-image_filter_center_focus'               = 'nf-md-image_filter_center_focus'
        'nf-mdi-image_filter_center_focus_weak'          = 'nf-md-image_filter_center_focus_weak'
        'nf-mdi-image_filter_drama'                      = 'nf-md-image_filter_drama'
        'nf-mdi-image_filter_frames'                     = 'nf-md-image_filter_frames'
        'nf-mdi-image_filter_hdr'                        = 'nf-md-image_filter_hdr'
        'nf-mdi-image_filter_none'                       = 'nf-md-image_filter_none'
        'nf-mdi-image_filter_tilt_shift'                 = 'nf-md-image_filter_tilt_shift'
        'nf-mdi-image_filter_vintage'                    = 'nf-md-image_filter_vintage'
        'nf-mdi-image_multiple'                          = 'nf-md-image_multiple'
        'nf-mdi-image_off'                               = 'nf-md-image_off'
        'nf-mdi-import'                                  = 'nf-md-import'
        'nf-mdi-inbox'                                   = 'nf-md-inbox'
        'nf-mdi-inbox_arrow_down'                        = 'nf-md-inbox_arrow_down'
        'nf-mdi-inbox_arrow_up'                          = 'nf-md-inbox_arrow_up'
        'nf-mdi-incognito'                               = 'nf-md-incognito'
        'nf-mdi-infinity'                                = 'nf-md-infinity'
        'nf-mdi-information'                             = 'nf-md-information'
        'nf-mdi-information_outline'                     = 'nf-md-information_outline'
        'nf-mdi-information_variant'                     = 'nf-md-information_variant'
        'nf-mdi-instagram'                               = 'nf-md-instagram'
        'nf-mdi-invert_colors'                           = 'nf-md-invert_colors'
        'nf-mdi-jeepney'                                 = 'nf-md-jeepney'
        'nf-mdi-jira'                                    = 'nf-md-jira'
        'nf-mdi-jsfiddle'                                = 'nf-md-jsfiddle'
        'nf-mdi-karate'                                  = 'nf-md-karate'
        'nf-mdi-keg'                                     = 'nf-md-keg'
        'nf-mdi-kettle'                                  = 'nf-md-kettle'
        'nf-mdi-key'                                     = 'nf-md-key'
        'nf-mdi-key_change'                              = 'nf-md-key_change'
        'nf-mdi-key_minus'                               = 'nf-md-key_minus'
        'nf-mdi-key_plus'                                = 'nf-md-key_plus'
        'nf-mdi-key_remove'                              = 'nf-md-key_remove'
        'nf-mdi-key_variant'                             = 'nf-md-key_variant'
        'nf-mdi-keyboard'                                = 'nf-md-keyboard'
        'nf-mdi-keyboard_backspace'                      = 'nf-md-keyboard_backspace'
        'nf-mdi-keyboard_caps'                           = 'nf-md-keyboard_caps'
        'nf-mdi-keyboard_close'                          = 'nf-md-keyboard_close'
        'nf-mdi-keyboard_off'                            = 'nf-md-keyboard_off'
        'nf-mdi-keyboard_return'                         = 'nf-md-keyboard_return'
        'nf-mdi-keyboard_tab'                            = 'nf-md-keyboard_tab'
        'nf-mdi-keyboard_variant'                        = 'nf-md-keyboard_variant'
        'nf-mdi-kickstarter'                             = 'nf-md-kickstarter'
        'nf-mdi-kodi'                                    = 'nf-md-kodi'
        'nf-mdi-label'                                   = 'nf-md-label'
        'nf-mdi-label_outline'                           = 'nf-md-label_outline'
        'nf-mdi-ladybug'                                 = 'nf-md-ladybug'
        'nf-mdi-lambda'                                  = 'nf-md-lambda'
        'nf-mdi-lamp'                                    = 'nf-md-lamp'
        'nf-mdi-lan'                                     = 'nf-md-lan'
        'nf-mdi-lan_connect'                             = 'nf-md-lan_connect'
        'nf-mdi-lan_disconnect'                          = 'nf-md-lan_disconnect'
        'nf-mdi-lan_pending'                             = 'nf-md-lan_pending'
        'nf-mdi-language_c'                              = 'nf-md-language_c'
        'nf-mdi-language_cpp'                            = 'nf-md-language_cpp'
        'nf-mdi-language_csharp'                         = 'nf-md-language_csharp'
        'nf-mdi-language_css3'                           = 'nf-md-language_css3'
        'nf-mdi-language_go'                             = 'nf-md-language_go'
        'nf-mdi-language_html5'                          = 'nf-md-language_html5'
        'nf-mdi-language_javascript'                     = 'nf-md-language_javascript'
        'nf-mdi-language_php'                            = 'nf-md-language_php'
        'nf-mdi-language_python'                         = 'nf-md-language_python'
        'nf-mdi-language_r'                              = 'nf-md-language_r'
        'nf-mdi-language_swift'                          = 'nf-md-language_swift'
        'nf-mdi-language_typescript'                     = 'nf-md-language_typescript'
        'nf-mdi-laptop'                                  = 'nf-md-laptop'
        'nf-mdi-laptop_off'                              = 'nf-md-laptop_off'
        'nf-mdi-lastpass'                                = 'nf-md-lastpass'
        'nf-mdi-launch'                                  = 'nf-md-launch'
        'nf-mdi-lava_lamp'                               = 'nf-md-lava_lamp'
        'nf-mdi-layers'                                  = 'nf-md-layers'
        'nf-mdi-layers_off'                              = 'nf-md-layers_off'
        'nf-mdi-lead_pencil'                             = 'nf-md-lead_pencil'
        'nf-mdi-leaf'                                    = 'nf-md-leaf'
        'nf-mdi-led_off'                                 = 'nf-md-led_off'
        'nf-mdi-led_on'                                  = 'nf-md-led_on'
        'nf-mdi-led_outline'                             = 'nf-md-led_outline'
        'nf-mdi-led_strip'                               = 'nf-md-led_strip'
        'nf-mdi-led_variant_off'                         = 'nf-md-led_variant_off'
        'nf-mdi-led_variant_on'                          = 'nf-md-led_variant_on'
        'nf-mdi-led_variant_outline'                     = 'nf-md-led_variant_outline'
        'nf-mdi-library'                                 = 'nf-md-library'
        'nf-mdi-library_books'                           = 'nf-md-text_box_multiple'
        'nf-mdi-library_music'                           = 'nf-md-music_box_multiple'
        'nf-mdi-lightbulb'                               = 'nf-md-lightbulb'
        'nf-mdi-lightbulb_on'                            = 'nf-md-lightbulb_on'
        'nf-mdi-lightbulb_on_outline'                    = 'nf-md-lightbulb_on_outline'
        'nf-mdi-lightbulb_outline'                       = 'nf-md-lightbulb_outline'
        'nf-mdi-link'                                    = 'nf-md-link'
        'nf-mdi-link_off'                                = 'nf-md-link_off'
        'nf-mdi-link_variant'                            = 'nf-md-link_variant'
        'nf-mdi-link_variant_off'                        = 'nf-md-link_variant_off'
        'nf-mdi-linkedin'                                = 'nf-md-linkedin'
        'nf-mdi-linux'                                   = 'nf-md-linux'
        'nf-mdi-loading'                                 = 'nf-md-loading'
        'nf-mdi-lock'                                    = 'nf-md-lock'
        'nf-mdi-lock_open'                               = 'nf-md-lock_open'
        'nf-mdi-lock_open_outline'                       = 'nf-md-lock_open_outline'
        'nf-mdi-lock_outline'                            = 'nf-md-lock_outline'
        'nf-mdi-lock_pattern'                            = 'nf-md-lock_pattern'
        'nf-mdi-lock_plus'                               = 'nf-md-lock_plus'
        'nf-mdi-lock_reset'                              = 'nf-md-lock_reset'
        'nf-mdi-locker'                                  = 'nf-md-locker'
        'nf-mdi-locker_multiple'                         = 'nf-md-locker_multiple'
        'nf-mdi-login'                                   = 'nf-md-login'
        'nf-mdi-logout'                                  = 'nf-md-logout'
        'nf-mdi-logout_variant'                          = 'nf-md-logout_variant'
        'nf-mdi-looks'                                   = 'nf-md-looks'
        'nf-mdi-loupe'                                   = 'nf-md-loupe'
        'nf-mdi-lumx'                                    = 'nf-md-lumx'
        'nf-mdi-magnet'                                  = 'nf-md-magnet'
        'nf-mdi-magnet_on'                               = 'nf-md-magnet_on'
        'nf-mdi-magnify'                                 = 'nf-md-magnify'
        'nf-mdi-magnify_minus'                           = 'nf-md-magnify_minus'
        'nf-mdi-magnify_minus_outline'                   = 'nf-md-magnify_minus_outline'
        'nf-mdi-magnify_plus'                            = 'nf-md-magnify_plus'
        'nf-mdi-magnify_plus_outline'                    = 'nf-md-magnify_plus_outline'
        'nf-mdi-mailbox'                                 = 'nf-md-mailbox'
        'nf-mdi-map'                                     = 'nf-md-map'
        'nf-mdi-map_marker'                              = 'nf-md-map_marker'
        'nf-mdi-map_marker_circle'                       = 'nf-md-map_marker_circle'
        'nf-mdi-map_marker_minus'                        = 'nf-md-map_marker_minus'
        'nf-mdi-map_marker_multiple'                     = 'nf-md-map_marker_multiple'
        'nf-mdi-map_marker_off'                          = 'nf-md-map_marker_off'
        'nf-mdi-map_marker_outline'                      = 'nf-md-map_marker_outline'
        'nf-mdi-map_marker_plus'                         = 'nf-md-map_marker_plus'
        'nf-mdi-map_marker_radius'                       = 'nf-md-map_marker_radius'
        'nf-mdi-margin'                                  = 'nf-md-margin'
        'nf-mdi-marker'                                  = 'nf-md-marker'
        'nf-mdi-marker_check'                            = 'nf-md-marker_check'
        'nf-mdi-material_ui'                             = 'nf-md-material_ui'
        'nf-mdi-math_compass'                            = 'nf-md-math_compass'
        'nf-mdi-matrix'                                  = 'nf-md-matrix'
        'nf-mdi-medical_bag'                             = 'nf-md-medical_bag'
        'nf-mdi-memory'                                  = 'nf-md-memory'
        'nf-mdi-menu'                                    = 'nf-md-menu'
        'nf-mdi-menu_down'                               = 'nf-md-menu_down'
        'nf-mdi-menu_down_outline'                       = 'nf-md-menu_down_outline'
        'nf-mdi-menu_left'                               = 'nf-md-menu_left'
        'nf-mdi-menu_right'                              = 'nf-md-menu_right'
        'nf-mdi-menu_up'                                 = 'nf-md-menu_up'
        'nf-mdi-menu_up_outline'                         = 'nf-md-menu_up_outline'
        'nf-mdi-message'                                 = 'nf-md-message'
        'nf-mdi-message_alert'                           = 'nf-md-message_alert'
        'nf-mdi-message_bulleted'                        = 'nf-md-message_bulleted'
        'nf-mdi-message_bulleted_off'                    = 'nf-md-message_bulleted_off'
        'nf-mdi-message_draw'                            = 'nf-md-message_draw'
        'nf-mdi-message_image'                           = 'nf-md-message_image'
        'nf-mdi-message_outline'                         = 'nf-md-message_outline'
        'nf-mdi-message_plus'                            = 'nf-md-message_plus'
        'nf-mdi-message_processing'                      = 'nf-md-message_processing'
        'nf-mdi-message_reply'                           = 'nf-md-message_reply'
        'nf-mdi-message_reply_text'                      = 'nf-md-message_reply_text'
        'nf-mdi-message_settings'                        = 'nf-md-message_settings'
        'nf-mdi-message_text'                            = 'nf-md-message_text'
        'nf-mdi-message_text_outline'                    = 'nf-md-message_text_outline'
        'nf-mdi-message_video'                           = 'nf-md-message_video'
        'nf-mdi-meteor'                                  = 'nf-md-meteor'
        'nf-mdi-metronome'                               = 'nf-md-metronome'
        'nf-mdi-metronome_tick'                          = 'nf-md-metronome_tick'
        'nf-mdi-micro_sd'                                = 'nf-md-micro_sd'
        'nf-mdi-microphone'                              = 'nf-md-microphone'
        'nf-mdi-microphone_off'                          = 'nf-md-microphone_off'
        'nf-mdi-microphone_outline'                      = 'nf-md-microphone_outline'
        'nf-mdi-microphone_settings'                     = 'nf-md-microphone_settings'
        'nf-mdi-microphone_variant'                      = 'nf-md-microphone_variant'
        'nf-mdi-microphone_variant_off'                  = 'nf-md-microphone_variant_off'
        'nf-mdi-microscope'                              = 'nf-md-microscope'
        'nf-mdi-microsoft'                               = 'nf-md-microsoft'
        'nf-mdi-minecraft'                               = 'nf-md-minecraft'
        'nf-mdi-minus'                                   = 'nf-md-minus'
        'nf-mdi-minus_box'                               = 'nf-md-minus_box'
        'nf-mdi-minus_box_outline'                       = 'nf-md-minus_box_outline'
        'nf-mdi-minus_circle'                            = 'nf-md-minus_circle'
        'nf-mdi-minus_circle_outline'                    = 'nf-md-minus_circle_outline'
        'nf-mdi-minus_network'                           = 'nf-md-minus_network'
        'nf-mdi-monitor'                                 = 'nf-md-monitor'
        'nf-mdi-monitor_multiple'                        = 'nf-md-monitor_multiple'
        'nf-mdi-more'                                    = 'nf-md-more'
        'nf-mdi-motorbike'                               = 'nf-md-motorbike'
        'nf-mdi-mouse'                                   = 'nf-md-mouse'
        'nf-mdi-mouse_off'                               = 'nf-md-mouse_off'
        'nf-mdi-mouse_variant'                           = 'nf-md-mouse_variant'
        'nf-mdi-mouse_variant_off'                       = 'nf-md-mouse_variant_off'
        'nf-mdi-move_resize'                             = 'nf-md-move_resize'
        'nf-mdi-move_resize_variant'                     = 'nf-md-move_resize_variant'
        'nf-mdi-movie'                                   = 'nf-md-movie'
        'nf-mdi-movie_roll'                              = 'nf-md-movie_roll'
        'nf-mdi-multiplication'                          = 'nf-md-multiplication'
        'nf-mdi-multiplication_box'                      = 'nf-md-multiplication_box'
        'nf-mdi-mushroom'                                = 'nf-md-mushroom'
        'nf-mdi-mushroom_outline'                        = 'nf-md-mushroom_outline'
        'nf-mdi-music'                                   = 'nf-md-music'
        'nf-mdi-music_box'                               = 'nf-md-music_box'
        'nf-mdi-music_box_outline'                       = 'nf-md-music_box_outline'
        'nf-mdi-music_circle'                            = 'nf-md-music_circle'
        'nf-mdi-music_note'                              = 'nf-md-music_note'
        'nf-mdi-music_note_bluetooth'                    = 'nf-md-music_note_bluetooth'
        'nf-mdi-music_note_bluetooth_off'                = 'nf-md-music_note_bluetooth_off'
        'nf-mdi-music_note_half'                         = 'nf-md-music_note_half'
        'nf-mdi-music_note_off'                          = 'nf-md-music_note_off'
        'nf-mdi-music_note_quarter'                      = 'nf-md-music_note_quarter'
        'nf-mdi-music_note_sixteenth'                    = 'nf-md-music_note_sixteenth'
        'nf-mdi-music_note_whole'                        = 'nf-md-music_note_whole'
        'nf-mdi-music_off'                               = 'nf-md-music_off'
        'nf-mdi-nature'                                  = 'nf-md-nature'
        'nf-mdi-nature_people'                           = 'nf-md-nature_people'
        'nf-mdi-navigation'                              = 'nf-md-navigation'
        'nf-mdi-near_me'                                 = 'nf-md-near_me'
        'nf-mdi-needle'                                  = 'nf-md-needle'
        'nf-mdi-netflix'                                 = 'nf-md-netflix'
        'nf-mdi-network'                                 = 'nf-md-network'
        'nf-mdi-new_box'                                 = 'nf-md-new_box'
        'nf-mdi-newspaper'                               = 'nf-md-newspaper'
        'nf-mdi-nfc'                                     = 'nf-md-nfc'
        'nf-mdi-nfc_tap'                                 = 'nf-md-nfc_tap'
        'nf-mdi-nfc_variant'                             = 'nf-md-nfc_variant'
        'nf-mdi-ninja'                                   = 'nf-md-ninja'
        'nf-mdi-nintendo_switch'                         = 'nf-md-nintendo_switch'
        'nf-mdi-nodejs'                                  = 'nf-md-nodejs'
        'nf-mdi-note'                                    = 'nf-md-note'
        'nf-mdi-note_multiple'                           = 'nf-md-note_multiple'
        'nf-mdi-note_multiple_outline'                   = 'nf-md-note_multiple_outline'
        'nf-mdi-note_outline'                            = 'nf-md-note_outline'
        'nf-mdi-note_plus'                               = 'nf-md-note_plus'
        'nf-mdi-note_plus_outline'                       = 'nf-md-note_plus_outline'
        'nf-mdi-note_text'                               = 'nf-md-note_text'
        'nf-mdi-notebook'                                = 'nf-md-notebook'
        'nf-mdi-notification_clear_all'                  = 'nf-md-notification_clear_all'
        'nf-mdi-npm'                                     = 'nf-md-npm'
        'nf-mdi-nuke'                                    = 'nf-md-nuke'
        'nf-mdi-null'                                    = 'nf-md-null'
        'nf-mdi-numeric'                                 = 'nf-md-numeric'
        'nf-mdi-numeric_0_box'                           = 'nf-md-numeric_0_box'
        'nf-mdi-numeric_0_box_multiple_outline'          = 'nf-md-numeric_0_box_multiple_outline'
        'nf-mdi-numeric_0_box_outline'                   = 'nf-md-numeric_0_box_outline'
        'nf-mdi-numeric_1_box'                           = 'nf-md-numeric_1_box'
        'nf-mdi-numeric_1_box_multiple_outline'          = 'nf-md-numeric_1_box_multiple_outline'
        'nf-mdi-numeric_1_box_outline'                   = 'nf-md-numeric_1_box_outline'
        'nf-mdi-numeric_2_box'                           = 'nf-md-numeric_2_box'
        'nf-mdi-numeric_2_box_multiple_outline'          = 'nf-md-numeric_2_box_multiple_outline'
        'nf-mdi-numeric_2_box_outline'                   = 'nf-md-numeric_2_box_outline'
        'nf-mdi-numeric_3_box'                           = 'nf-md-numeric_3_box'
        'nf-mdi-numeric_3_box_multiple_outline'          = 'nf-md-numeric_3_box_multiple_outline'
        'nf-mdi-numeric_3_box_outline'                   = 'nf-md-numeric_3_box_outline'
        'nf-mdi-numeric_4_box'                           = 'nf-md-numeric_4_box'
        'nf-mdi-numeric_4_box_multiple_outline'          = 'nf-md-numeric_4_box_multiple_outline'
        'nf-mdi-numeric_4_box_outline'                   = 'nf-md-numeric_4_box_outline'
        'nf-mdi-numeric_5_box'                           = 'nf-md-numeric_5_box'
        'nf-mdi-numeric_5_box_multiple_outline'          = 'nf-md-numeric_5_box_multiple_outline'
        'nf-mdi-numeric_5_box_outline'                   = 'nf-md-numeric_5_box_outline'
        'nf-mdi-numeric_6_box'                           = 'nf-md-numeric_6_box'
        'nf-mdi-numeric_6_box_multiple_outline'          = 'nf-md-numeric_6_box_multiple_outline'
        'nf-mdi-numeric_6_box_outline'                   = 'nf-md-numeric_6_box_outline'
        'nf-mdi-numeric_7_box'                           = 'nf-md-numeric_7_box'
        'nf-mdi-numeric_7_box_multiple_outline'          = 'nf-md-numeric_7_box_multiple_outline'
        'nf-mdi-numeric_7_box_outline'                   = 'nf-md-numeric_7_box_outline'
        'nf-mdi-numeric_8_box'                           = 'nf-md-numeric_8_box'
        'nf-mdi-numeric_8_box_multiple_outline'          = 'nf-md-numeric_8_box_multiple_outline'
        'nf-mdi-numeric_8_box_outline'                   = 'nf-md-numeric_8_box_outline'
        'nf-mdi-numeric_9_box'                           = 'nf-md-numeric_9_box'
        'nf-mdi-numeric_9_box_multiple_outline'          = 'nf-md-numeric_9_box_multiple_outline'
        'nf-mdi-numeric_9_box_outline'                   = 'nf-md-numeric_9_box_outline'
        'nf-mdi-numeric_9_plus_box'                      = 'nf-md-numeric_9_plus_box'
        'nf-mdi-numeric_9_plus_box_multiple_outline'     = 'nf-md-numeric_9_plus_box_multiple_outline'
        'nf-mdi-numeric_9_plus_box_outline'              = 'nf-md-numeric_9_plus_box_outline'
        'nf-mdi-nut'                                     = 'nf-md-nut'
        'nf-mdi-nutrition'                               = 'nf-md-nutrition'
        'nf-mdi-oar'                                     = 'nf-md-oar'
        'nf-mdi-octagon'                                 = 'nf-md-octagon'
        'nf-mdi-octagon_outline'                         = 'nf-md-octagon_outline'
        'nf-mdi-octagram'                                = 'nf-md-octagram'
        'nf-mdi-octagram_outline'                        = 'nf-md-octagram_outline'
        'nf-mdi-odnoklassniki'                           = 'nf-md-odnoklassniki'
        'nf-mdi-oil'                                     = 'nf-md-oil'
        'nf-mdi-oil_temperature'                         = 'nf-md-oil_temperature'
        'nf-mdi-omega'                                   = 'nf-md-omega'
        'nf-mdi-onedrive'                                = 'nf-dev-onedrive'
        'nf-mdi-opacity'                                 = 'nf-md-opacity'
        'nf-mdi-open_in_app'                             = 'nf-md-open_in_app'
        'nf-mdi-open_in_new'                             = 'nf-md-open_in_new'
        'nf-mdi-openid'                                  = 'nf-md-openid'
        'nf-mdi-opera'                                   = 'nf-md-opera'
        'nf-mdi-orbit'                                   = 'nf-md-orbit'
        'nf-mdi-ornament'                                = 'nf-md-ornament'
        'nf-mdi-ornament_variant'                        = 'nf-md-ornament_variant'
        'nf-mdi-owl'                                     = 'nf-md-owl'
        'nf-mdi-package'                                 = 'nf-md-package'
        'nf-mdi-package_down'                            = 'nf-md-package_down'
        'nf-mdi-package_up'                              = 'nf-md-package_up'
        'nf-mdi-package_variant'                         = 'nf-md-package_variant'
        'nf-mdi-package_variant_closed'                  = 'nf-md-package_variant_closed'
        'nf-mdi-page_first'                              = 'nf-md-page_first'
        'nf-mdi-page_last'                               = 'nf-md-page_last'
        'nf-mdi-page_layout_body'                        = 'nf-md-page_layout_body'
        'nf-mdi-page_layout_footer'                      = 'nf-md-page_layout_footer'
        'nf-mdi-page_layout_header'                      = 'nf-md-page_layout_header'
        'nf-mdi-page_layout_sidebar_left'                = 'nf-md-page_layout_sidebar_left'
        'nf-mdi-page_layout_sidebar_right'               = 'nf-md-page_layout_sidebar_right'
        'nf-mdi-palette'                                 = 'nf-md-palette'
        'nf-mdi-palette_advanced'                        = 'nf-md-palette_advanced'
        'nf-mdi-panda'                                   = 'nf-md-panda'
        'nf-mdi-pandora'                                 = 'nf-md-pandora'
        'nf-mdi-panorama'                                = 'nf-md-panorama'
        'nf-mdi-panorama_fisheye'                        = 'nf-md-panorama_fisheye'
        'nf-mdi-panorama_horizontal'                     = 'nf-md-panorama_horizontal'
        'nf-mdi-panorama_vertical'                       = 'nf-md-panorama_vertical'
        'nf-mdi-panorama_wide_angle'                     = 'nf-md-panorama_wide_angle'
        'nf-mdi-paper_cut_vertical'                      = 'nf-md-paper_cut_vertical'
        'nf-mdi-paperclip'                               = 'nf-md-paperclip'
        'nf-mdi-parking'                                 = 'nf-md-parking'
        'nf-mdi-passport'                                = 'nf-md-passport'
        'nf-mdi-pause'                                   = 'nf-md-pause'
        'nf-mdi-pause_circle'                            = 'nf-md-pause_circle'
        'nf-mdi-pause_circle_outline'                    = 'nf-md-pause_circle_outline'
        'nf-mdi-pause_octagon'                           = 'nf-md-pause_octagon'
        'nf-mdi-pause_octagon_outline'                   = 'nf-md-pause_octagon_outline'
        'nf-mdi-paw'                                     = 'nf-md-paw'
        'nf-mdi-paw_off'                                 = 'nf-md-paw_off'
        'nf-mdi-pen'                                     = 'nf-md-pen'
        'nf-mdi-pencil'                                  = 'nf-md-pencil'
        'nf-mdi-pencil_box'                              = 'nf-md-pencil_box'
        'nf-mdi-pencil_box_outline'                      = 'nf-md-pencil_box_outline'
        'nf-mdi-pencil_circle'                           = 'nf-md-pencil_circle'
        'nf-mdi-pencil_circle_outline'                   = 'nf-md-pencil_circle_outline'
        'nf-mdi-pencil_lock'                             = 'nf-md-pencil_lock'
        'nf-mdi-pencil_off'                              = 'nf-md-pencil_off'
        'nf-mdi-pentagon'                                = 'nf-md-pentagon'
        'nf-mdi-pentagon_outline'                        = 'nf-md-pentagon_outline'
        'nf-mdi-percent'                                 = 'nf-md-percent'
        'nf-mdi-phone'                                   = 'nf-md-phone'
        'nf-mdi-phone_bluetooth'                         = 'nf-md-phone_bluetooth'
        'nf-mdi-phone_classic'                           = 'nf-md-phone_classic'
        'nf-mdi-phone_forward'                           = 'nf-md-phone_forward'
        'nf-mdi-phone_hangup'                            = 'nf-md-phone_hangup'
        'nf-mdi-phone_in_talk'                           = 'nf-md-phone_in_talk'
        'nf-mdi-phone_incoming'                          = 'nf-md-phone_incoming'
        'nf-mdi-phone_log'                               = 'nf-md-phone_log'
        'nf-mdi-phone_minus'                             = 'nf-md-phone_minus'
        'nf-mdi-phone_missed'                            = 'nf-md-phone_missed'
        'nf-mdi-phone_outgoing'                          = 'nf-md-phone_outgoing'
        'nf-mdi-phone_paused'                            = 'nf-md-phone_paused'
        'nf-mdi-phone_plus'                              = 'nf-md-phone_plus'
        'nf-mdi-phone_return'                            = 'nf-md-phone_return'
        'nf-mdi-phone_settings'                          = 'nf-md-phone_settings'
        'nf-mdi-phone_voip'                              = 'nf-md-phone_voip'
        'nf-mdi-pi'                                      = 'nf-md-pi'
        'nf-mdi-pi_box'                                  = 'nf-md-pi_box'
        'nf-mdi-piano'                                   = 'nf-md-piano'
        'nf-mdi-pig'                                     = 'nf-md-pig'
        'nf-mdi-pill'                                    = 'nf-md-pill'
        'nf-mdi-pillar'                                  = 'nf-md-pillar'
        'nf-mdi-pin'                                     = 'nf-md-pin'
        'nf-mdi-pin_off'                                 = 'nf-md-pin_off'
        'nf-mdi-pine_tree'                               = 'nf-md-pine_tree'
        'nf-mdi-pine_tree_box'                           = 'nf-md-pine_tree_box'
        'nf-mdi-pinterest'                               = 'nf-md-pinterest'
        'nf-mdi-pipe'                                    = 'nf-md-pipe'
        'nf-mdi-pipe_disconnected'                       = 'nf-md-pipe_disconnected'
        'nf-mdi-pistol'                                  = 'nf-md-pistol'
        'nf-mdi-pizza'                                   = 'nf-md-pizza'
        'nf-mdi-play'                                    = 'nf-md-play'
        'nf-mdi-play_box_outline'                        = 'nf-md-play_box_outline'
        'nf-mdi-play_circle'                             = 'nf-md-play_circle'
        'nf-mdi-play_circle_outline'                     = 'nf-md-play_circle_outline'
        'nf-mdi-play_pause'                              = 'nf-md-play_pause'
        'nf-mdi-play_protected_content'                  = 'nf-md-play_protected_content'
        'nf-mdi-playlist_check'                          = 'nf-md-playlist_check'
        'nf-mdi-playlist_minus'                          = 'nf-md-playlist_minus'
        'nf-mdi-playlist_play'                           = 'nf-md-playlist_play'
        'nf-mdi-playlist_plus'                           = 'nf-md-playlist_plus'
        'nf-mdi-playlist_remove'                         = 'nf-md-playlist_remove'
        'nf-mdi-plex'                                    = 'nf-md-plex'
        'nf-mdi-plus'                                    = 'nf-md-plus'
        'nf-mdi-plus_box'                                = 'nf-md-plus_box'
        'nf-mdi-plus_box_outline'                        = 'nf-md-plus_box_outline'
        'nf-mdi-plus_circle'                             = 'nf-md-plus_circle'
        'nf-mdi-plus_circle_multiple_outline'            = 'nf-md-plus_circle_multiple_outline'
        'nf-mdi-plus_circle_outline'                     = 'nf-md-plus_circle_outline'
        'nf-mdi-plus_network'                            = 'nf-md-plus_network'
        'nf-mdi-plus_outline'                            = 'nf-md-plus_outline'
        'nf-mdi-pokeball'                                = 'nf-md-pokeball'
        'nf-mdi-poker_chip'                              = 'nf-md-poker_chip'
        'nf-mdi-polaroid'                                = 'nf-md-polaroid'
        'nf-mdi-poll'                                    = 'nf-md-poll'
        'nf-mdi-polymer'                                 = 'nf-md-polymer'
        'nf-mdi-pool'                                    = 'nf-md-pool'
        'nf-mdi-popcorn'                                 = 'nf-md-popcorn'
        'nf-mdi-pot'                                     = 'nf-md-pot'
        'nf-mdi-pot_mix'                                 = 'nf-md-pot_mix'
        'nf-mdi-pound'                                   = 'nf-md-pound'
        'nf-mdi-pound_box'                               = 'nf-md-pound_box'
        'nf-mdi-power'                                   = 'nf-md-power'
        'nf-mdi-power_plug'                              = 'nf-md-power_plug'
        'nf-mdi-power_plug_off'                          = 'nf-md-power_plug_off'
        'nf-mdi-power_settings'                          = 'nf-md-power_settings'
        'nf-mdi-power_socket'                            = 'nf-md-power_socket'
        'nf-mdi-power_socket_eu'                         = 'nf-md-power_socket_eu'
        'nf-mdi-power_socket_uk'                         = 'nf-md-power_socket_uk'
        'nf-mdi-power_socket_us'                         = 'nf-md-power_socket_us'
        'nf-mdi-prescription'                            = 'nf-md-prescription'
        'nf-mdi-presentation'                            = 'nf-md-presentation'
        'nf-mdi-presentation_play'                       = 'nf-md-presentation_play'
        'nf-mdi-printer'                                 = 'nf-md-printer'
        'nf-mdi-printer_3d'                              = 'nf-md-printer_3d'
        'nf-mdi-printer_alert'                           = 'nf-md-printer_alert'
        'nf-mdi-printer_settings'                        = 'nf-md-printer_settings'
        'nf-mdi-priority_high'                           = 'nf-md-priority_high'
        'nf-mdi-priority_low'                            = 'nf-md-priority_low'
        'nf-mdi-professional_hexagon'                    = 'nf-md-professional_hexagon'
        'nf-mdi-projector'                               = 'nf-md-projector'
        'nf-mdi-projector_screen'                        = 'nf-md-projector_screen'
        'nf-mdi-publish'                                 = 'nf-md-publish'
        'nf-mdi-pulse'                                   = 'nf-md-pulse'
        'nf-mdi-puzzle'                                  = 'nf-md-puzzle'
        'nf-mdi-qqchat'                                  = 'nf-md-qqchat'
        'nf-mdi-qrcode'                                  = 'nf-md-qrcode'
        'nf-mdi-qrcode_scan'                             = 'nf-md-qrcode_scan'
        'nf-mdi-quadcopter'                              = 'nf-md-quadcopter'
        'nf-mdi-quality_high'                            = 'nf-md-quality_high'
        'nf-mdi-radar'                                   = 'nf-md-radar'
        'nf-mdi-radiator'                                = 'nf-md-radiator'
        'nf-mdi-radio'                                   = 'nf-md-radio'
        'nf-mdi-radio_handheld'                          = 'nf-md-radio_handheld'
        'nf-mdi-radio_tower'                             = 'nf-md-radio_tower'
        'nf-mdi-radioactive'                             = 'nf-md-radioactive'
        'nf-mdi-radiobox_marked'                         = 'nf-md-radiobox_marked'
        'nf-mdi-ray_end'                                 = 'nf-md-ray_end'
        'nf-mdi-ray_end_arrow'                           = 'nf-md-ray_end_arrow'
        'nf-mdi-ray_start'                               = 'nf-md-ray_start'
        'nf-mdi-ray_start_arrow'                         = 'nf-md-ray_start_arrow'
        'nf-mdi-ray_start_end'                           = 'nf-md-ray_start_end'
        'nf-mdi-ray_vertex'                              = 'nf-md-ray_vertex'
        'nf-mdi-react'                                   = 'nf-md-react'
        'nf-mdi-read'                                    = 'nf-md-read'
        'nf-mdi-receipt'                                 = 'nf-md-receipt'
        'nf-mdi-record'                                  = 'nf-md-record'
        'nf-mdi-record_rec'                              = 'nf-md-record_rec'
        'nf-mdi-recycle'                                 = 'nf-md-recycle'
        'nf-mdi-reddit'                                  = 'nf-md-reddit'
        'nf-mdi-redo'                                    = 'nf-md-redo'
        'nf-mdi-redo_variant'                            = 'nf-md-redo_variant'
        'nf-mdi-refresh'                                 = 'nf-md-refresh'
        'nf-mdi-regex'                                   = 'nf-md-regex'
        'nf-mdi-relative_scale'                          = 'nf-md-relative_scale'
        'nf-mdi-reload'                                  = 'nf-md-reload'
        'nf-mdi-remote'                                  = 'nf-md-remote'
        'nf-mdi-rename_box'                              = 'nf-md-rename_box'
        'nf-mdi-reorder_horizontal'                      = 'nf-md-reorder_horizontal'
        'nf-mdi-reorder_vertical'                        = 'nf-md-reorder_vertical'
        'nf-mdi-repeat'                                  = 'nf-md-repeat'
        'nf-mdi-repeat_off'                              = 'nf-md-repeat_off'
        'nf-mdi-repeat_once'                             = 'nf-md-repeat_once'
        'nf-mdi-replay'                                  = 'nf-md-replay'
        'nf-mdi-reply'                                   = 'nf-md-reply'
        'nf-mdi-reply_all'                               = 'nf-md-reply_all'
        'nf-mdi-reproduction'                            = 'nf-md-reproduction'
        'nf-mdi-resize_bottom_right'                     = 'nf-md-resize_bottom_right'
        'nf-mdi-responsive'                              = 'nf-md-responsive'
        'nf-mdi-restart'                                 = 'nf-md-restart'
        'nf-mdi-restore'                                 = 'nf-md-restore'
        'nf-mdi-rewind'                                  = 'nf-md-rewind'
        'nf-mdi-rewind_outline'                          = 'nf-md-rewind_outline'
        'nf-mdi-rhombus'                                 = 'nf-md-rhombus'
        'nf-mdi-rhombus_outline'                         = 'nf-md-rhombus_outline'
        'nf-mdi-ribbon'                                  = 'nf-md-ribbon'
        'nf-mdi-rice'                                    = 'nf-md-rice'
        'nf-mdi-ring'                                    = 'nf-md-ring'
        'nf-mdi-road'                                    = 'nf-md-road'
        'nf-mdi-road_variant'                            = 'nf-md-road_variant'
        'nf-mdi-robot'                                   = 'nf-md-robot'
        'nf-mdi-rocket'                                  = 'nf-md-rocket'
        'nf-mdi-rotate_3d'                               = 'nf-md-rotate_3d'
        'nf-mdi-rotate_left'                             = 'nf-md-rotate_left'
        'nf-mdi-rotate_left_variant'                     = 'nf-md-rotate_left_variant'
        'nf-mdi-rotate_right'                            = 'nf-md-rotate_right'
        'nf-mdi-rotate_right_variant'                    = 'nf-md-rotate_right_variant'
        'nf-mdi-rounded_corner'                          = 'nf-md-rounded_corner'
        'nf-mdi-router_wireless'                         = 'nf-md-router_wireless'
        'nf-mdi-routes'                                  = 'nf-md-routes'
        'nf-mdi-rowing'                                  = 'nf-md-rowing'
        'nf-mdi-rss'                                     = 'nf-md-rss'
        'nf-mdi-rss_box'                                 = 'nf-md-rss_box'
        'nf-mdi-ruler'                                   = 'nf-md-ruler'
        'nf-mdi-run'                                     = 'nf-md-run'
        'nf-mdi-run_fast'                                = 'nf-md-run_fast'
        'nf-mdi-sale'                                    = 'nf-md-sale'
        'nf-mdi-sass'                                    = 'nf-md-sass'
        'nf-mdi-satellite'                               = 'nf-md-satellite'
        'nf-mdi-satellite_variant'                       = 'nf-md-satellite_variant'
        'nf-mdi-saxophone'                               = 'nf-md-saxophone'
        'nf-mdi-scale'                                   = 'nf-md-scale'
        'nf-mdi-scale_balance'                           = 'nf-md-scale_balance'
        'nf-mdi-scale_bathroom'                          = 'nf-md-scale_bathroom'
        'nf-mdi-scanner'                                 = 'nf-md-scanner'
        'nf-mdi-school'                                  = 'nf-md-school'
        'nf-mdi-screen_rotation'                         = 'nf-md-screen_rotation'
        'nf-mdi-screen_rotation_lock'                    = 'nf-md-screen_rotation_lock'
        'nf-mdi-screwdriver'                             = 'nf-md-screwdriver'
        'nf-mdi-script'                                  = 'nf-md-script'
        'nf-mdi-sd'                                      = 'nf-md-sd'
        'nf-mdi-seal'                                    = 'nf-md-seal'
        'nf-mdi-search_web'                              = 'nf-md-search_web'
        'nf-mdi-seat_flat'                               = 'nf-md-seat_flat'
        'nf-mdi-seat_flat_angled'                        = 'nf-md-seat_flat_angled'
        'nf-mdi-seat_individual_suite'                   = 'nf-md-seat_individual_suite'
        'nf-mdi-seat_legroom_extra'                      = 'nf-md-seat_legroom_extra'
        'nf-mdi-seat_legroom_normal'                     = 'nf-md-seat_legroom_normal'
        'nf-mdi-seat_legroom_reduced'                    = 'nf-md-seat_legroom_reduced'
        'nf-mdi-seat_recline_extra'                      = 'nf-md-seat_recline_extra'
        'nf-mdi-seat_recline_normal'                     = 'nf-md-seat_recline_normal'
        'nf-mdi-security'                                = 'nf-md-security'
        'nf-mdi-security_network'                        = 'nf-md-security_network'
        'nf-mdi-select'                                  = 'nf-md-select'
        'nf-mdi-select_all'                              = 'nf-md-select_all'
        'nf-mdi-select_inverse'                          = 'nf-md-select_inverse'
        'nf-mdi-select_off'                              = 'nf-md-select_off'
        'nf-mdi-selection'                               = 'nf-md-selection'
        'nf-mdi-selection_off'                           = 'nf-md-selection_off'
        'nf-mdi-send'                                    = 'nf-md-send'
        'nf-mdi-serial_port'                             = 'nf-md-serial_port'
        'nf-mdi-server'                                  = 'nf-md-server'
        'nf-mdi-server_minus'                            = 'nf-md-server_minus'
        'nf-mdi-server_network'                          = 'nf-md-server_network'
        'nf-mdi-server_network_off'                      = 'nf-md-server_network_off'
        'nf-mdi-server_off'                              = 'nf-md-server_off'
        'nf-mdi-server_plus'                             = 'nf-md-server_plus'
        'nf-mdi-server_remove'                           = 'nf-md-server_remove'
        'nf-mdi-server_security'                         = 'nf-md-server_security'
        'nf-mdi-set_all'                                 = 'nf-md-set_all'
        'nf-mdi-set_center'                              = 'nf-md-set_center'
        'nf-mdi-set_center_right'                        = 'nf-md-set_center_right'
        'nf-mdi-set_left'                                = 'nf-md-set_left'
        'nf-mdi-set_left_center'                         = 'nf-md-set_left_center'
        'nf-mdi-set_left_right'                          = 'nf-md-set_left_right'
        'nf-mdi-set_none'                                = 'nf-md-set_none'
        'nf-mdi-set_right'                               = 'nf-md-set_right'
        'nf-mdi-shape'                                   = 'nf-md-shape'
        'nf-mdi-shape_circle_plus'                       = 'nf-md-shape_circle_plus'
        'nf-mdi-shape_outline'                           = 'nf-md-shape_outline'
        'nf-mdi-shape_plus'                              = 'nf-md-shape_plus'
        'nf-mdi-shape_polygon_plus'                      = 'nf-md-shape_polygon_plus'
        'nf-mdi-shape_rectangle_plus'                    = 'nf-md-shape_rectangle_plus'
        'nf-mdi-shape_square_plus'                       = 'nf-md-shape_square_plus'
        'nf-mdi-share'                                   = 'nf-md-share'
        'nf-mdi-share_variant'                           = 'nf-md-share_variant'
        'nf-mdi-shield'                                  = 'nf-md-shield'
        'nf-mdi-shield_half_full'                        = 'nf-md-shield_half_full'
        'nf-mdi-shield_outline'                          = 'nf-md-shield_outline'
        'nf-mdi-ship_wheel'                              = 'nf-md-ship_wheel'
        'nf-mdi-shopping'                                = 'nf-md-shopping'
        'nf-mdi-shopping_music'                          = 'nf-md-shopping_music'
        'nf-mdi-shovel'                                  = 'nf-md-shovel'
        'nf-mdi-shovel_off'                              = 'nf-md-shovel_off'
        'nf-mdi-shredder'                                = 'nf-md-shredder'
        'nf-mdi-shuffle'                                 = 'nf-md-shuffle'
        'nf-mdi-shuffle_disabled'                        = 'nf-md-shuffle_disabled'
        'nf-mdi-shuffle_variant'                         = 'nf-md-shuffle_variant'
        'nf-mdi-sigma'                                   = 'nf-md-sigma'
        'nf-mdi-sigma_lower'                             = 'nf-md-sigma_lower'
        'nf-mdi-sign_caution'                            = 'nf-md-sign_caution'
        'nf-mdi-sign_direction'                          = 'nf-md-sign_direction'
        'nf-mdi-sign_text'                               = 'nf-md-sign_text'
        'nf-mdi-signal'                                  = 'nf-md-signal'
        'nf-mdi-signal_2g'                               = 'nf-md-signal_2g'
        'nf-mdi-signal_3g'                               = 'nf-md-signal_3g'
        'nf-mdi-signal_4g'                               = 'nf-md-signal_4g'
        'nf-mdi-signal_hspa'                             = 'nf-md-signal_hspa'
        'nf-mdi-signal_hspa_plus'                        = 'nf-md-signal_hspa_plus'
        'nf-mdi-signal_off'                              = 'nf-md-signal_off'
        'nf-mdi-signal_variant'                          = 'nf-md-signal_variant'
        'nf-mdi-silverware'                              = 'nf-md-silverware'
        'nf-mdi-silverware_fork'                         = 'nf-md-silverware_fork'
        'nf-mdi-silverware_spoon'                        = 'nf-md-silverware_spoon'
        'nf-mdi-silverware_variant'                      = 'nf-md-silverware_variant'
        'nf-mdi-sim'                                     = 'nf-md-sim'
        'nf-mdi-sim_alert'                               = 'nf-md-sim_alert'
        'nf-mdi-sim_off'                                 = 'nf-md-sim_off'
        'nf-mdi-sitemap'                                 = 'nf-md-sitemap'
        'nf-mdi-skip_backward'                           = 'nf-md-skip_backward'
        'nf-mdi-skip_forward'                            = 'nf-md-skip_forward'
        'nf-mdi-skip_next'                               = 'nf-md-skip_next'
        'nf-mdi-skip_next_circle'                        = 'nf-md-skip_next_circle'
        'nf-mdi-skip_next_circle_outline'                = 'nf-md-skip_next_circle_outline'
        'nf-mdi-skip_previous'                           = 'nf-md-skip_previous'
        'nf-mdi-skip_previous_circle'                    = 'nf-md-skip_previous_circle'
        'nf-mdi-skip_previous_circle_outline'            = 'nf-md-skip_previous_circle_outline'
        'nf-mdi-skull'                                   = 'nf-md-skull'
        'nf-mdi-skype'                                   = 'nf-md-skype'
        'nf-mdi-skype_business'                          = 'nf-md-skype_business'
        'nf-mdi-slack'                                   = 'nf-md-slack'
        'nf-mdi-sleep'                                   = 'nf-md-sleep'
        'nf-mdi-sleep_off'                               = 'nf-md-sleep_off'
        'nf-mdi-smoking'                                 = 'nf-md-smoking'
        'nf-mdi-smoking_off'                             = 'nf-md-smoking_off'
        'nf-mdi-snapchat'                                = 'nf-md-snapchat'
        'nf-mdi-snowflake'                               = 'nf-md-snowflake'
        'nf-mdi-snowman'                                 = 'nf-md-snowman'
        'nf-mdi-soccer'                                  = 'nf-md-soccer'
        'nf-mdi-soccer_field'                            = 'nf-md-soccer_field'
        'nf-mdi-sofa'                                    = 'nf-md-sofa'
        'nf-mdi-solid'                                   = 'nf-md-solid'
        'nf-mdi-sort'                                    = 'nf-md-sort'
        'nf-mdi-sort_ascending'                          = 'nf-md-sort_ascending'
        'nf-mdi-sort_descending'                         = 'nf-md-sort_descending'
        'nf-mdi-sort_variant'                            = 'nf-md-sort_variant'
        'nf-mdi-soundcloud'                              = 'nf-md-soundcloud'
        'nf-mdi-source_branch'                           = 'nf-md-source_branch'
        'nf-mdi-source_commit'                           = 'nf-md-source_commit'
        'nf-mdi-source_commit_end'                       = 'nf-md-source_commit_end'
        'nf-mdi-source_commit_end_local'                 = 'nf-md-source_commit_end_local'
        'nf-mdi-source_commit_local'                     = 'nf-md-source_commit_local'
        'nf-mdi-source_commit_next_local'                = 'nf-md-source_commit_next_local'
        'nf-mdi-source_commit_start'                     = 'nf-md-source_commit_start'
        'nf-mdi-source_commit_start_next_local'          = 'nf-md-source_commit_start_next_local'
        'nf-mdi-source_fork'                             = 'nf-md-source_fork'
        'nf-mdi-source_merge'                            = 'nf-md-source_merge'
        'nf-mdi-source_pull'                             = 'nf-md-source_pull'
        'nf-mdi-soy_sauce'                               = 'nf-md-soy_sauce'
        'nf-mdi-speaker'                                 = 'nf-md-speaker'
        'nf-mdi-speaker_off'                             = 'nf-md-speaker_off'
        'nf-mdi-speaker_wireless'                        = 'nf-md-speaker_wireless'
        'nf-mdi-speedometer'                             = 'nf-md-speedometer'
        'nf-mdi-spellcheck'                              = 'nf-md-spellcheck'
        'nf-mdi-spotify'                                 = 'nf-md-spotify'
        'nf-mdi-spotlight'                               = 'nf-md-spotlight'
        'nf-mdi-spotlight_beam'                          = 'nf-md-spotlight_beam'
        'nf-mdi-spray'                                   = 'nf-md-spray'
        'nf-mdi-square'                                  = 'nf-md-square'
        'nf-mdi-square_outline'                          = 'nf-md-square_outline'
        'nf-mdi-square_root'                             = 'nf-md-square_root'
        'nf-mdi-stack_overflow'                          = 'nf-md-stack_overflow'
        'nf-mdi-stadium'                                 = 'nf-md-stadium'
        'nf-mdi-stairs'                                  = 'nf-md-stairs'
        'nf-mdi-standard_definition'                     = 'nf-md-standard_definition'
        'nf-mdi-star'                                    = 'nf-md-star'
        'nf-mdi-star_circle'                             = 'nf-md-star_circle'
        'nf-mdi-star_half'                               = 'nf-md-star_half'
        'nf-mdi-star_off'                                = 'nf-md-star_off'
        'nf-mdi-star_outline'                            = 'nf-md-star_outline'
        'nf-mdi-steam'                                   = 'nf-md-steam'
        'nf-mdi-steering'                                = 'nf-md-steering'
        'nf-mdi-step_backward'                           = 'nf-md-step_backward'
        'nf-mdi-step_backward_2'                         = 'nf-md-step_backward_2'
        'nf-mdi-step_forward'                            = 'nf-md-step_forward'
        'nf-mdi-step_forward_2'                          = 'nf-md-step_forward_2'
        'nf-mdi-stethoscope'                             = 'nf-md-stethoscope'
        'nf-mdi-sticker'                                 = 'nf-md-sticker'
        'nf-mdi-sticker_emoji'                           = 'nf-md-sticker_emoji'
        'nf-mdi-stocking'                                = 'nf-md-stocking'
        'nf-mdi-stop'                                    = 'nf-md-stop'
        'nf-mdi-stop_circle'                             = 'nf-md-stop_circle'
        'nf-mdi-stop_circle_outline'                     = 'nf-md-stop_circle_outline'
        'nf-mdi-store'                                   = 'nf-md-store'
        'nf-mdi-store_24_hour'                           = 'nf-md-store_24_hour'
        'nf-mdi-stove'                                   = 'nf-md-stove'
        'nf-mdi-subdirectory_arrow_left'                 = 'nf-md-subdirectory_arrow_left'
        'nf-mdi-subdirectory_arrow_right'                = 'nf-md-subdirectory_arrow_right'
        'nf-mdi-subway'                                  = 'nf-md-subway'
        'nf-mdi-subway_variant'                          = 'nf-md-subway_variant'
        'nf-mdi-summit'                                  = 'nf-md-summit'
        'nf-mdi-sunglasses'                              = 'nf-md-sunglasses'
        'nf-mdi-surround_sound'                          = 'nf-md-surround_sound'
        'nf-mdi-surround_sound_2_0'                      = 'nf-md-surround_sound_2_0'
        'nf-mdi-surround_sound_3_1'                      = 'nf-md-surround_sound_3_1'
        'nf-mdi-surround_sound_5_1'                      = 'nf-md-surround_sound_5_1'
        'nf-mdi-surround_sound_7_1'                      = 'nf-md-surround_sound_7_1'
        'nf-mdi-svg'                                     = 'nf-md-svg'
        'nf-mdi-swap_horizontal'                         = 'nf-md-swap_horizontal'
        'nf-mdi-swap_vertical'                           = 'nf-md-swap_vertical'
        'nf-mdi-swim'                                    = 'nf-md-swim'
        'nf-mdi-switch'                                  = 'nf-md-switch'
        'nf-mdi-sword'                                   = 'nf-md-sword'
        'nf-mdi-sword_cross'                             = 'nf-md-sword_cross'
        'nf-mdi-sync'                                    = 'nf-md-sync'
        'nf-mdi-sync_alert'                              = 'nf-md-sync_alert'
        'nf-mdi-sync_off'                                = 'nf-md-sync_off'
        'nf-mdi-tab'                                     = 'nf-md-tab'
        'nf-mdi-tab_plus'                                = 'nf-md-tab_plus'
        'nf-mdi-tab_unselected'                          = 'nf-md-tab_unselected'
        'nf-mdi-table'                                   = 'nf-md-table'
        'nf-mdi-table_column'                            = 'nf-md-table_column'
        'nf-mdi-table_column_plus_after'                 = 'nf-md-table_column_plus_after'
        'nf-mdi-table_column_plus_before'                = 'nf-md-table_column_plus_before'
        'nf-mdi-table_column_remove'                     = 'nf-md-table_column_remove'
        'nf-mdi-table_column_width'                      = 'nf-md-table_column_width'
        'nf-mdi-table_edit'                              = 'nf-md-table_edit'
        'nf-mdi-table_large'                             = 'nf-md-table_large'
        'nf-mdi-table_of_contents'                       = 'nf-md-table_of_contents'
        'nf-mdi-table_row'                               = 'nf-md-table_row'
        'nf-mdi-table_row_height'                        = 'nf-md-table_row_height'
        'nf-mdi-table_row_plus_after'                    = 'nf-md-table_row_plus_after'
        'nf-mdi-table_row_plus_before'                   = 'nf-md-table_row_plus_before'
        'nf-mdi-table_row_remove'                        = 'nf-md-table_row_remove'
        'nf-mdi-table_settings'                          = 'nf-md-table_settings'
        'nf-mdi-tablet'                                  = 'nf-md-tablet'
        'nf-mdi-tablet_android'                          = 'nf-md-tablet_android'
        'nf-mdi-taco'                                    = 'nf-md-taco'
        'nf-mdi-tag'                                     = 'nf-md-tag'
        'nf-mdi-tag_faces'                               = 'nf-md-tag_faces'
        'nf-mdi-tag_heart'                               = 'nf-md-tag_heart'
        'nf-mdi-tag_multiple'                            = 'nf-md-tag_multiple'
        'nf-mdi-tag_outline'                             = 'nf-md-tag_outline'
        'nf-mdi-tag_plus'                                = 'nf-md-tag_plus'
        'nf-mdi-tag_remove'                              = 'nf-md-tag_remove'
        'nf-mdi-tag_text_outline'                        = 'nf-md-tag_text_outline'
        'nf-mdi-target'                                  = 'nf-md-target'
        'nf-mdi-taxi'                                    = 'nf-md-taxi'
        'nf-mdi-teamviewer'                              = 'nf-md-teamviewer'
        'nf-mdi-television'                              = 'nf-md-television'
        'nf-mdi-television_box'                          = 'nf-md-television_box'
        'nf-mdi-television_classic'                      = 'nf-md-television_classic'
        'nf-mdi-television_classic_off'                  = 'nf-md-television_classic_off'
        'nf-mdi-television_guide'                        = 'nf-md-television_guide'
        'nf-mdi-television_off'                          = 'nf-md-television_off'
        'nf-mdi-temperature_celsius'                     = 'nf-md-temperature_celsius'
        'nf-mdi-temperature_fahrenheit'                  = 'nf-md-temperature_fahrenheit'
        'nf-mdi-temperature_kelvin'                      = 'nf-md-temperature_kelvin'
        'nf-mdi-tennis'                                  = 'nf-md-tennis'
        'nf-mdi-tent'                                    = 'nf-md-tent'
        'nf-mdi-test_tube'                               = 'nf-md-test_tube'
        'nf-mdi-text_shadow'                             = 'nf-md-text_shadow'
        'nf-mdi-text_to_speech'                          = 'nf-md-text_to_speech'
        'nf-mdi-text_to_speech_off'                      = 'nf-md-text_to_speech_off'
        'nf-mdi-texture'                                 = 'nf-md-texture'
        'nf-mdi-theater'                                 = 'nf-md-theater'
        'nf-mdi-theme_light_dark'                        = 'nf-md-theme_light_dark'
        'nf-mdi-thermometer'                             = 'nf-md-thermometer'
        'nf-mdi-thermometer_lines'                       = 'nf-md-thermometer_lines'
        'nf-mdi-thought_bubble'                          = 'nf-md-thought_bubble'
        'nf-mdi-thought_bubble_outline'                  = 'nf-md-thought_bubble_outline'
        'nf-mdi-thumb_down'                              = 'nf-md-thumb_down'
        'nf-mdi-thumb_down_outline'                      = 'nf-md-thumb_down_outline'
        'nf-mdi-thumb_up'                                = 'nf-md-thumb_up'
        'nf-mdi-thumb_up_outline'                        = 'nf-md-thumb_up_outline'
        'nf-mdi-thumbs_up_down'                          = 'nf-md-thumbs_up_down'
        'nf-mdi-ticket'                                  = 'nf-md-ticket'
        'nf-mdi-ticket_account'                          = 'nf-md-ticket_account'
        'nf-mdi-ticket_confirmation'                     = 'nf-md-ticket_confirmation'
        'nf-mdi-ticket_percent'                          = 'nf-md-ticket_percent'
        'nf-mdi-tie'                                     = 'nf-md-tie'
        'nf-mdi-tilde'                                   = 'nf-md-tilde'
        'nf-mdi-timelapse'                               = 'nf-md-timelapse'
        'nf-mdi-timer'                                   = 'nf-md-timer'
        'nf-mdi-timer_10'                                = 'nf-md-timer_10'
        'nf-mdi-timer_3'                                 = 'nf-md-timer_3'
        'nf-mdi-timer_off'                               = 'nf-md-timer_off'
        'nf-mdi-timer_sand'                              = 'nf-md-timer_sand'
        'nf-mdi-timer_sand_empty'                        = 'nf-md-timer_sand_empty'
        'nf-mdi-timer_sand_full'                         = 'nf-md-timer_sand_full'
        'nf-mdi-timetable'                               = 'nf-md-timetable'
        'nf-mdi-toggle_switch'                           = 'nf-md-toggle_switch'
        'nf-mdi-toggle_switch_off'                       = 'nf-md-toggle_switch_off'
        'nf-mdi-tooltip'                                 = 'nf-md-tooltip'
        'nf-mdi-tooltip_edit'                            = 'nf-md-tooltip_edit'
        'nf-mdi-tooltip_image'                           = 'nf-md-tooltip_image'
        'nf-mdi-tooltip_outline'                         = 'nf-md-tooltip_outline'
        'nf-mdi-tooltip_text'                            = 'nf-md-tooltip_text'
        'nf-mdi-tooth'                                   = 'nf-md-tooth'
        'nf-mdi-tower_beach'                             = 'nf-md-tower_beach'
        'nf-mdi-tower_fire'                              = 'nf-md-tower_fire'
        'nf-mdi-trackpad'                                = 'nf-md-trackpad'
        'nf-mdi-traffic_light'                           = 'nf-md-traffic_light'
        'nf-mdi-train'                                   = 'nf-md-train'
        'nf-mdi-tram'                                    = 'nf-md-tram'
        'nf-mdi-transcribe'                              = 'nf-md-transcribe'
        'nf-mdi-transcribe_close'                        = 'nf-md-transcribe_close'
        'nf-mdi-transfer'                                = 'nf-md-transfer'
        'nf-mdi-transit_transfer'                        = 'nf-md-transit_transfer'
        'nf-mdi-translate'                               = 'nf-md-translate'
        'nf-mdi-treasure_chest'                          = 'nf-md-treasure_chest'
        'nf-mdi-tree'                                    = 'nf-md-tree'
        'nf-mdi-trello'                                  = 'nf-md-trello'
        'nf-mdi-trending_down'                           = 'nf-md-trending_down'
        'nf-mdi-trending_neutral'                        = 'nf-md-trending_neutral'
        'nf-mdi-trending_up'                             = 'nf-md-trending_up'
        'nf-mdi-triangle'                                = 'nf-md-triangle'
        'nf-mdi-triangle_outline'                        = 'nf-md-triangle_outline'
        'nf-mdi-trophy'                                  = 'nf-md-trophy'
        'nf-mdi-trophy_award'                            = 'nf-md-trophy_award'
        'nf-mdi-trophy_outline'                          = 'nf-md-trophy_outline'
        'nf-mdi-trophy_variant'                          = 'nf-md-trophy_variant'
        'nf-mdi-trophy_variant_outline'                  = 'nf-md-trophy_variant_outline'
        'nf-mdi-truck'                                   = 'nf-md-truck'
        'nf-mdi-truck_delivery'                          = 'nf-md-truck_delivery'
        'nf-mdi-truck_fast'                              = 'nf-md-truck_fast'
        'nf-mdi-truck_trailer'                           = 'nf-md-truck_trailer'
        'nf-mdi-tshirt_crew'                             = 'nf-md-tshirt_crew'
        'nf-mdi-tshirt_v'                                = 'nf-md-tshirt_v'
        'nf-mdi-tune'                                    = 'nf-md-tune'
        'nf-mdi-tune_vertical'                           = 'nf-md-tune_vertical'
        'nf-mdi-twitch'                                  = 'nf-md-twitch'
        'nf-mdi-twitter'                                 = 'nf-md-twitter'
        'nf-mdi-ubuntu'                                  = 'nf-md-ubuntu'
        'nf-mdi-ultra_high_definition'                   = 'nf-md-ultra_high_definition'
        'nf-mdi-umbraco'                                 = 'nf-md-umbraco'
        'nf-mdi-umbrella'                                = 'nf-md-umbrella'
        'nf-mdi-umbrella_outline'                        = 'nf-md-umbrella_outline'
        'nf-mdi-undo'                                    = 'nf-md-undo'
        'nf-mdi-undo_variant'                            = 'nf-md-undo_variant'
        'nf-mdi-unfold_less_horizontal'                  = 'nf-md-unfold_less_horizontal'
        'nf-mdi-unfold_less_vertical'                    = 'nf-md-unfold_less_vertical'
        'nf-mdi-unfold_more_horizontal'                  = 'nf-md-unfold_more_horizontal'
        'nf-mdi-unfold_more_vertical'                    = 'nf-md-unfold_more_vertical'
        'nf-mdi-ungroup'                                 = 'nf-md-ungroup'
        'nf-mdi-unity'                                   = 'nf-md-unity'
        'nf-mdi-update'                                  = 'nf-md-update'
        'nf-mdi-upload'                                  = 'nf-md-upload'
        'nf-mdi-upload_multiple'                         = 'nf-md-upload_multiple'
        'nf-mdi-upload_network'                          = 'nf-md-upload_network'
        'nf-mdi-usb'                                     = 'nf-md-usb'
        'nf-mdi-van_passenger'                           = 'nf-md-van_passenger'
        'nf-mdi-van_utility'                             = 'nf-md-van_utility'
        'nf-mdi-vanish'                                  = 'nf-md-vanish'
        'nf-mdi-vector_arrange_above'                    = 'nf-md-vector_arrange_above'
        'nf-mdi-vector_arrange_below'                    = 'nf-md-vector_arrange_below'
        'nf-mdi-vector_circle'                           = 'nf-md-vector_circle'
        'nf-mdi-vector_circle_variant'                   = 'nf-md-vector_circle_variant'
        'nf-mdi-vector_combine'                          = 'nf-md-vector_combine'
        'nf-mdi-vector_curve'                            = 'nf-md-vector_curve'
        'nf-mdi-vector_difference'                       = 'nf-md-vector_difference'
        'nf-mdi-vector_difference_ab'                    = 'nf-md-vector_difference_ab'
        'nf-mdi-vector_difference_ba'                    = 'nf-md-vector_difference_ba'
        'nf-mdi-vector_intersection'                     = 'nf-md-vector_intersection'
        'nf-mdi-vector_line'                             = 'nf-md-vector_line'
        'nf-mdi-vector_point'                            = 'nf-md-vector_point'
        'nf-mdi-vector_polygon'                          = 'nf-md-vector_polygon'
        'nf-mdi-vector_polyline'                         = 'nf-md-vector_polyline'
        'nf-mdi-vector_radius'                           = 'nf-md-vector_radius'
        'nf-mdi-vector_rectangle'                        = 'nf-md-vector_rectangle'
        'nf-mdi-vector_selection'                        = 'nf-md-vector_selection'
        'nf-mdi-vector_square'                           = 'nf-md-vector_square'
        'nf-mdi-vector_triangle'                         = 'nf-md-vector_triangle'
        'nf-mdi-vector_union'                            = 'nf-md-vector_union'
        'nf-mdi-vibrate'                                 = 'nf-md-vibrate'
        'nf-mdi-video'                                   = 'nf-md-video'
        'nf-mdi-video_3d'                                = 'nf-md-video_3d'
        'nf-mdi-video_4k_box'                            = 'nf-md-video_4k_box'
        'nf-mdi-video_input_antenna'                     = 'nf-md-video_input_antenna'
        'nf-mdi-video_input_component'                   = 'nf-md-video_input_component'
        'nf-mdi-video_input_hdmi'                        = 'nf-md-video_input_hdmi'
        'nf-mdi-video_input_svideo'                      = 'nf-md-video_input_svideo'
        'nf-mdi-video_off'                               = 'nf-md-video_off'
        'nf-mdi-video_switch'                            = 'nf-md-video_switch'
        'nf-mdi-view_agenda'                             = 'nf-md-view_agenda'
        'nf-mdi-view_array'                              = 'nf-md-view_array'
        'nf-mdi-view_carousel'                           = 'nf-md-view_carousel'
        'nf-mdi-view_column'                             = 'nf-md-view_column'
        'nf-mdi-view_dashboard'                          = 'nf-md-view_dashboard'
        'nf-mdi-view_dashboard_variant'                  = 'nf-md-view_dashboard_variant'
        'nf-mdi-view_day'                                = 'nf-md-view_day'
        'nf-mdi-view_grid'                               = 'nf-md-view_grid'
        'nf-mdi-view_headline'                           = 'nf-md-view_headline'
        'nf-mdi-view_list'                               = 'nf-md-view_list'
        'nf-mdi-view_module'                             = 'nf-md-view_module'
        'nf-mdi-view_parallel'                           = 'nf-md-view_parallel'
        'nf-mdi-view_quilt'                              = 'nf-md-view_quilt'
        'nf-mdi-view_sequential'                         = 'nf-md-view_sequential'
        'nf-mdi-view_stream'                             = 'nf-md-view_stream'
        'nf-mdi-view_week'                               = 'nf-md-view_week'
        'nf-mdi-vimeo'                                   = 'nf-md-vimeo'
        'nf-mdi-violin'                                  = 'nf-md-violin'
        'nf-mdi-visualstudio'                            = 'nf-dev-visualstudio'
        'nf-mdi-vlc'                                     = 'nf-md-vlc'
        'nf-mdi-voicemail'                               = 'nf-md-voicemail'
        'nf-mdi-volume_high'                             = 'nf-md-volume_high'
        'nf-mdi-volume_low'                              = 'nf-md-volume_low'
        'nf-mdi-volume_medium'                           = 'nf-md-volume_medium'
        'nf-mdi-volume_minus'                            = 'nf-md-volume_minus'
        'nf-mdi-volume_mute'                             = 'nf-md-volume_mute'
        'nf-mdi-volume_off'                              = 'nf-md-volume_off'
        'nf-mdi-volume_plus'                             = 'nf-md-volume_plus'
        'nf-mdi-vpn'                                     = 'nf-md-vpn'
        'nf-mdi-vuejs'                                   = 'nf-md-vuejs'
        'nf-mdi-walk'                                    = 'nf-md-walk'
        'nf-mdi-wall'                                    = 'nf-md-wall'
        'nf-mdi-wallet'                                  = 'nf-md-wallet'
        'nf-mdi-wallet_giftcard'                         = 'nf-md-wallet_giftcard'
        'nf-mdi-wallet_membership'                       = 'nf-md-wallet_membership'
        'nf-mdi-wallet_travel'                           = 'nf-md-wallet_travel'
        'nf-mdi-wan'                                     = 'nf-md-wan'
        'nf-mdi-washing_machine'                         = 'nf-md-washing_machine'
        'nf-mdi-watch'                                   = 'nf-md-watch'
        'nf-mdi-watch_export'                            = 'nf-md-watch_export'
        'nf-mdi-watch_import'                            = 'nf-md-watch_import'
        'nf-mdi-watch_vibrate'                           = 'nf-md-watch_vibrate'
        'nf-mdi-water'                                   = 'nf-md-water'
        'nf-mdi-water_off'                               = 'nf-md-water_off'
        'nf-mdi-water_percent'                           = 'nf-md-water_percent'
        'nf-mdi-water_pump'                              = 'nf-md-water_pump'
        'nf-mdi-watermark'                               = 'nf-md-watermark'
        'nf-mdi-waves'                                   = 'nf-md-waves'
        'nf-mdi-weather_cloudy'                          = 'nf-md-weather_cloudy'
        'nf-mdi-weather_fog'                             = 'nf-md-weather_fog'
        'nf-mdi-weather_hail'                            = 'nf-md-weather_hail'
        'nf-mdi-weather_lightning'                       = 'nf-md-weather_lightning'
        'nf-mdi-weather_lightning_rainy'                 = 'nf-md-weather_lightning_rainy'
        'nf-mdi-weather_night'                           = 'nf-md-weather_night'
        'nf-mdi-weather_pouring'                         = 'nf-md-weather_pouring'
        'nf-mdi-weather_rainy'                           = 'nf-md-weather_rainy'
        'nf-mdi-weather_snowy'                           = 'nf-md-weather_snowy'
        'nf-mdi-weather_snowy_rainy'                     = 'nf-md-weather_snowy_rainy'
        'nf-mdi-weather_sunny'                           = 'nf-md-weather_sunny'
        'nf-mdi-weather_sunset'                          = 'nf-md-weather_sunset'
        'nf-mdi-weather_sunset_down'                     = 'nf-md-weather_sunset_down'
        'nf-mdi-weather_sunset_up'                       = 'nf-md-weather_sunset_up'
        'nf-mdi-weather_windy'                           = 'nf-md-weather_windy'
        'nf-mdi-weather_windy_variant'                   = 'nf-md-weather_windy_variant'
        'nf-mdi-web'                                     = 'nf-md-web'
        'nf-mdi-webcam'                                  = 'nf-md-webcam'
        'nf-mdi-webhook'                                 = 'nf-md-webhook'
        'nf-mdi-webpack'                                 = 'nf-md-webpack'
        'nf-mdi-wechat'                                  = 'nf-md-wechat'
        'nf-mdi-weight'                                  = 'nf-md-weight'
        'nf-mdi-weight_kilogram'                         = 'nf-md-weight_kilogram'
        'nf-mdi-whatsapp'                                = 'nf-md-whatsapp'
        'nf-mdi-wheelchair_accessibility'                = 'nf-md-wheelchair_accessibility'
        'nf-mdi-white_balance_auto'                      = 'nf-md-white_balance_auto'
        'nf-mdi-white_balance_incandescent'              = 'nf-md-white_balance_incandescent'
        'nf-mdi-white_balance_iridescent'                = 'nf-md-white_balance_iridescent'
        'nf-mdi-white_balance_sunny'                     = 'nf-md-white_balance_sunny'
        'nf-mdi-widgets'                                 = 'nf-md-widgets'
        'nf-mdi-wifi'                                    = 'nf-md-wifi'
        'nf-mdi-wifi_off'                                = 'nf-md-wifi_off'
        'nf-mdi-wikipedia'                               = 'nf-md-wikipedia'
        'nf-mdi-window_close'                            = 'nf-md-window_close'
        'nf-mdi-window_closed'                           = 'nf-md-window_closed'
        'nf-mdi-window_maximize'                         = 'nf-md-window_maximize'
        'nf-mdi-window_minimize'                         = 'nf-md-window_minimize'
        'nf-mdi-window_open'                             = 'nf-md-window_open'
        'nf-mdi-window_restore'                          = 'nf-md-window_restore'
        'nf-mdi-wordpress'                               = 'nf-md-wordpress'
        'nf-mdi-wrap'                                    = 'nf-md-wrap'
        'nf-mdi-wrench'                                  = 'nf-md-wrench'
        'nf-mdi-xamarin'                                 = 'nf-md-xamarin'
        'nf-mdi-xaml'                                    = 'nf-md-language_xaml'
        'nf-mdi-xml'                                     = 'nf-md-xml'
        'nf-mdi-xmpp'                                    = 'nf-md-xmpp'
        'nf-mdi-yeast'                                   = 'nf-md-yeast'
        'nf-mdi-yin_yang'                                = 'nf-md-yin_yang'
        'nf-mdi-youtube_gaming'                          = 'nf-md-youtube_gaming'
        'nf-mdi-youtube_tv'                              = 'nf-md-youtube_tv'
        'nf-mdi-zip_box'                                 = 'nf-md-zip_box'
    }

    $RemovedGlyphs = @(
        'nf-oct-settings',
        'nf-oct-circuit_board',
        'nf-mdi-send_secure',
        'nf-mdi-amazon',
        'nf-mdi-cellphone_android',
        'nf-oct-primitive_square',
        'nf-mdi-account_location',
        'nf-mdi-flattr',
        'nf-mdi-laptop_windows',
        'nf-mdi-cash_usd',
        'nf-mdi-youtube_play',
        'nf-mdi-roomba',
        'nf-mdi-camcorder_box',
        'nf-mdi-basecamp',
        'nf-mdi-xbox',
        'nf-mdi-book_unsecure',
        'nf-mdi-voice',
        'nf-mdi-book_secure',
        'nf-mdi-houzz_box',
        'nf-mdi-github_box',
        'nf-oct-trashcan',
        'nf-mdi-plane_shield',
        'nf-mdi-vk_box',
        'nf-mdi-settings',
        'nf-mdi-json',
        'nf-mdi-xbox_controller_battery_full',
        'nf-mdi-markdown',
        'nf-mdi-mixcloud',
        'nf-mdi-etsy',
        'nf-mdi-disk_alert',
        'nf-mdi-hotel',
        'nf-mdi-internet_explorer',
        'nf-mdi-nest_thermostat',
        'nf-mdi-venmo',
        'nf-mdi-vk_circle',
        'nf-mdi-music_note_eighth',
        'nf-mdi-yammer',
        'nf-mdi-library_plus',
        'nf-mdi-radiobox_blank',
        'nf-mdi-format_list_numbers',
        'nf-mdi-worker',
        'nf-mdi-image_filter',
        'nf-mdi-maxcdn',
        'nf-mdi-behance',
        'nf-mdi-security_home',
        'nf-mdi-wii',
        'nf-mdi-playstation',
        'nf-mdi-google_wallet',
        'nf-mdi-settings_box',
        'nf-oct-ellipses',
        'nf-mdi-square_inc',
        'nf-mdi-yelp',
        'nf-mdi-pinterest_box',
        'nf-oct-jersey',
        'nf-mdi-uber',
        'nf-oct-octoface',
        'nf-mdi-blogger',
        'nf-mdi-twitter_circle',
        'nf-mdi-xing_circle',
        'nf-mdi-office',
        'nf-oct-gist_secret',
        'nf-mdi-currency_chf',
        'nf-mdi-tooltip_outline_plus',
        'nf-mdi-circle_outline',
        'nf-mdi-xbox_controller_battery_unknown',
        'nf-mdi-file_document_box',
        'nf-mdi-foursquare',
        'nf-mdi-twitter_box',
        'nf-mdi-google_photos',
        'nf-mdi-houzz',
        'nf-mdi-cisco_webex',
        'nf-mdi-quicktime',
        'nf-mdi-glassdoor',
        'nf-oct-primitive_dot',
        'nf-mdi-youtube_creator_studio',
        'nf-mdi-xing_box',
        'nf-mdi-plus_one',
        'nf-mdi-buffer',
        'nf-oct-cloud_upload',
        'nf-mdi-dribbble_box',
        'nf-mdi-eventbrite',
        'nf-mdi-laptop_mac',
        'nf-oct-arrow_small_down',
        'nf-mdi-tumblr',
        'nf-mdi-periscope',
        'nf-mdi-bible',
        'nf-mdi-instapaper',
        'nf-oct-mail_reply',
        'nf-oct-gist',
        'nf-mdi-xbox_controller_battery_empty',
        'nf-mdi-edge',
        'nf-mdi-chart_scatterplot_hexbin',
        'nf-mdi-disqus_outline',
        'nf-mdi-hangouts',
        'nf-mdi-poll_box',
        'nf-mdi-phone_locked',
        'nf-mdi-face_profile',
        'nf-mdi-tablet_ipad',
        'nf-mdi-flash_circle',
        'nf-mdi-beats',
        'nf-mdi-linkedin_box',
        'nf-oct-dashboard',
        'nf-oct-arrow_small_right',
        'nf-mdi-windows',
        'nf-mdi-airplay',
        'nf-mdi-disk',
        'nf-mdi-xing',
        'nf-mdi-android_debug_bridge',
        'nf-mdi-account_settings_variant',
        'nf-mdi-xbox_controller_battery_alert',
        'nf-mdi-mixer',
        'nf-oct-file_pdf',
        'nf-oct-repo_force_push',
        'nf-mdi-google_plus_box',
        'nf-mdi-dictionary',
        'nf-oct-plus_small',
        'nf-mdi-twitter_retweet',
        'nf-mdi-circle',
        'nf-mdi-dribbble',
        'nf-mdi-untappd',
        'nf-mdi-xbox_controller_off',
        'nf-mdi-mail_ru',
        'nf-mdi-message_settings_variant',
        'nf-mdi-loop',
        'nf-mdi-bandcamp',
        'nf-mdi-nest_protect',
        'nf-oct-clippy',
        'nf-mdi-xbox_controller_battery_low',
        'nf-mdi-wunderlist',
        'nf-mdi-coins',
        'nf-oct-mail_read',
        'nf-oct-file_text',
        'nf-mdi-coin',
        'nf-mdi-martini',
        'nf-mdi-xbox_controller_battery_medium',
        'nf-mdi-stackexchange',
        'nf-mdi-medium',
        'nf-mdi-sort_numeric',
        'nf-mdi-email_secure',
        'nf-mdi-square_inc_cash',
        'nf-mdi-allo',
        'nf-mdi-book_multiple_variant',
        'nf-mdi-wiiu',
        'nf-mdi-do_not_disturb',
        'nf-mdi-hackernews',
        'nf-oct-text_size',
        'nf-mdi-pocket',
        'nf-mdi-fridge_filled_top',
        'nf-mdi-login_variant',
        'nf-mdi-lastfm',
        'nf-mdi-textbox_password',
        'nf-mdi-xda',
        'nf-mdi-vk',
        'nf-mdi-douban',
        'nf-mdi-artist',
        'nf-mdi-periodic_table_co2',
        'nf-mdi-contact_mail',
        'nf-mdi-fridge_filled_bottom',
        'nf-mdi-laptop_chromebook',
        'nf-mdi-verified',
        'nf-mdi-itunes',
        'nf-mdi-xamarin_outline',
        'nf-mdi-android_head',
        'nf-oct-paintcan',
        'nf-mdi-do_not_disturb_off',
        'nf-mdi-apple_mobileme',
        'nf-oct-watch',
        'nf-mdi-google_physical_web',
        'nf-oct-arrow_small_up',
        'nf-oct-no_newline',
        'nf-mdi-camcorder_box_off',
        'nf-oct-keyboard',
        'nf-mdi-cellphone_iphone',
        'nf-mdi-telegram',
        'nf-mdi-terrain',
        'nf-mdi-pharmacy',
        'nf-mdi-github_circle',
        'nf-mdi-face',
        'nf-mdi-tumblr_reblog',
        'nf-mdi-sort_alphabetical',
        'nf-mdi-textbox',
        'nf-mdi-google_pages',
        'nf-mdi-approval',
        'nf-mdi-bing',
        'nf-mdi-onenote',
        'nf-mdi-facebook_box',
        'nf-mdi-raspberrypi',
        'nf-mdi-audiobook',
        'nf-mdi-fridge_filled',
        'nf-mdi-language_python_text',
        'nf-mdi-tor',
        'nf-mdi-amazon_clouddrive',
        'nf-mdi-account_card_details',
        'nf-mdi-towing',
        'nf-oct-radio_tower',
        'nf-oct-cloud_download',
        'nf-mdi-blackberry',
        'nf-mdi-gradient',
        'nf-oct-arrow_small_left',
        'nf-mdi-weather_partlycloudy',
        'nf-mdi-xbox_controller'
        )


    # Resolve path(s)
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $paths = Resolve-Path -Path $Path | Select-Object -ExpandProperty Path
    } elseif ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
        $paths = Resolve-Path -LiteralPath $LiteralPath | Select-Object -ExpandProperty Path
    }

    foreach ($resolvedPath in $paths) {
        if (Test-Path $resolvedPath) {
            $item = Get-Item -LiteralPath $resolvedPath

            $Theme = Get-Content $item -Raw

            foreach ($OldGlyph in $MigrationMap.Keys) {
                $Theme = $Theme -replace "('|`")$OldGlyph('|`")", "`$1$($MigrationMap[$OldGlyph])`$2"
            }

            $GlyphsWithNoAutoMigration = @()
            foreach ($OldGlyph in $RemovedGlyphs) {
                if ($Theme -match $OldGlyph) {
                    $GlyphsWithNoAutoMigration += $OldGlyph
                }
            }

            if ($GlyphsWithNoAutoMigration.Count -gt 0) {
                Write-Warning "The following glyphs were found to be present in your theme and do not have any auto-migration path. Please find a replacement for them yourself:`r`n`r`n$($GlyphsWithNoAutoMigration -join "`r`n")"
            }

            return $Theme
        } else {
            Write-Error "Path [$resolvedPath] is not valid."
        }
    }
}
function Remove-TerminalIconsTheme {
    <#
    .SYNOPSIS
        Removes a color or icon theme
    .DESCRIPTION
        Removes a given icon or color theme. In order to be removed, a theme must not be active.
    .PARAMETER IconTheme
        The icon theme to remove.
    .PARAMETER ColorTheme
        The color theme to remove.
    .PARAMETER Force
        Bypass confirmation messages.
    .EXAMPLE
        PS> Remove-TerminalIconsTheme -IconTheme MyAwesomeTheme

        Removes the icon theme 'MyAwesomeTheme'
    .EXAMPLE
        PS> Remove-TerminalIconsTheme -ColorTheme MyAwesomeTheme

        Removes the color theme 'MyAwesomeTheme'
    .INPUTS
        System.String

        The name of the color or icon theme to remove.
    .OUTPUTS
        None.
    .LINK
        Set-TerminalIconsTheme
    .LINK
        Add-TerminalIconsColorTheme
    .LINK
        Add-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsTheme
    .NOTES
        A theme must not be active in order to be removed.
    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [ArgumentCompleter({
            (Get-TerminalIconsIconTheme).Keys | Sort-Object
        })]
        [string]$IconTheme,

        [ArgumentCompleter({
            (Get-TerminalIconsColorTheme).Keys | Sort-Object
        })]
        [string]$ColorTheme,

        [switch]$Force
    )

    $currentTheme     = Get-TerminalIconsTheme
    $themeStoragePath = Get-ThemeStoragePath

    if ($ColorTheme) {
        if ($currentTheme.Color.Name -ne $ColorTheme) {
            $themePath = Join-Path $themeStoragePath "$($ColorTheme)_color.xml"
            if (-not (Test-Path $themePath)) {
                Write-Error "Could not find theme file [$themePath]"
            } else {
                if ($Force -or $PSCmdlet.ShouldProcess($ColorTheme, 'Remove color theme')) {
                    if ($userThemeData.Themes.Color.ContainsKey($ColorTheme)) {
                        $userThemeData.Themes.Color.Remove($ColorTheme)
                    } else {
                        # We shouldn't be here
                        Write-Error "Color theme [$ColorTheme] is not registered."
                    }
                    Remove-Item $themePath -Force
                }
            }
        } else {
            Write-Error ("Color theme [{0}] is active. Please select another theme before removing this it." -f $ColorTheme)
        }
    }

    if ($IconTheme) {
        if ($currentTheme.Icon.Name -ne $IconTheme) {
            $themePath = Join-Path $themeStoragePath "$($IconTheme)_icon.xml"
            if (-not (Test-Path $themePath)) {
                Write-Error "Could not find theme file [$themePath]"
            } else {
                if ($Force -or $PSCmdlet.ShouldProcess($ColorTheme, 'Remove icon theme')) {
                    if ($userThemeData.Themes.Icon.ContainsKey($IconTheme)) {
                        $userThemeData.Themes.Icon.Remove($IconTheme)
                    } else {
                        # We shouldn't be here
                        Write-Error "Icon theme [$IconTheme] is not registered."
                    }
                    Remove-Item $themePath -Force
                }
            }
        } else {
            Write-Error ("Icon theme [{0}] is active. Please select another theme before removing this it." -f $IconTheme)
        }
    }
}
function Set-TerminalIconsIcon {
    <#
    .SYNOPSIS
        Set a specific icon in the current Terminal-Icons icon theme or allows
        swapping one glyph for another.
    .DESCRIPTION
        Set the Terminal-Icons icon for a specific file/directory or glyph to a
        named glyph.

        Also allows all uses of a specific glyph to be replaced with a different
        glyph.
    .PARAMETER Directory
        The well-known directory name to match for the icon.
    .PARAMETER FileName
        The well-known file name to match for the icon.
    .PARAMETER FileExtension
        The file extension to match for the icon.
    .PARAMETER NewGlyph
        The name of the new glyph to use when swapping.
    .PARAMETER Glyph
        The name of the glyph to use; or, when swapping glyphs, the name of the
        glyph you want to change.
    .PARAMETER Force
        Bypass confirmation messages.
    .EXAMPLE
        PS> Set-TerminalIconsIcon -FileName "README.md" -Glyph "nf-fa-file_text"

        Set README.md files to display a text file icon.
    .EXAMPLE
        PS> Set-TerminalIconsIcon -FileExtension ".xml" -Glyph "nf-md-xml"

        Set XML files to display an XML file icon.
    .EXAMPLE
        PS> Set-TerminalIconsIcon -Directory ".github" -Glyph "nf-dev-github_alt"

        Set directories named ".github" to display an Octocat face icon.
    .EXAMPLE
        PS> Set-TerminalIconsIcon -Glyph "nf-md-xml" -NewGlyph "nf-md-xml"

        Changes all uses of the "nf-md-xml" double-wide glyph to be the "nf-md-xml"
        single-width XML file glyph.
    .INPUTS
        None.

        The command does not accept pipeline input.
    .OUTPUTS
        None.
    .LINK
        Get-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsTheme
    .LINK
        Get-TerminalIconsGlyphs
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = "ArgumentCompleter parameters don't all get used.")]
    [cmdletbinding(SupportsShouldProcess, DefaultParameterSetName = "FileExtension")]
    param(
        [Parameter(ParameterSetName = "Directory", Mandatory)]
        [ArgumentCompleter( {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-TerminalIconsIconTheme).Values.Types.Directories.WellKnown.Keys | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateNotNullOrEmpty()]
        [string]$Directory,

        [Parameter(ParameterSetName = "FileName", Mandatory)]
        [ArgumentCompleter( {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-TerminalIconsIconTheme).Values.Types.Files.WellKnown.Keys | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,

        [Parameter(ParameterSetName = "FileExtension", Mandatory)]
        [ArgumentCompleter( {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-TerminalIconsIconTheme).Values.Types.Files.Keys | Where-Object { $_.StartsWith(".") -and $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidatePattern("^\.")]
        [string]$FileExtension,

        [Parameter(ParameterSetName = "SwapGlyph", Mandatory)]
        [ArgumentCompleter( {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-TerminalIconsGlyphs).Keys | Where-Object { $_ -like "*$wordToComplete*" } | Sort-Object
            })]
        [ValidateNotNullOrEmpty()]
        [string]$NewGlyph,

        [Parameter(Mandatory)]
        [ArgumentCompleter( {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (Get-TerminalIconsGlyphs).Keys | Where-Object { $_ -like "*$wordToComplete*" } | Sort-Object
            })]
        [ValidateNotNullOrEmpty()]
        [string]$Glyph,

        [switch]$Force
    )

    If($PSCmdlet.ParameterSetName -eq "Directory") {
        If ($Force -or $PSCmdlet.ShouldProcess("$Directory = $Glyph", 'Set well-known directory icon')) {
            (Get-TerminalIconsIconTheme).Values.Types.Directories.WellKnown[$Directory] = $Glyph
        }
    }
    ElseIf ($PSCmdlet.ParameterSetName -eq "FileName") {
        If ($Force -or $PSCmdlet.ShouldProcess("$FileName = $Glyph", 'Set well-known file name icon')) {
            (Get-TerminalIconsIconTheme).Values.Types.Files.WellKnown[$FileName] = $Glyph
        }
    }
    ElseIf ($PSCmdlet.ParameterSetName -eq "FileExtension") {
        If ($Force -or $PSCmdlet.ShouldProcess("$FileExtension = $Glyph", 'Set file extension icon')) {
            (Get-TerminalIconsIconTheme).Values.Types.Files[$FileExtension] = $Glyph
        }
    }
    ElseIf ($PSCmdlet.ParameterSetName -eq "SwapGlyph") {
        If ($Force -or $PSCmdlet.ShouldProcess("$Glyph to $NewGlyph", 'Swap glyph usage')) {
            # Directories
            $toModify = (Get-TerminalIconsTheme).Icon.Types.Directories.WellKnown
            $keys = $toModify.Keys | Where-Object { $toModify[$_] -eq $Glyph }
            $keys | ForEach-Object { $toModify[$_] = $NewGlyph }

            # Files
            $toModify = (Get-TerminalIconsTheme).Icon.Types.Files.WellKnown
            $keys = $toModify.Keys | Where-Object { $toModify[$_] -eq $Glyph }
            $keys | ForEach-Object { $toModify[$_] = $NewGlyph }

            # Extensions
            $toModify = (Get-TerminalIconsTheme).Icon.Types.Files
            $keys = $toModify.Keys | Where-Object { $_.StartsWith(".") -and $toModify[$_] -eq $Glyph }
            $keys | ForEach-Object { $toModify[$_] = $NewGlyph }
        }
    }
}
function Set-TerminalIconsTheme {
    <#
    .SYNOPSIS
        Set the Terminal-Icons color or icon theme
    .DESCRIPTION
        Set the Terminal-Icons color or icon theme to the given name.
    .PARAMETER ColorTheme
        The name of a registered color theme to use.
    .PARAMETER IconTheme
        The name of a registered icon theme to use.
    .PARAMETER DisableColorTheme
        Disables custom colors and uses default terminal color.
    .PARAMETER DisableIconTheme
        Disables custom icons and shows only shows the directory or file name.
    .PARAMETER Force
        Bypass confirmation messages.
    .EXAMPLE
        PS> Set-TerminalIconsTheme -ColorTheme devblackops

        Set the color theme to 'devblackops'.
    .EXAMPLE
        PS> Set-TerminalIconsTheme -IconTheme devblackops

        Set the icon theme to 'devblackops'.
    .EXAMPLE
        PS> Set-TerminalIconsTheme -DisableIconTheme

        Disable Terminal-Icons custom icons and only show custom colors.
    .EXAMPLE
        PS> Set-TerminalIconsTheme -DisableColorTheme

        Disable Terminal-Icons custom colors and only show custom icons.
    .INPUTS
        System.String

        The name of the color or icon theme to use.
    .OUTPUTS
        None.
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsTheme
    .NOTES
        This function supercedes Set-TerminalIconsColorTheme and Set-TerminalIconsIconTheme. They have been deprecated.
    #>
    [cmdletbinding(SupportsShouldProcess, DefaultParameterSetName = 'theme')]
    param(
        [Parameter(ParameterSetName = 'theme')]
        [ArgumentCompleter({
            (Get-TerminalIconsIconTheme).Keys | Sort-Object
        })]
        [string]$IconTheme,

        [Parameter(ParameterSetName = 'theme')]
        [ArgumentCompleter({
            (Get-TerminalIconsColorTheme).Keys | Sort-Object
        })]
        [string]$ColorTheme,

        [Parameter(ParameterSetName = 'notheme')]
        [switch]$DisableColorTheme,

        [Parameter(ParameterSetName = 'notheme')]
        [switch]$DisableIconTheme,

        [switch]$Force
    )

    if ($DisableIconTheme.IsPresent) {
        Set-Theme -Name $null -Type Icon
    }

    if ($DisableColorTheme.IsPresent) {
        Set-Theme -Name $null -Type Color
    }

    if ($ColorTheme) {
        if ($Force -or $PSCmdlet.ShouldProcess($ColorTheme, 'Set color theme')) {
            Set-Theme -Name $ColorTheme -Type Color
        }
    }

    if ($IconTheme) {
        if ($Force -or $PSCmdlet.ShouldProcess($IconTheme, 'Set icon theme')) {
            Set-Theme -Name $IconTheme -Type Icon
        }
    }
}

function Show-TerminalIconsTheme {
    <#
    .SYNOPSIS
        List example directories and files to show the currently applied color and icon themes.
    .DESCRIPTION
        List example directories and files to show the currently applied color and icon themes.
        The directory/file objects show are in memory only, they are not written to the filesystem.
    .PARAMETER ColorTheme
        The color theme to use for examples
    .PARAMETER IconTheme
        The icon theme to use for examples
    .EXAMPLE
        Show-TerminalIconsTheme

        List example directories and files to show the currently applied color and icon themes.
    .INPUTS
        None.
    .OUTPUTS
        System.IO.DirectoryInfo
    .OUTPUTS
        System.IO.FileInfo
    .NOTES
        Example directory and file objects only exist in memory. They are not written to the filesystem.
    .LINK
        Get-TerminalIconsColorTheme
    .LINK
        Get-TerminalIconsIconTheme
    .LINK
        Get-TerminalIconsTheme
    #>
    [CmdletBinding()]
    param()

    $theme = Get-TerminalIconsTheme

    # Use the default theme if the icon theme has been disabled
    if ($theme.Icon) {
        $themeName = $theme.Icon.Name
    } else {
        $themeName = $script:defaultTheme
    }

    $directories = @(
        [IO.DirectoryInfo]::new('ExampleFolder')
        $script:userThemeData.Themes.Icon[$themeName].Types.Directories.WellKnown.Keys.ForEach({
            [IO.DirectoryInfo]::new($_)
        })
    )
    $wellKnownFiles = @(
        [IO.FileInfo]::new('ExampleFile')
        $script:userThemeData.Themes.Icon[$themeName].Types.Files.WellKnown.Keys.ForEach({
            [IO.FileInfo]::new($_)
        })
    )

    $extensions = $script:userThemeData.Themes.Icon[$themeName].Types.Files.Keys.Where({$_ -ne 'WellKnown'}).ForEach({
        [IO.FileInfo]::new("example$_")
    })

    $directories + $wellKnownFiles + $extensions | Sort-Object | Format-TerminalIcons
}
# Dot source public/private functions
# $public  = @(Get-ChildItem -Path ([IO.Path]::Combine($PSScriptRoot, 'Public/*.ps1'))  -Recurse -ErrorAction Stop)
# $private = @(Get-ChildItem -Path ([IO.Path]::Combine($PSScriptRoot, 'Private/*.ps1')) -Recurse -ErrorAction Stop)
# @($public + $private).ForEach({
#     try {
#         . $_.FullName
#     } catch {
#         throw $_
#         $PSCmdlet.ThrowTerminatingError("Unable to dot source [$($import.FullName)]")
#     }
# })

$moduleRoot    = $PSScriptRoot
$glyphs        = Invoke-Expression "& `"$moduleRoot/Data/glyphs.ps1`""
$escape        = [char]27
$colorReset    = "${escape}[0m"
$defaultTheme  = 'devblackops'
$userThemePath = Get-ThemeStoragePath
$userThemeData = @{
    CurrentIconTheme  = $null
    CurrentColorTheme = $null
    Themes = @{
        Color = @{}
        Icon  = @{}
    }
}

# Import builtin icon/color themes and convert colors to escape sequences
$colorSequences = @{}
$iconThemes     = Import-IconTheme
$colorThemes    = Import-ColorTheme
$colorThemes.GetEnumerator().ForEach({
    $colorSequences[$_.Name] = ConvertTo-ColorSequence -ColorData $_.Value
})

# Load or create default prefs
$prefs = Import-Preferences

# Set current theme
$userThemeData.CurrentIconTheme  = $prefs.CurrentIconTheme
$userThemeData.CurrentColorTheme = $prefs.CurrentColorTheme

# Load user icon and color themes
# We're ignoring the old 'theme.xml' from Terimal-Icons v0.3.1 and earlier
(Get-ChildItem $userThemePath -Filter '*_icon.xml').ForEach({
    $userIconTheme = Import-CliXml -Path $_.FullName
    $userThemeData.Themes.Icon[$userIconTheme.Name] = $userIconTheme
})
(Get-ChildItem $userThemePath -Filter '*_color.xml').ForEach({
    $userColorTheme = Import-CliXml -Path $_.FullName
    $userThemeData.Themes.Color[$userColorTheme.Name] = $userColorTheme
    $colorSequences[$userColorTheme.Name] = ConvertTo-ColorSequence -ColorData $userThemeData.Themes.Color[$userColorTheme.Name]
})

# Update the builtin themes
$colorThemes.GetEnumerator().ForEach({
    $userThemeData.Themes.Color[$_.Name] = $_.Value
})
$iconThemes.GetEnumerator().ForEach({
    $userThemeData.Themes.Icon[$_.Name] = $_.Value
})

# Save all themes to theme path
$userThemeData.Themes.Color.GetEnumerator().ForEach({
    $colorThemePath = Join-Path $userThemePath "$($_.Name)_color.xml"
    $_.Value | Export-Clixml -Path $colorThemePath -Force
})
$userThemeData.Themes.Icon.GetEnumerator().ForEach({
    $iconThemePath = Join-Path $userThemePath "$($_.Name)_icon.xml"
    $_.Value | Export-Clixml -Path $iconThemePath -Force
})

Save-Preferences -Preferences $prefs

# Export-ModuleMember -Function $public.Basename

Update-FormatData -Prepend ([IO.Path]::Combine($moduleRoot, 'Terminal-Icons.format.ps1xml'))

