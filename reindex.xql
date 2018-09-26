xquery version "3.1";


(:~ 
 : Reindex XQuery executable
 : This file reindexes the database.
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

declare         namespace   exist   = "http://exist.sourceforge.net/NS/exist";
declare         namespace   util    = "http://exist-db.org/xquery/util";
declare         namespace   xmldb   = "http://exist-db.org/xquery/xmldb";
import module   namespace   config  = "http://salamanca.school/ns/config"   at "modules/config.xqm";

declare         option      exist:serialize "method=xhtml media-type=text/html indent=yes";

let $data-collection := ($config:data-root,
                         $config:app-root || '/temp/cache',
                         $config:app-root || '/services/lod/temp/cache',
                         $config:salamanca-data-root)

(: let $login := xmldb:login($config:app-root, $cred:adminUsername, $cred:adminPassword) :)

let $start-time := util:system-time()
let $reindex := for $coll in $data-collection
                    return xmldb:reindex($coll)
let $runtime := ((util:system-time() - $start-time)
                        div xs:dayTimeDuration('PT1S')) (:  * 1000 :) 

return
<html>
    <head>
       <title>Reindex</title>
    </head>
    <body>
    <h1>Reindex</h1>
    <p>The index for {$data-collection} was updated in 
                 {$runtime} seconds.</p>
    <a href="index.html">svsal Home</a>
    </body>
</html>
