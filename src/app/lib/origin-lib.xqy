xquery version "1.0-ml";

module namespace olib = "http://marklogic.com/roxy/lib/origin-lib";

import module namespace search = "http://marklogic.com/appservices/search" at "/MarkLogic/appservices/search/search.xqy";
import module namespace cfg    = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";

declare namespace cts    = "http://marklogic.com/cts";

declare option xdmp:mapping "false";

declare function olib:origin-snippet(
   $result as node(),
   $ctsquery as schema-element(cts:query),
   $options as element(search:transform-results)?
)
{
  let $default-snippet := search:snippet($result, $ctsquery, $options)
  return
    element
    { fn:QName(fn:namespace-uri($default-snippet), fn:name($default-snippet)) }
    { $default-snippet/@*,
      for $child in $default-snippet (: /node() :)
      return
        (: if ($child instance of element(search:match)) then :)
        element
        { fn:QName(fn:namespace-uri($child), fn:name($child)) }
        {
          $child/../@*,
          let $uri := fn:data($result/@uri)
          let $snipdoc := fn:doc($uri)
          return
            <table boder="1">
              <tr><td>node name 1</td><td>{fn:node-name($child)}</td></tr>
              <tr><td>node name 1</td><td>{fn:name($child/../..)}</td></tr>
              <tr><td>node name 1</td><td>{fn:name($child/../../..)}</td></tr>
              <tr><td width="145" valign="top">Id</td><td colspan="2" valign="top">{$snipdoc/*:origin/*:meta/*:id/text()}</td></tr>,
              <tr><td width="145" valign="top">Import File Id</td><td colspan="2" valign="top">{$snipdoc/*:origin/*:meta/*:importFileId/text()}</td></tr>,
              <tr><td width="145" valign="top">Imported Unit Code</td><td colspan="2" valign="top">{$snipdoc/*:origin/*:meta/*:importedUnitCode/text()}</td></tr>,
              <tr><td width="145" valign="top">Imported Account Code</td><td colspan="2" valign="top">{$snipdoc/*:origin/*:meta/*:importedAccountCode/text()}</td></tr>,
              <tr><td width="145" valign="top">Beginning Balance</td><td colspan="2" valign="top">{$snipdoc/*:origin/*:meta/*:beginningBalance/text()}</td></tr>,
              <tr><td width="145" valign="top">Ending Balance</td><td colspan="2" valign="top">{$snipdoc/*:origin/*:meta/*:endingBalance/text()}</td></tr>
            </table>
        }
        (:
        else
          $child
        :)
    }
};
