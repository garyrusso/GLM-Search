declare namespace zip     = "xdmp:zip";
declare namespace ssml    = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
declare namespace rel     = "http://schemas.openxmlformats.org/package/2006/relationships";
declare namespace wbrel   = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
declare namespace wsheet  = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet";
declare namespace core    = "http://schemas.openxmlformats.org/package/2006/metadata/core-properties";
declare namespace dcterms = "http://purl.org/dc/terms/";
declare namespace dc      = "http://purl.org/dc/elements/1.1/";

declare namespace tax    = "http://tax.thomsonreuters.com";

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
declare function local:getValue($row as xs:string, $col as xs:string, $sheetName as xs:string, $table as map:map)
{
  let $wkBook        := map:get($table, "xl/workbook.xml")/ssml:workbook/ssml:sheets/ssml:sheet
  let $rels          := map:get($table, "xl/_rels/workbook.xml.rels")/rel:Relationships
  let $sharedStrings := map:get($table, "xl/sharedStrings.xml")/ssml:sst/ssml:si/ssml:t/text()

  let $wkSheetKey := "xl/"||xs:string($rels/rel:Relationship[@Id=$wkBook[@name=$sheetName]/@wbrel:id]/@Target)

  let $wkSheet := map:get($table, $wkSheetKey)
  let $item     := $wkSheet/ssml:worksheet/ssml:sheetData/ssml:row[@r=$row]/ssml:c[@r=$col||$row]

  let $ref     := $item/@t
  let $value   := xs:string($item/ssml:v)

  let $retVal  := if ($ref eq "s") then $sharedStrings[xs:integer($value) + 1] else $value

  return $retVal
};

(:~
 : Entry point to a recursive function.
 :
 : @param $row
 :)
declare function local:findLabel($row as xs:string, $col as xs:string, $sheetName as xs:string, $table as map:map) as xs:string*
{
  let $leftLabelVal := local:getLabelValue($row, $col, $sheetName, $table)

  return $leftLabelVal
};

declare function local:getLabelValue($row as xs:string, $col as xs:string, $sheetName as xs:string, $table)
{
  let $pattern  := "[a-zA-Z]"

  let $leftCell := local:getLeftCell($col)

  return
    if (fn:matches(local:getValue($row, $leftCell, $sheetName, $table), $pattern) or
        (fn:string-to-codepoints($leftCell) lt 66)) then
      local:getValue($row, $leftCell, $sheetName, $table)
    else
      local:getLabelValue($row, $leftCell, $sheetName, $table)
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

  let $defnames      := map:get($table, "xl/workbook.xml")/ssml:workbook/ssml:definedNames/node()
  let $wkBook        := map:get($table, "xl/workbook.xml")/ssml:workbook/ssml:sheets/ssml:sheet
  let $rels          := map:get($table, "xl/_rels/workbook.xml.rels")/rel:Relationships
  let $sharedStrings := map:get($table, "xl/sharedStrings.xml")/ssml:sst/ssml:si/ssml:t/text()

  let $workSheets :=
    element { fn:QName($NS, "worksheets") }
    {
      for $ws in $wkBook
        let $wkSheetKey := "xl/"||xs:string($rels/rel:Relationship[@Id=$ws/@wbrel:id/fn:string()]/@Target)
        let $relWkSheet := map:get($table, $wkSheetKey)
        let $dim := $relWkSheet/ssml:worksheet/ssml:dimension/@ref/fn:string()
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
                for $cell in $relWkSheet/ssml:worksheet/ssml:sheetData/ssml:row
                  let $row  := xs:string($cell/@r)
                  for $column in $cell/ssml:c
                    let $pos   := xs:string($column/@r)
                    let $col   := fn:substring($pos, 1, 1)  (: fix this :)
                    let $ref   := xs:string($column/@t)
                    let $value := xs:string($column/ssml:v)
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

  let $defNamePass1Doc :=
        element { fn:QName($NS, "definedNames") }
        {
          for $dn in $defnames
            let $att    := xs:string($dn/@name)
            let $sheet  := fn:tokenize($dn/text(), "!") [1]
            let $cell   := fn:tokenize($dn/text(), "!") [2]
            let $pos    := fn:replace($cell, "\$", "")
            
            let $pos1   := fn:tokenize($pos, ":") [1]
            let $pos2   := fn:tokenize($pos, ":") [2]
            
            let $col    := fn:tokenize($pos1, "[0-9]") [1]
            let $row    := fn:tokenize($pos1, "[A-Za-z]+") [2]
            
            let $expand :=
              if (fn:empty($pos2)) then
                ()
              else
              (
                let $row2 := fn:tokenize($pos2, "[A-Za-z]+") [2]
                return
                (
                  element { fn:QName($NS, "col") } { $col },
                  element { fn:QName($NS, "row1") } { xs:integer($row) + 1 },
                  element { fn:QName($NS, "row2") } { $row2 }
                )
              )
            
            let $lblCol := $col
            let $val    := local:getValue($row, $col, $sheet, $table)
            let $label  := local:findLabel($row, $col, $sheet, $table)
              return
                element { fn:QName($NS, "definedName") }
                {
                  element { fn:QName($NS, "expand") }  { $expand },
                  element { fn:QName($NS, "dname") }  { $att },
                  element { fn:QName($NS, "dlabel") } { $label },
                  element { fn:QName($NS, "sheet") }  { $sheet },
                  element { fn:QName($NS, "col") }    { $col },
                  element { fn:QName($NS, "row") }    { $row },
                  element { fn:QName($NS, "pos") }    { $pos1 },
                  element { fn:QName($NS, "dvalue") } { $val }
                }
        }

  let $dnExpansionDoc :=
    element { fn:QName($NS, "definedNames") }
    {
      for $dn in $defNamePass1Doc/tax:definedName
        for $newRow in (xs:integer($dn/tax:expand/tax:row1/text()) to xs:integer($dn/tax:expand/tax:row2/text()))
          let $newPos    := $dn/tax:col/text()||$newRow
          let $sheetName := $dn/tax:sheet/text()
          let $col       := $dn/tax:col/text()
          let $dname     := $dn/tax:dname/text()
          let $newLabel  := local:findLabel(xs:string($newRow), $col, $sheetName, $table)
          let $newValue  := local:getValue(xs:string($newRow), $col, $sheetName, $table)
            return
            (
              element { fn:QName($NS, "definedName") }
              {
                element { fn:QName($NS, "dname") }  { $dname },
                element { fn:QName($NS, "dlabel") } { $newLabel },
                element { fn:QName($NS, "sheet") }  { $sheetName },
                element { fn:QName($NS, "col") }    { $col },
                element { fn:QName($NS, "row") }    { $newRow },
                element { fn:QName($NS, "pos") }    { $newPos },
                element { fn:QName($NS, "dvalue") } { $newValue }
              }
            )
    }
  
  let $unSortedDoc :=
      element { fn:QName($NS, "definedNames") }
      {
        $dnExpansionDoc/node(),
        for $d in $defNamePass1Doc/tax:definedName
          return
            element { fn:QName($NS, "definedName") }
            {
                element { fn:QName($NS, "dname") }  { $d/tax:dname/text() },
                element { fn:QName($NS, "dlabel") } { $d/tax:dlabel/text() },
                element { fn:QName($NS, "sheet") }  { $d/tax:sheet/text() },
                element { fn:QName($NS, "col") }    { $d/tax:col/text() },
                element { fn:QName($NS, "row") }    { $d/tax:row/text() },
                element { fn:QName($NS, "pos") }    { $d/tax:pos/text() },
                element { fn:QName($NS, "dvalue") } { $d/tax:dvalue/text() }
            }
      }
  
  let $newDefNameDoc :=
      element { fn:QName($NS, "definedNames") }
      {
        for $i in $unSortedDoc/tax:definedName
          let $row   := xs:integer($i/tax:row/text())
          let $seq   :=
            if ($row lt 10) then
              $i/tax:col/text()||"0"||$i/tax:row/text()
            else
              $i/tax:pos/text()
          let $dname := $i/tax:dname/text()
          order by $seq, $dname
            return $i
      }

  let $doc :=
    element { fn:QName($NS, "workbook") }
    {
      element { fn:QName($NS, "meta") }
      {
        element { fn:QName($NS, "type") }      { "workbook" },
        element { fn:QName($NS, "user") }      { $user },
        element { fn:QName($NS, "client") }    { "Thomson Reuters" },
        element { fn:QName($NS, "creator") }   { map:get($table, "docProps/core.xml")/core:coreProperties/dc:creator/text() },
        element { fn:QName($NS, "file") }      { local:generateFileUri($user, $zipFile) },
        element { fn:QName($NS, "lastModifiedBy") } { map:get($table, "docProps/core.xml")/core:coreProperties/core:lastModifiedBy/text() },
        element { fn:QName($NS, "created") }   { map:get($table, "docProps/core.xml")/core:coreProperties/dcterms:created/text() },
        element { fn:QName($NS, "modified") }  { map:get($table, "docProps/core.xml")/core:coreProperties/dcterms:modified/text() }
      },
      element { fn:QName($NS, "feed") }
      {
        $newDefNameDoc,
        $workSheets
      }
    }

  return $doc
};

let $userDir := "/tmp/users/gracehopper/"
let $user    := fn:tokenize($userDir, "/")[fn:last()-1]

let $zipFileList := local:loadDirectory($userDir)

let $docs :=
  for $zipFile in $zipFileList
    let $doc     := local:extractSpreadsheetData($user, $zipFile)
    let $dir     := "/user/"||$user||"/"
    let $uri     := $dir||xdmp:hash64($doc)||".xml"
    let $fileUri := local:generateFileUri($user, $zipFile)
    let $binDoc  := xdmp:document-get($zipFile)
      order by $zipFile
        return
        (
          $doc
        (:
          $doc/tax:feed/tax:worksheets/tax:worksheet
          $uri, $fileUri,
          fn:count($doc/tax:feed/tax:definedNames/tax:definedName),
          $doc
          xdmp:document-insert($uri, $doc, xdmp:default-permissions(), ("spreadsheet")),
          xdmp:document-insert($fileUri, $binDoc, xdmp:default-permissions(), ("binary"))
        :)
        )

return $docs
