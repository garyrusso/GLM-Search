xquery version "1.0-ml";

module namespace tr = "http://marklogic.com/rest-api/resource/search";

import module namespace search = "http://marklogic.com/appservices/search"
    at "/MarkLogic/appservices/search/search.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

(: 
 : To add parameters to the functions, specify them in the params annotations. 
 : Example
 :   declare %roxy:params("uri=xs:string", "priority=xs:int") tr:get(...)
 : This means that the get function will take two parameters, a string and an int.
 :)

(:
 :)
declare 
%roxy:params("q=xs:string", "start=xs:int", "pageLength=xs:int")
function tr:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  let $q  := map:get($params, "q")
  let $pg := map:get($params, "start")
  let $ps := map:get($params, "pageLength")
  let $ft := map:get($params, "format")

  let $qtext      := if (fn:string-length($q) eq 0)  then "" else $q
  let $page       := if (fn:string-length($pg) eq 0) then  1 else $pg
  let $pageLength := if (fn:string-length($ps) eq 0) then 10 else $ps
  let $format     := if ($ft eq "json") then "json" else "xml"

  let $output-types :=
    if ($format eq "json") then
    (
      map:put($context,"output-types","application/json")
    )
    else
    (
      map:put($context,"output-types","application/xml")
    )

  let $options :=
      <options xmlns="http://marklogic.com/appservices/search">
        <start>{$page}</start>
        <page-length>{$pageLength}</page-length>
        <constraint name="Id">
          <word>
            <element ns="http://marklogic.com/xdmp/json/basic" name="Id"/>
          </word>
        </constraint>
        <constraint name="ImportedAccountCode">
          <word>
            <element ns="http://marklogic.com/xdmp/json/basic" name="ImportedAccountCode"/>
          </word>
        </constraint>
        <constraint name="ImportedUnitCode">
          <word>
            <element ns="http://marklogic.com/xdmp/json/basic" name="ImportedUnitCode"/>
          </word>
        </constraint>
      </options>

    let $results := search:search($qtext, $options)

  return
    document
    {
      $results
    }
};

(:
 :)
declare 
%roxy:params("quest=xs:string", "favorite-color=xs:string")
function tr:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "text/html"),
  xdmp:set-response-code(200, "OK"),
  document {
    <div>
      <div>
        <label>Quest</label>
        <span>{map:get($params, "quest")}</span>
      </div>
      <div>
        <label>Favorite Color</label>
        <span>{map:get($params, "favorite-color")}</span>
      </div>
    </div>
  }
};
