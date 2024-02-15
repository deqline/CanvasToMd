$script:markdownbuffer = ""

function ConvertCanvas {
    param(
        [System.String]$InputPath,
        [System.String]$OutputPath
    )

    Try {
<#        $InputPath = "Intro.canvas"#> 
        $json = Get-Content -Raw -Path $InputPath
        $global = ConvertFrom-Json -InputObject $json

        $nodes = $global.nodes
        $edges = $global.edges

        $hashNodes = @{}
        $hashEdges = @{}

        For($i = 0; $i -lt $nodes.Count;$i++) {
            $hashNodes[$nodes[$i].id] = $nodes[$i] 
        }
      
        $rootNodes = FindRootNodes $hashNodes $edges 

        ForEach ($node in $rootNodes) {
            if($node.type -eq "file") {
                # ${...} corresponds to String Interpolation
                Write-Warning "Root file node detected, please connect it (file: " + $node.file + ")"
                Exit
            }

            # Node already contains headers, in this case keep them as they are
            if(-not $node.text.Contains("#")) {
                $script:markdownbuffer += "##"
            }
            $script:markdownbuffer += $node.text + [System.Environment]::NewLine

            $rootChildEdges = FindNodeChildEdges $node.id $edges

            ForEach ($childEdge in $rootChildEdges) {
                IterateEdges $childEdge $hashNodes $edges " "
            }

        }
        
        Write-Host ("Processed " + $nodes.Count + " nodes.")

        Set-Content -Path $OutputPath -Value $script:markdownbuffer

        Write-Host ("Wrote output to " + $OutputPath + " -> size: " + [int]((Get-Item $OutputPath).Length / 1kb) + "KB")
    } 
    Catch [System.Management.Automation.ItemNotFoundException] {
	    Write-Output "[ - ] $FilePath does not exist."
    }
}

function FindRootNodes {
    param (
        [System.Collections.Hashtable]$hashN,
        [System.Object]$edges
    )

    #For each node id check if every edge does not contain a reference 
    #for this id in toNode 

    $roots = @()

    ForEach ($nodeid in $hashN.keys) {
        $isRoot = $true
        
<#        if($hashN[$nodeid].type -eq "file") {
            Continue
        }#>

        ForEach ($edge in $edges) {
            if ($edge.toNode -eq $nodeid) {
                $isRoot = $false
                Break
            }
        }
        if($isRoot) {
            $roots += $hashN[$nodeid]
        }
    }
    return $roots
}

function FindNodeChildEdges {
    param(
        [System.String]$nodeid,
        [System.Object[]]$edges
    )

    $childs = @()

    ForEach ($edge in $edges) {
        if($edge.fromNode -eq $nodeid) {
            $childs += $edge
        }
    }

    return $childs
}

function IterateEdges {
param (
    [System.Object]$currentEdge,
    [System.Collections.Hashtable]$hashN,
    [System.Object[]]$edges,
    [System.String]$level

)
    if($currentEdge -eq $null) {
        return
    } else {
        Write-Debug $currentEdge
        $EquivNode = $hashN[$currentEdge.toNode]

        if($EquivNode.type -eq "text") {
            if(-not $EquivNode.text.Contains("#")) {
                $paragraphWithSpaces = PrefixParagraph $EquivNode.text ($level + "- ")
                $script:markdownbuffer += $paragraphWithSpaces + [System.Environment]::NewLine
            } else {
                $script:markdownbuffer += $EquivNode.text + [System.Environment]::NewLine
            }
            
        } elseif($EquivNode.type -eq "file") {
            Write-Debug $EquivNode.file
            $script:markdownbuffer += "![" + $EquivNode.width + "x" + $EquivNode.height +  "](" + $EquivNode.file + ")" + [System.Environment]::NewLine
        }

        $script:markdownbuffer += [System.Environment]::NewLine

        $childEdges = FindNodeChildEdges $EquivNode.id $edges
        ForEach ($child in $childEdges) {
            IterateEdges $child $hashN $edges ($level + " ")
        }
    }

}

function PrefixParagraph {
    param(
        [System.String]$text,
        [System.String]$separator

    )

    $lines = $text.Split("`n")
    $numLines = $lines.Count

    #do not append separator to last line
    For($i = 0;$i -lt $numLines;$i++) {
        if($lines[$i].Length -lt 2){
            Continue
        }
        $lines[$i] = $separator + $lines[$i].Replace("-", "") # remove pre-existent separators
    }

    return [String]::Join("`n", $lines)

}

ConvertCanvas -InputPath $args[0] -OutputPath $args[1]
