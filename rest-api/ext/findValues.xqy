xquery version "1.0-ml";

module namespace tr = "http://marklogic.com/rest-api/resource/findValues";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace tax = "http://tax.thomsonreuters.com";

declare variable $NS      := "http://tax.thomsonreuters.com";
declare variable $pathIdx := "/tax:origin/tax:feed/tax:price//*";

(:
 :)
declare function tr:getValuesWithDetailsWithinRange($min as xs:decimal, $max as xs:decimal) as node()*
{
  let $values  :=
    for $val in cts:values(cts:path-reference($pathIdx))
      where $val ge $min and $val le $max
        return
          $val

  let $valueStrings := xs:string($values)
  
  let $valuesDoc :=
    element { "valueItems" }
    {
      for $val in $valueStrings[1 to 20] (: Response shows first twenty items for now. Will add pagination parameters later. :)
      
        let $value := 
          if (fn:string-length(fn:tokenize($val, "\.")[2]) lt 2) then
            xs:string(fn:format-number(xs:decimal($val), "###0.00"))
          else
            $val
      
        let $results := cts:search(/tax:origin/tax:feed/tax:price, cts:word-query($value)) (: May need pagination here too. :)

        return
          element { "valueItem" }
          {
            (
              element { "value" } { $value },
              element { "count" } { fn:count($results) },
              element { "items" }
              {
                for $item in $results//*/text()
                  let $path  := xdmp:path($item/..)
                  let $itemToCompare := xs:decimal(fn:replace($item,",",""))
                    where $itemToCompare eq xs:decimal($value)
                      return
                        element { "item" }
                        {
                          element { "uri" }   { xdmp:node-uri($item) },
                          element { "path" }  { $path }
                        }
               }
            )
          }
    }

  let $response :=
    element { "response" }
    {
      element { "input" }
      {
        element { "min" }            { $min },
        element { "max" }            { $max },
        element { "notes" }          { "Returns first twenty items only. Will add pagination parameters to show unlimited items later." }
      },
      element { "elapsedTime" }      { xdmp:elapsed-time() },
      element { "uniqueValueCount" } { fn:count($values) },
      element { "values" }           { fn:string-join(xs:string($values), " ") },
      element { "sum" }              { fn:sum($values) },
      element { "avg" }              { fn:avg($values) },
      element { "min" }              { fn:min($values) },
      element { "max" }              { fn:max($values) },
      element { "stddev" }           { math:stddev($values) },
      $valuesDoc
    }

  return $response
};

declare function tr:getValuesWithinRangeForField($min as xs:decimal, $max as xs:decimal, $field as xs:string) as node()*
{
  let $values1  :=
    for $val in cts:values(cts:path-reference($pathIdx))
      where $val ge $min and $val le $max
        return
          $val
  
  let $valueStrings1 :=
    for $val in $values1
      let $num := fn:format-number($val, "###0.00")
        return
          xs:string($num)
  
  let $query   := cts:element-value-query(fn:QName($NS, $field), $valueStrings1)
  let $results := cts:search(/tax:origin/tax:feed/tax:price, $query)
  let $values  := xs:decimal($results//*[fn:local-name(.) = $field]/text())
  let $orderedList := for $val in $values order by $val return $val

  let $valuesDoc :=
    element { "items" }
    {
      element { "count" } { fn:count($results) },
      
      for $result in $results
      
        let $val := xs:decimal($result//*[fn:local-name(.) = $field]/text())
        
        order by $val
      
        return
          element { "item" }
          {
            (
              element { "value" } { $val },
              element { "uri" }   { xdmp:node-uri($result) }
            )
          }
    }

  let $response :=
    element { "response" }
    {
      element { "input" }
      {
        element { "field" }          { $field },
        element { "min" }            { $min },
        element { "max" }            { $max }
      },
      element { "elapsedTime" }      { xdmp:elapsed-time() },
      element { "uniqueValueCount" } { fn:count($values) },
      element { "values" }           { fn:string-join(xs:string($orderedList), " ") },
      element { "sum" }              { fn:sum($values) },
      element { "avg" }              { fn:avg($values) },
      element { "min" }              { fn:min($values) },
      element { "max" }              { fn:max($values) },
      element { "stddev" }           { math:stddev($values) },
      $valuesDoc
    }

  return $response
};

(:
 :)
declare function tr:getValuesWithinRange($min as xs:decimal, $max as xs:decimal) as node()*
{
  let $values  :=
    for $val in cts:values(cts:path-reference($pathIdx))
      where $val ge $min and $val le $max
        return
          $val
  
  let $response :=
    element { "response" }
    {
      element { "input" }
      {
        element { "min" }            { $min },
        element { "max" }            { $max }
      },
      element { "elapsedTime" }      { xdmp:elapsed-time() },
      element { "uniqueValueCount" } { fn:count($values) },
      element { "values" }           { fn:string-join(xs:string($values), " ") },
      element { "sum" }              { fn:sum($values) },
      element { "avg" }              { fn:avg($values) },
      element { "min" }              { fn:min($values) },
      element { "max" }              { fn:max($values) },
      element { "stddev" }           { math:stddev($values) }
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
  let $q          := map:get($params, "q")
  let $min        := xs:decimal(map:get($params, "min"))
  let $max        := xs:decimal(map:get($params, "max"))
  let $showDetail := map:get($params, "details")
  let $fieldName  := map:get($params, "field")

  let $field      :=
    if (fn:empty($fieldName)) then
      ()
    else
      $fieldName

  let $details    :=
    if (fn:empty($showDetail)) then
      fn:false()
    else
    if ($showDetail eq "true") then
      fn:true()
    else
      fn:false()

  let $doc     :=
    if (fn:string-length($fieldName) gt 0) then
      tr:getValuesWithinRangeForField($min, $max, $field)
    else
    if ($details eq fn:true()) then
      tr:getValuesWithDetailsWithinRange($min, $max)
    else
      tr:getValuesWithinRange($min, $max)
      
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
