xquery version "1.0-ml";

module namespace tr = "http://marklogic.com/rest-api/resource/transactions";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare variable $NS := "http://tax.thomsonreuters.com";

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
  let $output := map:put($context, "output-types", "application/xml")

  let $config    := admin:get-configuration()
  let $transList := xdmp:host-status(admin:get-host-ids($config)[1])/*:transactions/*:transaction

  let $ids :=
      element { fn:QName($NS, "txids") }
      {
        for $doc in $transList
          return
            element { fn:QName($NS, "txid") }
            {
              $doc/*:transaction-state/text()||": "||$doc/*:host-id/text()||"_"||$doc/*:transaction-id/text()
            }
      }

  return
    document
    {
      <status>{($ids, $transList)}</status>
    }
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
  document
  {
    <status>PUT called on the ext service extension</status>
  }
};

(:
 :)
declare 
%roxy:params("")
function tr:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),
  document
  {
    <status>POST called on the ext service extension</status>
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
  document
  {
    <status>DELETE called on the ext service extension</status>
  }
};
