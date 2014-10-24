declare namespace zip  = "xdmp:zip";
declare namespace ssml = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

declare variable $NS := "http://tax.thomsonreuters.com";
declare variable $OPTIONS as element () :=
                 <options xmlns="xdmp:zip-get">
                   <format>xml</format>
                 </options>;

(:~
 : Iterate the network directory where the spreadsheet files (xslx files) reside.
 : Traverses the network directory recursively.
 :
 : @param $path The network directory where the XLSX files reside.
 :
 : Returns the complete list of XLSX files.
 :)
declare function local:loadDirectory($path as xs:string)
{
  try
  {
    for $entry in xdmp:filesystem-directory($path)/dir:entry
      let $subpath := $entry/dir:pathname/text()
        return
          if ( $entry/dir:type = 'directory' ) then
            local:loadDirectory($subpath)
          else
            $subpath
  }
  catch ($e) {()}
};

(:~
 : Get Value from Defined Name
 :
 : @param $cell
 : @param $doc
 :)
declare function local:getValue($row as xs:string, $col as xs:string, $sheetName as xs:string, $table, $rels, $wkBook, $sharedStrings)
{
  let $wkSheetKey := "xl/"||xs:string($rels/*:Relationship[@Id=$wkBook[@name=$sheetName]/@*:id]/@Target)

  let $wkSheet := map:get($table, $wkSheetKey)
  let $item     := $wkSheet/*:worksheet/*:sheetData/*:row[@r=$row]/*:c[@r=$col||$row]

  let $ref     := $item/@t
  let $value   := xs:string($item/*:v)

  let $retVal  := if ($ref eq "s") then $sharedStrings[xs:integer($value) + 1] else $value

let $log := xdmp:log("111----- cell  = "||$col||$row)
let $log := xdmp:log("111----- value = "||$retVal)

  return $retVal
};

(:~
 : Get Value from Defined Name
 :
 : @param $cell
 : @param $doc
 :)
declare function local:getLabelValue1($row as xs:string, $col as xs:string, $sheetName as xs:string, $table, $rels, $wkBook, $sharedStrings)
{
  let $leftCell := local:getLeftCell($col)

let $log := xdmp:log("1----- getLabelValue() leftCell  = "||$leftCell)

  let $retVal   := local:getValue($row, $leftCell, $sheetName, $table, $rels, $wkBook, $sharedStrings)

let $log := xdmp:log("1----- getLabelValue() cell  = "||$col||$row)
let $log := xdmp:log("1----- getLabelValue() label = "||$retVal)

  return $retVal
};

(:~
 : Entry point to a recursive function.
 :
 : @param $row
 :)
declare function local:findLabel($row as xs:string, $col as xs:string, $sheetName as xs:string, $table, $rels, $wkBook, $sharedStrings) as xs:string*
{
  let $leftLabelVal := local:getLabelValue($row, $col, $sheetName, $table, $rels, $wkBook, $sharedStrings)

let $log := xdmp:log("1----- findLabel() leftLabelVal = "||$leftLabelVal)

  return $leftLabelVal
};

declare function local:getLabelValue($row as xs:string, $col as xs:string, $sheetName as xs:string, $table, $rels, $wkBook, $sharedStrings)
{
  let $pattern  := "[a-zA-Z]"

  let $leftCell := local:getLeftCell($col)
  
let $log := xdmp:log("1----- getLabelValue() cell  = "||$col||$row)
let $log := xdmp:log("1----- getLabelValue() value = "||local:getValue($row, $leftCell, $sheetName, $table, $rels, $wkBook, $sharedStrings))

  return
    if (fn:matches(local:getValue($row, $leftCell, $sheetName, $table, $rels, $wkBook, $sharedStrings), $pattern) or
        (fn:string-to-codepoints($leftCell) lt 66)) then
      local:getValue($row, $leftCell, $sheetName, $table, $rels, $wkBook, $sharedStrings)
    else
      local:getLabelValue($row, $leftCell, $sheetName, $table, $rels, $wkBook, $sharedStrings)
};

declare function local:getLeftCell($col as xs:string)
{
  let $upperCol      := fn:upper-case($col)
  let $lastCharCode  := fn:string-to-codepoints($upperCol)[fn:last()]
  let $decrementChar := fn:codepoints-to-string(fn:string-to-codepoints($upperCol)[fn:last()] - 1)

  let $retVal :=
    if (($lastCharCode) eq 65) then  (: "A" :)
      $upperCol
    else
      fn:substring($upperCol, 1, fn:string-length($upperCol) - 1)||$decrementChar

let $log := xdmp:log("1----- getLeftCell() leftCell  = "||$retVal)

  return $retVal
};

(:~
 : Generate File URI
 :
 : @param $cell
 :)
declare function local:generateFileUri($user as xs:string, $fileName as xs:string)
{
  let $fileUri := "/user/"||$user||"/files/"||fn:tokenize($fileName, "/")[fn:last()]
  
  return $fileUri
};

(:~
 : Extract Spreadsheet Data
 :
 : @param $zipfile
 :)
declare function local:extractSpreadsheetData($user as xs:string, $zipFile as xs:string)
{
  let $excelFile := xdmp:document-get($zipFile)

  let $exclude :=
  (
    "[Content_Types].xml", "docProps/app.xml", "xl/theme/theme1.xml", "xl/styles.xml", "_rels/.rels",
    "xl/printerSettings/printerSettings1.bin", "xl/printerSettings/printerSettings2.bin",
    "xl/printerSettings/printerSettings3.bin", "xl/printerSettings/printerSettings4.bin",
    "xl/printerSettings/printerSettings5.bin",
    "xl/vbaProject.bin", "xl/media/image1.png"
  )

  let $table := map:map()
  
  let $docs :=
    for $x in xdmp:zip-manifest($excelFile)//zip:part/text()
      where (($x = $exclude) eq fn:false())
        return
          map:put($table, $x, xdmp:zip-get($excelFile, $x, $OPTIONS))

  let $defnames      := map:get($table, "xl/workbook.xml")/*:workbook/*:definedNames/node()
  let $wkBook        := map:get($table, "xl/workbook.xml")/*:workbook/*:sheets/*:sheet
  let $rels          := map:get($table, "xl/_rels/workbook.xml.rels")/*:Relationships
  let $sharedStrings := map:get($table, "xl/sharedStrings.xml")/*:sst/*:si/*:t/text()

  let $workSheets :=
    element { fn:QName($NS, "worksheets") }
    {
      for $ws in $wkBook
        let $wkSheetKey := "xl/"||xs:string($rels/*:Relationship[@Id=$ws/@*:id/fn:string()]/@Target)
        let $relWkSheet := map:get($table, $wkSheetKey)
        let $dim := $relWkSheet/*:worksheet/*:dimension/@ref/fn:string()
          return
            element { fn:QName($NS, "worksheet") }
            {
              element { fn:QName($NS, "name") } { $ws/@name/fn:string() },
              element { fn:QName($NS, "key") } { $wkSheetKey },
              element { fn:QName($NS, "dimension") }
              {
                element { fn:QName($NS, "topLeft") } { fn:tokenize($dim, ":") [1] },
                element { fn:QName($NS, "bottomRight") } { fn:tokenize($dim, ":") [2] }
              },
              element { fn:QName($NS, "sheetData") }
              {
                for $cell in $relWkSheet/*:worksheet/*:sheetData/*:row
                  let $row  := xs:string($cell/@r)
                  for $column in $cell/ssml:c
                    let $pos   := xs:string($column/@r)
                    let $col   := fn:substring($pos, 1, 1)  (: fix this :)
                    let $ref   := xs:string($column/@t)
                    let $value := xs:string($column/*:v)
                    let $val   := if ($ref eq "s") then $sharedStrings[xs:integer($value) + 1] else $value
                    let $type  := if ($ref eq "s") then "string" else "integer"
                    return
                      element { fn:QName($NS, "cell") }
                      {
                        element { fn:QName($NS, "col") }   { $col },
                        element { fn:QName($NS, "row") }   { $row },
                        element { fn:QName($NS, "pos") }   { $pos },
                        element { fn:QName($NS, "dtype") } { $type },
                        element { fn:QName($NS, "val") }   { $val }
                      }
              }
            }
    }
    
  let $doc :=
    element { fn:QName($NS, "workbook") }
    {
      element { fn:QName($NS, "meta") }
      {
        element { fn:QName($NS, "type") }      { "workbook" },
        element { fn:QName($NS, "user") }      { $user },
        element { fn:QName($NS, "client") }    { "Thomson Reuters" },
        element { fn:QName($NS, "creator") }   { map:get($table, "docProps/core.xml")/*:coreProperties/*:creator/text() },
        element { fn:QName($NS, "file") }      { local:generateFileUri($user, $zipFile) },
        element { fn:QName($NS, "lastModifiedBy") } { map:get($table, "docProps/core.xml")/*:coreProperties/*:lastModifiedBy/text() },
        element { fn:QName($NS, "created") }   { map:get($table, "docProps/core.xml")/*:coreProperties/*:created/text() },
        element { fn:QName($NS, "modified") }  { map:get($table, "docProps/core.xml")/*:coreProperties/*:modified/text() }
      },
      element { fn:QName($NS, "feed") }
      {
        element { fn:QName($NS, "definedNames") }
        {
          for $dn in $defnames
            let $att    := xs:string($dn/@name)
            let $sheet  := fn:tokenize($dn/text(), "!") [1]
            let $cell   := fn:tokenize($dn/text(), "!") [2]
            let $pos    := fn:replace($cell, "\$", "")
            let $col    := fn:tokenize($pos, "[0-9]") [1]
            let $row    := fn:tokenize($pos, "[A-Za-z]+") [2]
            let $lblCol := $col
            let $val    := local:getValue($row, $col, $sheet, $table, $rels, $wkBook, $sharedStrings)
            let $label  := local:findLabel($row, $col, $sheet, $table, $rels, $wkBook, $sharedStrings)
              return
                element { fn:QName($NS, "definedName") }
                {
                  element { fn:QName($NS, "dname") }  { $att },
                  element { fn:QName($NS, "dlabel") } { $label },
                  element { fn:QName($NS, "sheet") }  { $sheet },
                  element { fn:QName($NS, "col") }    { $col },
                  element { fn:QName($NS, "row") }    { $row },
                  element { fn:QName($NS, "pos") }    { $pos },
                  element { fn:QName($NS, "dvalue") } { $val }
                }
        },
        $workSheets
      }
    }

  return $doc
};

let $userDir := "/tmp/users/sandraday/"
let $user    := fn:tokenize($userDir, "/")[fn:last()-1]

let $zipFileList := local:loadDirectory($userDir)

let $docs :=
  for $zipFile in $zipFileList[1 to 1]
    let $doc     := local:extractSpreadsheetData($user, $zipFile)
    let $dir     := "/user/"||$user||"/"
    let $uri     := $dir||xdmp:hash64($doc)||".xml"
    let $fileUri := local:generateFileUri($user, $zipFile)
    let $binDoc  := xdmp:document-get($zipFile)
      return
      (
        $uri, $fileUri, $doc
      (:
        xdmp:document-insert($uri, $doc, xdmp:default-permissions(), ("spreadsheet")),
        xdmp:document-insert($fileUri, $binDoc, xdmp:default-permissions(), ("binary"))
      :)
      )

return $docs
