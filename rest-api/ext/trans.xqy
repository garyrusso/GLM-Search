xquery version "1.0-ml";

module namespace tr = "http://marklogic.com/rest-api/resource/trans";

declare namespace roxy = "http://marklogic.com/roxy";

declare namespace tax = "http://tax.thomsonreuters.com";

declare variable $NS := "http://tax.thomsonreuters.com";

declare variable $CONTENT-DIR := "/glmtest/";

declare variable $TIDY-OPTIONS as element () :=
                 <options xmlns="xdmp:tidy">
                   <input-xml>yes</input-xml>
                 </options>;

(:~
 : Centralized Logging
 :
 : @param $file
 : @param $message
 :)
declare function tr:log($file as xs:string, $level as xs:string, $message as xs:string)
{
  let $idateTime := xs:string(fn:current-dateTime())
  let $dateTime  := fn:substring($idateTime, 1, fn:string-length($idateTime)-6)

  return
    xdmp:log(fn:concat("1......... LOGGING $file: ", $file, " | level: ", $level, " | message: ", $message, " | dateTime: ", $dateTime))
};

(: 
 : To add parameters to the functions, specify them in the params annotations. 
 : Example
 :   declare %roxy:params("uri=xs:string", "priority=xs:int") tr:get(...)
 : This means that the get function will take two parameters, a string and an int.
 :)

(:
 :)
declare 
%roxy:params("")
function tr:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),
  document { "GET called on the ext service extension" }
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
  let $output-types := map:put($context,"output-types","application/xml")

  let $doc :=  document { $input } (: xdmp:tidy(document { $input }, $TIDY-OPTIONS) [2] :)

  let $uri := fn:concat($CONTENT-DIR, xdmp:hash64($doc), xdmp:random(), ".xml")

  return
    if ($doc) then
      try
      {
        xdmp:document-insert($uri, $doc, xdmp:default-permissions(), ("glm")),
        document {
          <status>Success</status>
        }
      }
      catch ($e)
      {
        tr:log($uri, "ERROR", $e/error:message/text())
      }
      else
        document {
          <status>Input Error</status>
        }

(:
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
:)
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
