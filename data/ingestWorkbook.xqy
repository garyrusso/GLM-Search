declare namespace zip  = "xdmp:zip";
declare namespace ssml = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

declare variable $NS := "http://tax.thomsonreuters.com";
declare variable $OPTIONS as element () :=
                 <options xmlns="xdmp:zip-get">
                   <format>xml</format>
                 </options>;

(:~
 : Get Value from Defined Name
 :
 : @param $cell
 : @param $doc
 :)
declare function local:getValue($cell as xs:string, $sheetName as xs:string, $table, $rels, $wkBook)
{
  let $wkSheetKey := "xl/"||xs:string($rels/*:Relationship[@Id=$wkBook[@name=$sheetName]/@*:id]/@Target)

  let $relWkSheet := map:get($table, $wkSheetKey)
  let $value      := $relWkSheet/*:worksheet/*:sheetData/*:row/*:c[@r=$cell]/*:v/text()

  return $value
};

let $zipfile  := "/tmp/Book1.xlsx"
let $zipfile2 := "/tmp/AMC_TB_Upload_Batch_Processing.xlsm"
let $doc      := xdmp:document-get($zipfile)

let $binFile := fn:tokenize($zipfile, "/")[fn:last()]
let $dir     := "/user/grusso/"||fn:lower-case(fn:tokenize($binFile, "\.")[1])||"/"
let $fileUri := $dir||"files/"||$binFile

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
  for $x in xdmp:zip-manifest($doc)//zip:part/text()
    where (($x = $exclude) eq fn:false())
    return
      map:put($table, $x, xdmp:zip-get($doc, $x, $OPTIONS))

let $defnames  := map:get($table, "xl/workbook.xml")/*:workbook/*:definedNames/node()

let $wkBook := map:get($table, "xl/workbook.xml")/*:workbook/*:sheets/*:sheet
let $rels   := map:get($table, "xl/_rels/workbook.xml.rels")/*:Relationships
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
                  let $pos2  := xdmp:path($column)
                  return
                    element { fn:QName($NS, "cell") }
                    {
                      element { fn:QName($NS, "col") }   { $col },
                      element { fn:QName($NS, "row") }   { $row },
                      element { fn:QName($NS, "pos") }   { $pos },
                      element { fn:QName($NS, "type") }  { $type },
                      element { fn:QName($NS, "val") }   { $val }
                    }
            }
          }
  }

let $doc1 :=
  element { fn:QName($NS, "workbook") }
  {
    element { fn:QName($NS, "meta") }
    {
      element { fn:QName($NS, "type") }      { "workbook" },
      element { fn:QName($NS, "user") }      { "grusso" },
      element { fn:QName($NS, "client") }    { "Thomson Reuters" },
      element { fn:QName($NS, "creator") }   { map:get($table, "docProps/core.xml")/*:coreProperties/*:creator/text() },
      element { fn:QName($NS, "file") }      { $fileUri },
      element { fn:QName($NS, "lastModifiedBy") } { map:get($table, "docProps/core.xml")/*:coreProperties/*:lastModifiedBy/text() },
      element { fn:QName($NS, "created") }   { map:get($table, "docProps/core.xml")/*:coreProperties/*:created/text() },
      element { fn:QName($NS, "modified") }  { map:get($table, "docProps/core.xml")/*:coreProperties/*:modified/text() }
    },
    element { fn:QName($NS, "feed") }
    {
      element { fn:QName($NS, "definedNames") }
      {
        for $dn in $defnames
          let $att := xs:string($dn/@name)
          let $sheet := fn:tokenize($dn/text(), "!") [1]
          let $cell  := fn:tokenize($dn/text(), "!") [2]
          let $pos   := fn:replace($cell, "\$", "")
          let $col   := fn:tokenize($pos, "[0-9]") [1]
          let $row   := fn:tokenize($pos, "[A-Za-z]+") [2]
          let $val   := local:getValue($pos, $sheet, $table, $rels, $wkBook)
          return
          element { fn:QName($NS, "definedName") }
          {
            element { fn:QName($NS, "dname") } { $att },
            element { fn:QName($NS, "sheet") } { $sheet },
            element { fn:QName($NS, "col") }   { $col },
            element { fn:QName($NS, "row") }   { $row },
            element { fn:QName($NS, "pos") }   { $pos },
            element { fn:QName($NS, "value") } { $val }
          }
      },
      $workSheets
    }
  }

let $uri := $dir||xdmp:hash64($doc1)||".xml"
let $cell  := "C4"

return
(
(:
  for $dn1 in $doc1/*:feed/*:definedNames/*:definedName return $dn1/*:dname/text()||" | "||$dn1/*:sheet/text(),
  for $dn2 in $doc1/*:feed/*:definedNames/*:definedName
    return
      local:getValue($cell, $dn2/*:sheet/text(), $table, $rels, $wkBook),
  $wkBook[1],
  $wkBook[1]/@name,
  $rels,
  $doc1
:)
  xdmp:document-insert($uri, $doc1, xdmp:default-permissions(), ("spreadsheet")),
  xdmp:document-insert($fileUri, $doc, xdmp:default-permissions(), ("spreadsheet"))
)
