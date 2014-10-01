xquery version "1.0-ml";

module namespace tr = "http://marklogic.com/rest-api/resource/glmdemo";

import module namespace search = "http://marklogic.com/appservices/search"
    at "/MarkLogic/appservices/search/search.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare variable $DN := "http://marklogic.com/xdmp/json/basic";

(: 
 : To add parameters to the functions, specify them in the params annotations. 
 : Example
 :   declare %roxy:params("uri=xs:string", "priority=xs:int") tr:get(...)
 : This means that the get function will take two parameters, a string and an int.
 :)

(:
 :)
declare 
%roxy:params("q=xs:string")
function tr:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
(:
  let $options :=
    <options xmlns="http://marklogic.com/appservices/search">
      <constraint name="ImportedUnitCode">
        <word>
          <element ns="http://marklogic.com/xdmp/json/basic" name="ImportedUnitCode"/>
        </word>
      </constraint>
    </options>
:)
  let $arg1 := map:get($params,"q")
  let $content := 
        <args>
            {for $arg in $arg1
             return <arg1>{$arg1}</arg1>
            }
        </args>

(:
  let $results := search:search($q, $options)
:)

  (: $results/search:result//search:highlight/text(), $results :)

  return
  (
    map:put($context, "output-types", "application/xml"),
    xdmp:set-response-code(200, "OK"),
    document {
      $content
    }
  )
};

(:
 :)
declare 
%roxy:params("")
function tr:put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),
  document { "PUT called on the ext service extension" }
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

(:
 :)
declare 
%roxy:params("")
function tr:delete(
    $context as map:map,
    $params  as map:map
) as document-node()?
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),
  document { "DELETE called on the ext service extension" }
};
