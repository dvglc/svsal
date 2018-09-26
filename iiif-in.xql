xquery version "3.1";

(:~ 
 : iiif-in XQuery executable
 : This file is the iiif input interface.
 :
 : For doc annotation format, see
 : - https://exist-db.org/exist/apps/doc/xqdoc
 :
 : For testing, see
 : - https://exist-db.org/exist/apps/doc/xqsuite
 : - https://en.wikibooks.org/wiki/XQuery/XUnit_Annotations
 :
 : @author Andreas Wagner
 : @author David Glück
 : @author Ingo Caesar
 : @version 1.0
 :
~:)

declare         namespace output    = "http://www.w3.org/2010/xslt-xquery-serialization";
declare         namespace request   = "http://exist-db.org/xquery/request";
declare         namespace response  = "http://exist-db.org/xquery/response";
import module   namespace console   = "http://exist-db.org/xquery/console";
import module   namespace config    = "http://salamanca.school/ns/config" at "modules/config.xqm";
import module   namespace iiif      = "http://salamanca.school/ns/iiif"   at "modules/iiif.xql";

declare option output:method "json";
declare option output:media-type "application/json";

let $facsDomain := $config:imageserver

let $canvasId           := request:get-parameter('canvasId', $facsDomain || '/iiif/presentation/W0015/canvas/p1')
let $header-addition    := response:set-header("Access-Control-Allow-Origin", "*")
let $debug              := if ($config:debug = ("trace", "info")) then console:log("iiif resolver running, requested canvasId '" || $canvasId || "'.") else ()

return iiif:getPageId($canvasId)
