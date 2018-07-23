begin {
    function add-member {
        param($type, $name, $value, $input)
        $note = "system.management.automation.psnoteproperty"
        $member = new-object $note $name,$value
        $metaInfoObj.psobject.members.add($member)
        return $metaInfoObj
    }
    
    function emitMetaInfoObject($path) {
        [string]$path = (resolve-path $path).ProviderPath
        [string]$dir  = split-path $path
        [string]$file = split-path $path -leaf
        $shellApp = new-object -com shell.application
        $myFolder = $shellApp.Namespace($dir)
        $items = $myFolder.Items()
        $fileobj = $items.Item($file)
        
        $metaInfoObj = new-object system.management.automation.psobject
        $metaInfoObj.psobject.typenames[0] = "Custom.IO.File.Metadata"
        $metaInfoObj = add-member noteproperty Path $path -input $metaInfoObj
        0..1024 | % {
            $key = $myFolder.GetDetailsOf($objFolder.items, $_)
            $v = $myFolder.GetDetailsOf($fileobj,$_)
            if ($v)
            { 
                $metaInfoObj = add-member noteproperty $key $v -input $metaInfoObj 
            }
        }
        write-output $metaInfoObj
    }
}

process {
    if ($_) {
        emitMetaInfoObject $_
    }
}

end {
    if ($args) {
        $paths
        foreach ($path in $args) {
            if (!(test-path $path)) {
                write-error "$path is not a valid path"
            }
            $paths += resolve-path $path
        }
    
        foreach ($path in $paths) {
            emitMetaInfoObject $path
        }
    }
}
