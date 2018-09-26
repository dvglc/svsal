xquery version "3.1";

(:~ 
 : RDF XQuery-Module
 : This module contains rdf functions:
 : At the moment, it only reports if rdf has been generated for a given work.
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
 :)
module namespace rdf                = "http://salamanca.school/ns/rdf";

declare namespace sal               = "http://salamanca.school/ns/sal";
declare namespace tei               = "http://www.tei-c.org/ns/1.0";
declare namespace templates         = "http://exist-db.org/xquery/templates";
import module namespace console     = "http://exist-db.org/xquery/console";
import module namespace functx      = "http://www.functx.com";
import module namespace http        = "http://expath.org/ns/http-client";
import module namespace httpclient  = "http://exist-db.org/xquery/httpclient";
import module namespace i18n        = "http://exist-db.org/xquery/i18n";
import module namespace util        = "http://exist-db.org/xquery/util";
import module namespace xmldb       = "http://exist-db.org/xquery/xmldb";
import module namespace app         = "http://salamanca.school/ns/app"     at "app.xql";
import module namespace config      = "http://salamanca.school/ns/config"  at "config.xqm";
import module namespace render      = "http://salamanca.school/ns/render"  at "render.xql";

declare
function rdf:needsRDF($targetWorkId as xs:string) as xs:boolean {
    let $targetSubcollection := for $subcollection in $config:tei-sub-roots return 
                                    if (doc-available(concat($subcollection, '/', $targetWorkId, '.xml'))) then $subcollection
                                    else ()
    let $targetWorkModTime := xmldb:last-modified($targetSubcollection, $targetWorkId || '.xml')

    return if (doc-available($config:rdf-root || '/' || $targetWorkId || '.rdf')) then
                let $rdfModTime := xmldb:last-modified($config:rdf-root, $targetWorkId || '.rdf')
                return if ($rdfModTime lt $targetWorkModTime) then true() else false()
        else
            true()
};

declare
function rdf:needsRDFString($node as node(), $model as map(*)) {
    let $currentWorkId := max((string($model('currentWork')/@xml:id), string($model('currentAuthor')/@xml:id), string($model('currentLemma')/@xml:id), string($model('currentWp')/@xml:id)))
    let $targetSubcollection := for $subcollection in $config:tei-sub-roots return 
                                    if (doc-available(concat($subcollection, '/', $currentWorkId, '.xml'))) then $subcollection
                                    else ()
    return if (rdf:needsRDF($currentWorkId)) then
                    <td title="{concat(if (doc-available($config:rdf-root || '/' || $currentWorkId || '.rdf')) then concat('RDF created on: ', string(xmldb:last-modified($config:rdf-root, $currentWorkId || '.rdf')), ', ') else (), 'Source from: ', string(xmldb:last-modified($targetSubcollection, $currentWorkId || '.xml')), '.')}"><a href="rdf-admin.xql?resourceId={$currentWorkId}"><b>Create RDF NOW!</b></a></td>
            else
                    <td title="{concat('RDF created on: ', string(xmldb:last-modified($config:rdf-root, $currentWorkId || '.rdf')), ', Source from: ', string(xmldb:last-modified($targetSubcollection, $currentWorkId || '.xml')), '.')}">Creating RDF unnecessary. <small><a href="rdf-admin.xql?resourceId={$currentWorkId}">Create RDF anyway!</a></small></td>
};
