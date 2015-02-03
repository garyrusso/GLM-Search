xquery version "1.0-ml";

module namespace tr = "http://marklogic.com/rest-api/resource/customerFlexFields";

declare namespace tax  = "http://tax.thomsonreuters.com";
declare namespace roxy = "http://marklogic.com/roxy";

declare variable $NS      := "http://tax.thomsonreuters.com";
declare variable $pathIdx := "/tax:origin/tax:feed/tax:customer//*";

(:
 :)
declare function tr:getElementNames() as node()*
{
  let $values  := cts:values(cts:path-reference($pathIdx))
  
  let $query :=
      cts:and-query((
        cts:word-query($values)
      ))
  
  let $results := cts:search(/tax:origin/tax:feed/tax:customer, $query)
  let $fields  := xs:string($results[1 to 100]//fn:node-name(.))
  let $list    := fn:distinct-values($fields)
  
  let $orderedList :=
    for $item in $list
      where $item ne "customer"
        order by $item
          return $item
  
  let $response :=
    element { "response" }
    {
      element { "input" }
      {
        element { "field" }          { "no field specified" }
      },
      element { "elapsedTime" }      { xdmp:elapsed-time() },
      element { "uniqueValueCount" } { fn:count($orderedList) },
      element { "values" }
      {
        for $val in $orderedList
          return
            element { "value" } { $val }
      }
    }

  return $response
};

(:
 :)
declare function tr:getFieldValues($field as xs:string) as node()*
{
  let $query :=
    cts:and-query((
      cts:element-query(
        fn:QName($NS, $field), cts:and-query(())
      )
    ))
  
  let $results     := cts:search(/tax:origin/tax:feed/tax:customer, $query)
  let $fieldValues := xs:string($results//*[fn:string(fn:node-name(.)) = $field]/text())
  
  let $list        := fn:distinct-values($fieldValues)
  let $orderedList := for $item in $list order by $item return $item

  let $response :=
    element { "response" }
    {
      element { "input" }
      {
        element { "field" }          { $field }
      },
      element { "elapsedTime" }      { xdmp:elapsed-time() },
      element { "valueCount" }       { fn:count($fieldValues) },
      element { "uniqueValueCount" } { fn:count($orderedList) },
      element { "values" }
      {
        for $val in $orderedList
          return
            element { "value" } { $val }
      }
    }

  return $response
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
  let $q     := map:get($params, "q")
  let $field := map:get($params, "field")
  
  let $doc   :=
    if (fn:empty($field)) then
      tr:getElementNames()
    else
      tr:getFieldValues($field)
      
  return
    document
    {
      $doc
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
  document { "PUT called on the ext service extension" }
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
  document { "POST called on the ext service extension" }
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
