xquery version "3.1";

(:~ 
 : Rdf-admin XQuery executable
 : This file calls rdf creation functions with admin/write privileges.
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

declare namespace output            = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace request           = "http://exist-db.org/xquery/request";
import module namespace console     = "http://exist-db.org/xquery/console";
import module namespace util        = "http://exist-db.org/xquery/util";
import module namespace admin       = "http://salamanca.school/ns/admin"           at "modules/admin.xql";
import module namespace config      = "http://salamanca.school/ns/config"          at "modules/config.xqm";

declare option output:media-type "application/rdf+xml";
declare option output:indent "yes";

let $start-time       := util:system-time()

let $resourceId    := request:get-parameter('resourceId', 'W0013')

let $rid :=     if (starts-with($resourceId, "authors.")) then
                        substring-after($resourceId, "authors.")
                    else if (starts-with($resourceId, "works.")) then
                        substring-after($resourceId, "works.")
                    else
                        $resourceId

let $debug := console:log("Requesting " || $config:apiserver || '/lod/extract.xql?format=rdf&amp;configuration=' || $config:apiserver || '/lod/createConfig.xql?resourceId=' || $rid || ' ...')

let $rdf   :=  doc($config:apiserver || '/lod/extract.xql?format=rdf&amp;configuration=' || $config:apiserver        || '/lod/createConfig.xql?resourceId=' || $rid)
(: let $debug := console:log("Resulting $rdf := " || $rdf || '.' ) :)

let $runtime-ms       := ((util:system-time() - $start-time) div xs:dayTimeDuration('PT1S'))  * 1000
let $runtimeString := if ($runtime-ms < (1000 * 60)) then format-number($runtime-ms div 1000, "#.##") || " Sek."
                      else if ($runtime-ms < (1000 * 60 * 60))  then format-number($runtime-ms div (1000 * 60), "#.##") || " Min."
                      else format-number($runtime-ms div (1000 * 60 * 60), "#.##") || " Std."

let $log := util:log('warn', 'Extracted RDF for ' || $resourceId || ' in ' || $runtimeString)

let $save := admin:saveFile($rid, $rid || '.rdf', $rdf, 'rdf')

return
    <output>
        <status>Extracted RDF in {$runtimeString} and saved at {$save}</status>
        <data>{$rdf}</data>
    </output>
