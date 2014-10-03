xquery version "1.0-ml";

module namespace tr = "http://marklogic.com/rest-api/resource/trans";

declare namespace roxy = "http://marklogic.com/roxy";

declare namespace tax = "http://tax.thomsonreuters.com";

declare variable $NS := "http://tax.thomsonreuters.com";

declare variable $CONTENT-DIR := "/test/";

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
    xdmp:log(fn:concat("1..... LOGGING $file: ", $file, " | dateTime: ", $dateTime, " | level: ", $level, " | message: ", $message))
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
%roxy:params("uri=xs:string")
function tr:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  let $output-types := map:put($context,"output-types","application/xml")

  let $uri := map:get($params, "uri")
  let $doc := fn:doc($uri)

  return
    if (fn:empty($doc)) then
      document {
        <status>Document does not exist</status>
      }
    else
      document { $doc }
};

(:
 :)
declare 
%roxy:params("uri=xs:string", "document=payload")
function tr:put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
  let $output-types := map:put($context,"output-types","application/xml")

  let $newdoc :=  document { $input }

  let $uri := map:get($params, "uri")
  let $doc := fn:doc($uri)
  return
    if (fn:empty($doc)) then
      document {
        <status>Document does not exist</status>
      }
    else
    (
      if (fn:not(fn:empty($newdoc/node()))) then
        try
        {
          xdmp:document-insert($uri, $doc, xdmp:default-permissions(), ("RESTful")),
          tr:log($uri, "INFO", fn:concat("INFO: Document was updated: ", $uri)),
          document {
            <status>{fn:concat("Update Success: ", $uri)}</status>
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
    )
};

(:
 :)
declare
%roxy:params("document=payload")
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
    if (fn:not(fn:empty($doc/node()))) then
      try
      {
        xdmp:document-insert($uri, $doc, xdmp:default-permissions(), ("RESTful")),
        tr:log($uri, "INFO", fn:concat("INFO: New document added: ", $uri)),
        document {
          <status>{fn:concat("Create New Success: ", $uri)}</status>
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
};

(:
 :)
declare 
%roxy:params("uri=xs:string")
function tr:delete(
    $context as map:map,
    $params  as map:map
) as document-node()?
{
  let $output-types := map:put($context,"output-types","application/xml")

  let $uri := map:get($params, "uri")
  let $doc := fn:doc($uri)

  return
    if (fn:empty($doc)) then
      document {
        <status>Document does not exist</status>
      }
    else
      try
      {
        xdmp:document-delete($uri),
        tr:log($uri, "INFO", fn:concat("INFO: Document was deleted: ", $uri)),
        document {
          <status>{fn:concat("Delete Success: ", $uri)}</status>
        }
      }
      catch ($e)
      {
        tr:log($uri, "ERROR", $e/error:message/text())
      }
};
