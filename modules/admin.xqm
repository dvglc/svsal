xquery version "3.0";

(: ####++++---- 

    Admin functions, mostly related to the creation of webdata formats (html, iiif, snippets, etc.).
    Tightly coupled with modules in factory/*.

 ----++++#### :)
 
module namespace admin              = "http://www.salamanca.school/xquery/admin";
declare namespace exist             = "http://exist.sourceforge.net/NS/exist";
declare namespace tei               = "http://www.tei-c.org/ns/1.0";
declare namespace xi                = "http://www.w3.org/2001/XInclude";
declare namespace sal               = "http://salamanca.adwmainz.de";
declare namespace i18n              = 'http://exist-db.org/xquery/i18n';
import module namespace functx      = "http://www.functx.com";
import module namespace console     = "http://exist-db.org/xquery/console";
import module namespace templates   = "http://exist-db.org/xquery/templates";
import module namespace util        = "http://exist-db.org/xquery/util";
import module namespace xmldb       = "http://exist-db.org/xquery/xmldb";
import module namespace app         = "http://www.salamanca.school/xquery/app"                    at "xmldb:exist:///db/apps/salamanca/modules/app.xqm";
import module namespace config      = "http://www.salamanca.school/xquery/config"                 at "xmldb:exist:///db/apps/salamanca/modules/config.xqm";
import module namespace render-app  = "http://www.salamanca.school/xquery/render-app"         at "xmldb:exist:///db/apps/salamanca/modules/render-app.xqm";
import module namespace sphinx      = "http://www.salamanca.school/xquery/sphinx"                 at "xmldb:exist:///db/apps/salamanca/modules/sphinx.xqm";
import module namespace sutil       = "http://www.salamanca.school/xquery/sutil" at "xmldb:exist:///db/apps/salamanca/modules/sutil.xqm";
import module namespace stats       = "https://www.salamanca.school/factory/works/stats" at "xmldb:exist:///db/apps/salamanca/modules/factory/works/stats.xqm";
import module namespace index       = "https://www.salamanca.school/factory/works/index" at "xmldb:exist:///db/apps/salamanca/modules/factory/works/index.xqm";
import module namespace html        = "https://www.salamanca.school/factory/works/html" at "xmldb:exist:///db/apps/salamanca/modules/factory/works/html.xqm";
import module namespace txt         = "https://www.salamanca.school/factory/works/txt" at "xmldb:exist:///db/apps/salamanca/modules/factory/works/txt.xqm";
import module namespace iiif        = "https://www.salamanca.school/factory/works/iiif" at "xmldb:exist:///db/apps/salamanca/modules/factory/works/iiif.xqm";
declare namespace output            = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option exist:timeout "25000000"; (: ~7 h :)

(:
~ TODO: 
~    - HTML rendering and creation of snippets is currently not working for authors and lemmata, although 
~      the "ancient" infrastructure is still there (see renderTheRest.html and admin:renderAuthorLemma(), etc.).
~      Ideally, this infrastructure would be refactored in the way the creation of work data works: the webdata-admin.xql
~      forwards requests for the creation of data to the admin.xqm module, which then lets dedicated modules in factory/authors/* 
~      create the data.
:)



(: #### UTIL FUNCTIONS for informing the admin about current status of a webdata resources (node index, HTML, snippets, etc.) :)

declare function admin:needsIndex($targetWorkId as xs:string) as xs:boolean {
    let $workModTime := xmldb:last-modified($config:tei-works-root, $targetWorkId || '.xml')
    return
        if ($targetWorkId || "_nodeIndex.xml" = xmldb:get-child-resources($config:index-root)) then
            let $renderModTime := xmldb:last-modified($config:index-root, $targetWorkId || "_nodeIndex.xml")
            return if ($renderModTime lt $workModTime) then true() else false()
        else
            true()
};

declare function admin:needsIndexString($node as node(), $model as map(*)) {
    let $currentWorkId := $model('currentWork')?('wid')
    return 
        if (admin:needsIndex($currentWorkId)) then
            <td title="Source from: {string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml'))}{if (xmldb:get-child-resources($config:index-root) = $currentWorkId || "_nodeIndex.xml") then concat(', rendered on: ', xmldb:last-modified($config:index-root, $currentWorkId || "_nodeIndex.xml")) else ()}"><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=index"><b>Create Node Index NOW!</b></a></td>
        else
            <td title="Source from: {string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml'))}, rendered on: {xmldb:last-modified($config:index-root, $currentWorkId || "_nodeIndex.xml")}">Node indexing unnecessary. <small><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=index">Create Node Index anyway!</a></small></td>
};

declare function admin:needsTeiCorpusZip($node as node(), $model as map(*)) {
    let $worksModTime := max(for $work in xmldb:get-child-resources($config:tei-works-root) return xmldb:last-modified($config:tei-works-root, $work))    
    let $needsCorpusZip := 
        if (util:binary-doc-available($config:corpus-zip-root || '/sal-tei-corpus.zip')) then
            let $resourceModTime := xmldb:last-modified($config:corpus-zip-root, 'sal-tei-corpus.zip')
            return $resourceModTime lt $worksModTime
        else true()
    return 
        if ($needsCorpusZip) then
            <td title="Most current source from: {string($worksModTime)}"><a href="webdata-admin.xql?format=tei-corpus"><b>Create TEI corpus NOW!</b></a></td>
        else
            <td title="{concat('TEI corpus created on: ', string(xmldb:last-modified($config:corpus-zip-root, 'sal-tei-corpus.zip')), ', most current source from: ', string($worksModTime), '.')}">Creating TEI corpus unnecessary. <small><a href="webdata-admin.xql?format=tei-corpus">Create TEI corpus zip anyway!</a></small></td>
};

declare function admin:needsTxtCorpusZip($node as node(), $model as map(*)) {
    if (xmldb:collection-available($config:txt-root)) then
        let $worksModTime := max(for $work in xmldb:get-child-resources($config:txt-root) return xmldb:last-modified($config:txt-root, $work))    
        let $needsCorpusZip := 
            if (util:binary-doc-available($config:corpus-zip-root || '/sal-txt-corpus.zip')) then
                let $resourceModTime := xmldb:last-modified($config:corpus-zip-root, 'sal-txt-corpus.zip')
                return $resourceModTime lt $worksModTime
            else true()
        return 
            if ($needsCorpusZip) then
                <td title="Most current source from: {string($worksModTime)}"><a href="webdata-admin.xql?format=txt-corpus"><b>Create TXT corpus NOW!</b></a></td>
            else
                <td title="{concat('TXT corpus created on: ', string(xmldb:last-modified($config:corpus-zip-root, 'sal-txt-corpus.zip')), ', most current source from: ', string($worksModTime), '.')}">Creating TXT corpus unnecessary. <small><a href="webdata-admin.xql?format=txt-corpus">Create TXT corpus zip anyway!</a></small></td>
    else <td title="No txt sources available so far!"><a href="webdata-admin.xql?format=txt-corpus"><b>Create TXT corpus NOW!</b></a></td>
};

declare function admin:needsStats($node as node(), $model as map(*)) {
    let $worksModTime := max(for $work in xmldb:get-child-resources($config:tei-works-root) return xmldb:last-modified($config:tei-works-root, $work))    
    let $needsStats := 
        if (util:binary-doc-available($config:stats-root || '/stats.json')) then
            let $resourceModTime := xmldb:last-modified($config:stats-root, 'stats.json')
            return $resourceModTime lt $worksModTime
        else true()
    return 
        if ($needsStats) then
            <td title="Most current source from: {string($worksModTime)}"><a href="webdata-admin.xql?format=stats"><b>Create corpus stats NOW!</b></a></td>
        else
            <td title="{concat('Stats created on: ', string(xmldb:last-modified($config:stats-root, 'stats.json')), ', most current source from: ', string($worksModTime), '.')}">Creating corpus stats unnecessary. <small><a href="webdata-admin.xql?format=stats">Create corpus stats anyway!</a></small></td>
};

declare function admin:authorString($node as node(), $model as map(*), $lang as xs:string?) {
    let $currentAuthorId  := $model('currentAuthor')/@xml:id/string()
    return 
        <td><a href="author.html?aid={$currentAuthorId}">{$currentAuthorId} - {app:AUTname($node, $model)}</a></td>
};

declare function admin:authorMakeHTML($node as node(), $model as map(*)) {
    let $currentAuthorId := $model('currentAuthor')/@xml:id/string()
    return 
        if (admin:needsHTML($currentAuthorId)) then
            <td title="source from: {string(xmldb:last-modified($config:tei-authors-root, $currentAuthorId || '.xml'))}{if (xmldb:collection-available($config:temp) and xmldb:get-child-resources($config:temp) = $currentAuthorId || ".html") then concat(', rendered on: ', xmldb:last-modified($config:temp, $currentAuthorId || ".html")) else ()}"><a href="renderTheRest.html?aid={$currentAuthorId}"><b>Render NOW!</b></a></td>
        else
            <td title="source from: {string(xmldb:last-modified($config:tei-authors-root, $currentAuthorId || '.xml'))}, Rendered on: {xmldb:last-modified($config:temp, $currentAuthorId || '.html')}">Rendering unnecessary. <small><a href="renderTheRest.html?aid={$currentAuthorId}">Render anyway!</a></small></td>
};

declare function admin:lemmaString($node as node(), $model as map(*), $lang as xs:string?) {
    let $currentLemmaId  := string($model('currentLemma')/@xml:id)
    return <td><a href="lemma.html?lid={$currentLemmaId}">{$currentLemmaId} - {app:LEMtitle($node, $model)}</a></td>
};

declare function admin:lemmaMakeHTML($node as node(), $model as map(*)) {
    let $currentLemmaId := string($model('currentLemma')/@xml:id)
    return 
        if (admin:needsHTML($currentLemmaId)) then
            <td title="source from: {string(xmldb:last-modified($config:tei-lemmata-root, $currentLemmaId || '.xml'))}{if (xmldb:collection-available($config:temp) and xmldb:get-child-resources($config:temp) = $currentLemmaId || ".html") then concat(', rendered on: ', xmldb:last-modified($config:temp, $currentLemmaId || ".html")) else ()}"><a href="renderTheRest.html?lid={$currentLemmaId}"><b>Render NOW!</b></a></td>
        else
            <td title="source from: {string(xmldb:last-modified($config:tei-lemmata-root, $currentLemmaId || '.xml'))}, Rendered on: {xmldb:last-modified($config:temp, $currentLemmaId || ".html")}">Rendering unnecessary. <small><a href="renderTheRest.html?lid={$currentLemmaId}">Render anyway!</a></small></td>
};
           
declare function admin:WPString($node as node(), $model as map(*), $lang as xs:string?) {
    let $currentWPId  := string($model('currentWp')/@xml:id)
    return <td><a href="workingPaper.html?wpid={$currentWPId}">{$currentWPId} - {app:WPtitle($node, $model)}</a></td>
};

declare function admin:needsHTML($targetWorkId as xs:string) as xs:boolean {
    let $targetSubcollection := 
        for $subcollection in $config:tei-sub-roots return 
            if (doc-available(concat($subcollection, '/', $targetWorkId, '.xml'))) then $subcollection
            else ()
    let $workModTime := xmldb:last-modified($targetSubcollection, $targetWorkId || '.xml')
    return
        if (substring($targetWorkId,1,2) eq "W0") then
            if ($targetWorkId || "_nodeIndex.xml" = xmldb:get-child-resources($config:index-root)
                and xmldb:collection-available($config:html-root || '/' || $targetWorkId)) then
                let $indexModTime := xmldb:last-modified($config:index-root, $targetWorkId || "_nodeIndex.xml")
                let $htmlModTime := 
                    max(for $file in xmldb:get-child-resources($config:html-root || '/' || $targetWorkId) return 
                            xmldb:last-modified($config:html-root || '/' || $targetWorkId, $file))
                return if ($htmlModTime lt $workModTime or $htmlModTime lt $indexModTime) then true() else false()
            else
                true()
        else if (substring($targetWorkId,1,2) = ("A0", "L0", "WP")) then
            (: TODO: in the future, this should point to the directory where author/lemma/... HTML will be stored... :)
            if (not(xmldb:collection-available($config:data-root))) then
                true()
            else if ($targetWorkId || ".html" = xmldb:get-child-resources($config:data-root)) then
                let $renderModTime := xmldb:last-modified($config:data-root, $targetWorkId || ".html")
                return if ($renderModTime lt $workModTime) then true() else false()
            else true()
        else true()
};

declare function admin:needsHTMLString($node as node(), $model as map(*)) {
    let $currentWorkId := $model('currentWork')?('wid')
    return 
        if (admin:needsHTML($currentWorkId)) then
            <td title="Source from: {string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml'))}{if (xmldb:get-child-resources($config:index-root) = $currentWorkId || "_nodeIndex.xml") then concat(', rendered on: ', xmldb:last-modified($config:index-root, $currentWorkId || "_nodeIndex.xml")) else ()}"><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=html"><b>Render HTML (&amp; TXT) NOW!</b></a></td>
        else
            <td title="Source from: {string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml'))}, rendered on: {xmldb:last-modified($config:index-root, $currentWorkId || "_nodeIndex.xml")}">Rendering unnecessary. <small><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=html">Render HTML (&amp; TXT) anyway!</a></small></td>
};

declare function admin:workString($node as node(), $model as map(*), $lang as xs:string?) {
(:    let $debug := console:log(string($model('currentWork')/@xml:id)):)
    let $currentWorkId  := $model('currentWork')?('wid')
    let $author := <span>{$model('currentWork')?('author')}</span>
    let $titleShort := $model('currentWork')?('titleShort')
    return 
        <td>
            <a href="{$config:webserver}/en/work.html?wid={$currentWorkId}">{$currentWorkId}: {$author} - {$titleShort}</a>
            <br/>
            <a style="font-weight:bold;" href="{$config:webserver}/webdata-admin.xql?rid={$currentWorkId}&amp;format=all">Create EVERYTHING except IIIF (safest option)</a>
        </td>
};

declare function admin:needsSphinxSnippets($targetWorkId as xs:string) as xs:boolean {
    let $targetSubcollection := for $subcollection in $config:tei-sub-roots return 
                                    if (doc-available(concat($subcollection, '/', $targetWorkId, '.xml'))) then $subcollection
                                    else ()
    let $targetWorkModTime := xmldb:last-modified($targetSubcollection, $targetWorkId || '.xml')
(:    let $newestSnippet := max(for $file in xmldb:get-child-resources($config:snippets-root || '/' || $targetWorkId) return xmldb:last-modified($config:snippets-root || '/' || $targetWorkId, $file)):)

    return if (xmldb:collection-available($config:snippets-root || '/' || $targetWorkId)) then
                let $snippetsModTime := max(for $file in xmldb:get-child-resources($config:snippets-root || '/' || $targetWorkId) return xmldb:last-modified($config:snippets-root || '/' || $targetWorkId, $file))
                return 
                    if (starts-with(upper-case($targetWorkId), 'W0')) then
                        let $indexModTime := xmldb:last-modified($config:index-root, $targetWorkId || "_nodeIndex.xml")
                        return 
                            if ($snippetsModTime lt $targetWorkModTime or $snippetsModTime lt $indexModTime) then true() else false()
                    else if ($snippetsModTime lt $targetWorkModTime) then true() 
                    else false()
        else
            true()
};

declare function admin:needsSphinxSnippetsString($node as node(), $model as map(*)) {
    let $currentWorkId := max((string($model('currentWork')?('wid')), string($model('currentAuthor')/@xml:id), string($model('currentLemma')/@xml:id), string($model('currentWp')/@xml:id)))
    let $targetSubcollection := for $subcollection in $config:tei-sub-roots return 
                                    if (doc-available(concat($subcollection, '/', $currentWorkId, '.xml'))) then $subcollection
                                    else ()
    return if (admin:needsSphinxSnippets($currentWorkId)) then
                <td title="{concat(if (xmldb:collection-available($config:snippets-root || '/' || $currentWorkId)) then concat('Snippets created on: ', max(for $file in xmldb:get-child-resources($config:snippets-root || '/' || $currentWorkId) return string(xmldb:last-modified($config:snippets-root || '/' || $currentWorkId, $file))), ', ') else (), 'Source from: ', string(xmldb:last-modified($targetSubcollection, $currentWorkId || '.xml')), '.')}"><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=snippets"><b>Create snippets NOW!</b></a></td>
            else
                <td title="{concat('Snippets created on: ', max(for $file in xmldb:get-child-resources($config:snippets-root || '/' || $currentWorkId) return string(xmldb:last-modified($config:snippets-root || '/' || $currentWorkId, $file))), ', Source from: ', string(xmldb:last-modified($targetSubcollection, $currentWorkId || '.xml')), '.')}">Creating snippets unnecessary. <small><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=snippets">Create snippets anyway!</a></small></td>
};

declare function admin:needsRDF($targetWorkId as xs:string) as xs:boolean {
    let $targetSubcollection := 
        for $subcollection in $config:tei-sub-roots return 
            if (doc-available(concat($subcollection, '/', $targetWorkId, '.xml'))) then $subcollection
            else ()
    let $targetWorkModTime := xmldb:last-modified($targetSubcollection, $targetWorkId || '.xml')
    let $subcollection := 
        if (starts-with(upper-case($targetWorkId), 'W')) then $config:rdf-works-root
        else if (starts-with(upper-case($targetWorkId), 'A')) then $config:rdf-authors-root
        else if (starts-with(upper-case($targetWorkId), 'L')) then $config:rdf-lemmata-root
        else ()
    return    
        if (doc-available($subcollection || '/' || $targetWorkId || '.rdf')) then
            let $rdfModTime := xmldb:last-modified($subcollection, $targetWorkId || '.rdf')
            return 
                if (starts-with(upper-case($targetWorkId), 'W0')) then
                    let $indexModTime := xmldb:last-modified($config:index-root, $targetWorkId || "_nodeIndex.xml")
                    return 
                        if ($rdfModTime lt $targetWorkModTime or $rdfModTime lt $indexModTime) then true() else false()
                else if ($rdfModTime lt $targetWorkModTime) then true() 
                else false()
        else true()
};

declare function admin:needsRDFString($node as node(), $model as map(*)) {
    let $currentWorkId := max((string($model('currentWork')?('wid')), string($model('currentAuthor')/@xml:id), string($model('currentLemma')/@xml:id), string($model('currentWp')/@xml:id)))
    let $targetSubcollection := 
        for $subcollection in $config:tei-sub-roots return 
            if (doc-available(concat($subcollection, '/', $currentWorkId, '.xml'))) then $subcollection
            else ()
    let $rdfSubcollection := 
        if (starts-with(upper-case($currentWorkId), 'W')) then $config:rdf-works-root
        else if (starts-with(upper-case($currentWorkId), 'A')) then $config:rdf-authors-root
        else if (starts-with(upper-case($currentWorkId), 'L')) then $config:rdf-lemmata-root
        else ()
    return 
        if (admin:needsRDF($currentWorkId)) then
            <td title="{concat(if (doc-available($rdfSubcollection || '/' || $currentWorkId || '.rdf')) then concat('RDF created on: ', string(xmldb:last-modified($rdfSubcollection, $currentWorkId || '.rdf')), ', ') else (), 'Source from: ', string(xmldb:last-modified($targetSubcollection, $currentWorkId || '.xml')), '.')}"><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=rdf"><b>Create RDF NOW!</b></a></td>
        else
            <td title="{concat('RDF created on: ', string(xmldb:last-modified($rdfSubcollection, $currentWorkId || '.rdf')), ', Source from: ', string(xmldb:last-modified($targetSubcollection, $currentWorkId || '.xml')), '.')}">Creating RDF unnecessary. <small><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=rdf">Create RDF anyway!</a></small></td>
};

declare function admin:needsIIIFResource($targetWorkId as xs:string) as xs:boolean {
    let $targetWorkModTime := xmldb:last-modified($config:tei-works-root, $targetWorkId || '.xml')

    return if (util:binary-doc-available($config:iiif-root || '/' || $targetWorkId || '.json')) then
                let $resourceModTime := xmldb:last-modified($config:iiif-root, $targetWorkId || '.json')
                return if ($resourceModTime lt $targetWorkModTime) then true() else false()
        else
            true()
};

declare function admin:needsIIIFResourceString($node as node(), $model as map(*)) {
    let $currentWorkId := $model('currentWork')?('wid')
    return if (admin:needsIIIFResource($currentWorkId)) then
                <td title="source from: {string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml'))}"><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=iiif"><b>Create IIIF resource NOW!</b></a></td>
            else
                <td title="{concat('IIIF resource created on: ', string(xmldb:last-modified($config:iiif-root, $currentWorkId || '.json')), ', Source from: ', string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml')), '.')}">Creating IIIF resource unnecessary. <small><a href="webdata-admin.xql?rid={$currentWorkId}&amp;format=iiif">Create IIIF resource anyway!</a></small></td>
};


(: #### DATABASE UTIL FUNCTIONS #### :)

declare function admin:cleanCollection ($wid as xs:string, $collection as xs:string) {
    let $collectionName := 
        if ($collection = "html") then
            $config:html-root || "/" || $wid
        else if ($collection = "data") then
            $config:data-root || "/"
        else if ($collection = "snippets") then
            $config:snippets-root || "/" || $wid
        else if ($collection eq "txt") then
            $config:txt-root || "/" || $wid
        else
            $config:data-root || "/trash/"
    let $create-parent-status :=    
        if ($collection = "html"    and not(xmldb:collection-available($config:html-root))) then
            xmldb:create-collection($config:webdata-root, "html")
        else if ($collection = "txt"    and not(xmldb:collection-available($config:txt-root))) then
            xmldb:create-collection($config:webdata-root, "txt")
        else if ($collection = "snippets" and not(xmldb:collection-available($config:snippets-root))) then
            xmldb:create-collection($config:webdata-root, "snippets")
        else ()
    let $create-collection-status := 
        if ($collection = "html" and not(xmldb:collection-available($collectionName))) then
            xmldb:create-collection($config:html-root, $wid)
        else if ($collection = "txt" and not(xmldb:collection-available($collectionName))) then
            xmldb:create-collection($config:txt-root, $wid)
        else if ($collection = "snippets" and not(xmldb:collection-available($collectionName))) then
            xmldb:create-collection($config:snippets-root, $wid)
        else ()
    let $chown-collection-status := sm:chown(xs:anyURI($collectionName), 'sal')
    let $chgrp-collection-status := sm:chgrp(xs:anyURI($collectionName), 'svsal')
    let $chmod-collection-status := sm:chmod(xs:anyURI($collectionName), 'rwxrwxr-x')
    let $remove-status := 
        if (count(xmldb:get-child-resources($collectionName))) then
            for $file in xmldb:get-child-resources($collectionName) return xmldb:remove($collectionName, $file)
        else ()
    return $remove-status
};

declare function admin:saveFile($wid as xs:string, $fileName as xs:string, $content as item(), $collection as xs:string?) {
    let $collectionName := 
        if ($collection = "html") then
            $config:html-root || "/" || $wid
        else if ($collection eq 'index') then
            $config:index-root || "/"
        else if ($collection = "txt") then
            $config:txt-root || "/" || $wid
        else if ($collection = 'iiif') then
            $config:iiif-root || "/"
        else if ($collection = "data") then
            $config:data-root || "/"
        else if ($collection = 'stats') then
            $config:stats-root || "/"
        else if ($collection = "snippets") then
            $config:snippets-root || "/" || $wid
        else if ($collection = "rdf" and starts-with(upper-case($wid), 'W0')) then
            $config:rdf-works-root || "/"
        else if ($collection = "rdf" and starts-with(upper-case($wid), 'A0')) then
            $config:rdf-authors-root || "/"
        else if ($collection = "rdf" and starts-with(upper-case($wid), 'L0')) then
            $config:rdf-lemmata-root || "/"
        else
            $config:data-root || "/trash/"
    let $create-parent-status     :=      
        if ($collection = "html" and not(xmldb:collection-available($config:html-root))) then
            xmldb:create-collection($config:webdata-root, "html")
        else if ($collection = "txt" and not(xmldb:collection-available($config:txt-root))) then
            xmldb:create-collection($config:webdata-root, "txt")
        else if ($collection = "snippets" and not(xmldb:collection-available($config:snippets-root))) then
            xmldb:create-collection($config:webdata-root, "snippets")
        else if ($collection = "index" and not(xmldb:collection-available($config:index-root))) then
            xmldb:create-collection($config:webdata-root, "index")
        else if ($collection = "iiif" and not(xmldb:collection-available($config:iiif-root))) then
            xmldb:create-collection($config:webdata-root, "iiif")
        else if ($collection = "rdf" and not(xmldb:collection-available($config:rdf-root))) then
            xmldb:create-collection($config:webdata-root, "rdf")
        else if ($collection = "stats" and not(xmldb:collection-available($config:stats-root))) then
            xmldb:create-collection($config:webdata-root, "stats")
        (: TODO: rdf subroots (works/authors)? but these should already ship with the svsal-webdata package :)
        else ()
    let $create-collection-status :=      
        if ($collection = "html" and not(xmldb:collection-available($collectionName))) then
            xmldb:create-collection($config:html-root, $wid)
        else if ($collection = "txt" and not(xmldb:collection-available($collectionName))) then
            xmldb:create-collection($config:txt-root, $wid)
        else if ($collection = "snippets" and not(xmldb:collection-available($collectionName))) then
            xmldb:create-collection($config:snippets-root, $wid)
        else ()
    let $chown-collection-status := sm:chown(xs:anyURI($collectionName), 'sal')
    let $chgrp-collection-status := sm:chgrp(xs:anyURI($collectionName), 'svsal')
    let $chmod-collection-status := sm:chmod(xs:anyURI($collectionName), 'rwxrwxr-x')
    let $remove-status := 
        if ($content and ($fileName = xmldb:get-child-resources($collectionName))) then
            xmldb:remove($collectionName, $fileName)
        else ()
    let $store-status := 
        if ($content) then
            xmldb:store($collectionName, $fileName, $content)
        else ()
    return $store-status
};

declare function admin:saveFileWRK ($node as node(), $model as map (*), $lang as xs:string?) {
    let $debug := if ($config:debug = ("trace", "info")) then console:log("[ADMIN] Storing finalFacets...") else ()
    let $create-collection  :=  if (not(xmldb:collection-available($config:data-root))) then xmldb:create-collection($config:app-root, "data") else ()
    let $fileNameDe         :=  'works_de.xml'
    let $fileNameEn         :=  'works_en.xml'
    let $fileNameEs         :=  'works_es.xml'
    let $contentDe :=  
        <sal>
            {app:WRKfinalFacets($node, $model, 'de')}
        </sal>
    let $contentEn :=  
        <sal>
            {app:WRKfinalFacets($node, $model, 'en')}
        </sal>
    let $contentEs :=  
        <sal>
            {app:WRKfinalFacets($node, $model, 'es')}
        </sal> 
    let $store :=  (xmldb:store($config:data-root, $fileNameDe, $contentDe), xmldb:store($config:data-root, $fileNameEn, $contentEn), xmldb:store($config:data-root, $fileNameEs, $contentEs))
    return
        <span>
            <p><span class="glyphicon glyphicon-thumbs-up" aria-hidden="true"></span> List of works saved!</p>
            <br/><br/>
            <a href="works.html" class="btn btn-info" role="button"><span class="glyphicon glyphicon-thumbs-up" aria-hidden="true"></span> Open works.html</a>
        </span>   
};

declare function admin:saveFileWRKnoJs ($node as node(), $model as map (*), $lang as xs:string?) {
    let $debug := if ($config:debug = ("trace", "info")) then console:log("[ADMIN] Storing finalFacets (noJS)...") else ()
    let $create-collection  :=  
        if (not(xmldb:collection-available($config:data-root))) then 
            xmldb:create-collection(util:collection-name($config:data-root), $config:data-root) 
        else ()
    let $fileNameDeSn :=  'worksNoJs_de_surname.xml'
    let $fileNameEnSn :=  'worksNoJs_en_surname.xml'
    let $fileNameEsSn :=  'worksNoJs_es_surname.xml'
    let $contentDeSn :=  
        <sal>
            {app:WRKcreateListSurname($node, $model, 'de')}
        </sal>   
    let $contentEnSn :=  
        <sal>
            {app:WRKcreateListSurname($node, $model, 'en')}
        </sal>
    let $contentEsSn :=  
        <sal>
            {app:WRKcreateListSurname($node, $model, 'es')}
        </sal> 
    let $fileNameDeTi :=  'worksNoJs_de_title.xml'
    let $fileNameEnTi :=  'worksNoJs_en_title.xml'
    let $fileNameEsTi :=  'worksNoJs_es_title.xml'
    let $contentDeTi :=  
        <sal>
            {app:WRKcreateListTitle($node, $model, 'de')}
        </sal>   
    let $contentEnTi :=  
        <sal>
            {app:WRKcreateListTitle($node, $model, 'en')}
        </sal>
    let $contentEsTi := 
        <sal>
            {app:WRKcreateListTitle($node, $model, 'es')}
        </sal>                                
    let $fileNameDeYe :=  'worksNoJs_de_year.xml'
    let $fileNameEnYe :=  'worksNoJs_en_year.xml'
    let $fileNameEsYe :=  'worksNoJs_es_year.xml'
    let $contentDeYe :=  
        <sal>
            {app:WRKcreateListYear($node, $model, 'de')}
        </sal>   
    let $contentEnYe := 
        <sal>
            {app:WRKcreateListYear($node, $model, 'en')}
        </sal>
    let $contentEsYe := 
        <sal>
            {app:WRKcreateListYear($node, $model, 'es')}
        </sal>  
    let $fileNameDePl :=  'worksNoJs_de_place.xml'
    let $fileNameEnPl :=  'worksNoJs_en_place.xml'
    let $fileNameEsPl :=  'worksNoJs_es_place.xml'
    let $contentDePl :=  
        <sal>
            {app:WRKcreateListPlace($node, $model, 'de')}
        </sal>   
    let $contentEnPl :=  
        <sal>
            {app:WRKcreateListPlace($node, $model, 'en')}
        </sal>
    let $contentEsPl :=  
        <sal>
            {app:WRKcreateListPlace($node, $model, 'es')}
        </sal>
    let $store :=  
        (xmldb:store($config:data-root, $fileNameDeSn, $contentDeSn), xmldb:store($config:data-root, $fileNameEnSn, $contentEnSn), xmldb:store($config:data-root, $fileNameEsSn, $contentEsSn),
         xmldb:store($config:data-root, $fileNameDeTi, $contentDeTi), xmldb:store($config:data-root, $fileNameEnTi, $contentEnTi), xmldb:store($config:data-root, $fileNameEsTi, $contentEsTi),
         xmldb:store($config:data-root, $fileNameDeYe, $contentDeYe), xmldb:store($config:data-root, $fileNameEnYe, $contentEnYe), xmldb:store($config:data-root, $fileNameEsYe, $contentEsYe),
         xmldb:store($config:data-root, $fileNameDePl, $contentDePl), xmldb:store($config:data-root, $fileNameEnPl, $contentEnPl), xmldb:store($config:data-root, $fileNameEsPl, $contentEsPl))
    return      
        <p><span class="glyphicon glyphicon-thumbs-up" aria-hidden="true"></span> Noscript-files saved!</p>

};

(:declare %templates:wrap function admin:saveEditors($node as node()?, $model as map(*)?) {
    let $debug := if ($config:debug = ("trace", "info")) then console:log("[ADMIN] Storing finalFacets...") else ()
    let $create-collection  :=  
        if (not(xmldb:collection-available($config:data-root))) then 
            xmldb:create-collection($config:app-root, "data") 
        else ()
    let $fileName := 'editors.xml'
    let $content :=  
        <sal>{
            ()
        }</sal>
    let $store := xmldb:store($config:data-root, $fileName, $content)
    return
        <span>
            <p><span class="glyphicon glyphicon-thumbs-up" aria-hidden="true"></span> List of works saved!</p>
            <br/><br/>
            <a href="works.html" class="btn btn-info" role="button"><span class="glyphicon glyphicon-thumbs-up" aria-hidden="true"></span> Open works.html</a>
        </span> 
};:)


(: #### RENDERING ADMINISTRATION FUNCTIONS #### :)

declare %templates:wrap function admin:renderAuthorLemma($node as node(), $model as map(*), $aid as xs:string*, $lid as xs:string*, $lang as xs:string*) {
    let $request            :=  request:get-parameter('aid', '')
    let $switchType         :=  if ($request) then $aid else $lid
    let $switchLabel1       :=  if ($request) then 'author.html' else 'lemma.html'
    let $switchLabel2       :=  if ($request) then '?aid=' else '?lid='
    let $create-collection  :=  if (not(xmldb:collection-available($config:temp))) then xmldb:create-collection($config:app-root, "temp") else ()
    let $fileMain           :=  $switchType || '.html'
    let $fileCited          :=  $switchType || '_cited.html'
    let $fileLemma          :=  $switchType || '_lemmata.html'
    let $filePersons        :=  $switchType || '_persons.html'
    let $filePlaces         :=  $switchType || '_places.html'
    let $main :=  
        if ($request) then 
            <div>
               { render-app:dispatch(doc($config:tei-authors-root || "/" || $aid || ".xml")//tei:body, "work", ())
               }
            </div>  
        else 
            <div>
                { render-app:dispatch(doc($config:tei-lemmata-root || "/" || $lid || ".xml")//tei:body, "work", ())
                }
            </div>  
    let $cited :=  
        <div>
            {app:cited($node, $model, $lang, $aid, $lid)}
        </div>
    let $lemmata :=  
        <div>
            {app:lemmata($node, $model, $lang, $aid, $lid)}
        </div>                                       
    let $persons :=  
        <div>
            {app:persons($node, $model, $aid, $lid)}
        </div>   
    let $places :=  
        <div>
            {app:places($node, $model, $aid, $lid)}
        </div>                              
    let $store :=  
        (xmldb:store($config:data-root, $fileMain, $main),
         xmldb:store($config:data-root, $filePersons, $persons), 
         xmldb:store($config:data-root, $fileCited,   $cited),
         xmldb:store($config:data-root, $fileLemma,   $lemmata),
         xmldb:store($config:data-root, $filePlaces,  $places))     
    return  
        <p class="lead">{$config:data-root||'/'||$switchType||'.html created'}
            <a href="{($switchLabel1||$switchLabel2||$switchType)}">&#32;&#32;
                <span class="glyphicon glyphicon-play" aria-hidden="true"></span>
            </a>
        </p>
};


(:
~ Creates HTML fragments and TXT datasets for works and stores them in the database, also updating
~ the corpus datasets (TEI and TXT zips) with the respective work's data.
:)
declare %templates:wrap function admin:renderWork($workId as xs:string*) as element(div) {
    let $start-time := util:system-time()
    let $wid := if ($workId) then $workId else request:get-parameter('wid', '*')
    
    let $debug := if ($config:debug = ("trace", "info")) then console:log("[ADMIN] Rendering " || $wid || ".") else ()
    
    (: define the works to be fragmented: :)
    let $todo := 
        if ($wid = '*') then
            collection($config:tei-works-root)//tei:TEI[.//tei:text[@type = ("work_multivolume", "work_monograph")]]
        else
            collection($config:tei-works-root)//tei:TEI[@xml:id = distinct-values($wid)]

    (: for each requested work: create fragments, insert them into the transformation, and produce some diagnostic info :)
    let $createData := 
        for $work-raw in $todo
            let $workId := $work-raw/@xml:id
        
            let $cleanStatus := admin:cleanCollection($workId, "html")
            
            (: (1) HTML :)
            
            let $start-time-a := util:system-time()
            let $htmlData := html:makeHTMLData($work-raw)
            (: Keep track of how long this work did take :)
            let $runtime-ms-a := ((util:system-time() - $start-time-a) div xs:dayTimeDuration('PT1S'))  * 1000
            
            (: store data :)
            let $saveToc := admin:saveFile($workId, $workId || "_toc.html", $htmlData('toc'), "html")
            let $savePages := (
                admin:saveFile($workId, $workId || "_pages_de.html", $htmlData('pagination_de'), "html"),
                admin:saveFile($workId, $workId || "_pages_en.html", $htmlData('pagination_en'), "html"),
                admin:saveFile($workId, $workId || "_pages_es.html", $htmlData('pagination_es'), "html")
                )
            let $saveFragments :=
                for $fragment in $htmlData('fragments') return
                    let $fileName := $fragment('number') || '_' || $fragment('tei_id') || '.html'
                    let $storeStatus := if ($fragment('html')) then admin:saveFile($workId, $fileName, $fragment('html'), 'html') else ()
                    return 
                        (: generate some HTML output to be shown in report :)
                        <div>
                            <h3>Fragment {$fragment('index')}:</h3>
                            <h3>{$fragment('number')}: &lt;{$fragment('tei_name') || ' xml:id=&quot;' || $fragment('tei_id') 
                                 || '&quot;&gt;'} (Level {$fragment('tei_level')})</h3>
                            <div style="margin-left:4em;">
                                <div style="border:'3px solid black';background-color:'grey';">
                                    <code>{$wid}/{$fileName}:<br/>
                                        target xml:id={$fragment('tei_id')} <br/>
                                        prev xml:id={$fragment('prev')} <br/>
                                        next xml:id={$fragment('next')} <br/>
                                    </code>
                                    {$fragment('html')}
                                </div>
                            </div>
                        </div>
        
            (: (2) TXT :)
            
            let $txt-start-time := util:system-time()
            let $plainTextEdit := txt:makeTXTData($work-raw, 'edit')
            let $txtEditSaveStatus := admin:saveFile($workId, $workId || "_edit.txt", $plainTextEdit, "txt")
            let $debug := if ($config:debug = ("trace", "info")) then console:log("Plain text (edit) file created and stored.") else ()
            let $plainTextOrig := txt:makeTXTData($work-raw, 'orig')
            let $txtOrigSaveStatus := admin:saveFile($workId, $workId || "_orig.txt", $plainTextOrig, "txt")
            let $debug := if ($config:debug = ("trace", "info")) then console:log("Plain text (orig) file created and stored.") else ()
            let $txt-end-time := ((util:system-time() - $txt-start-time) div xs:dayTimeDuration('PT1S'))
            
            (: HTML & TXT Reporting :)
            
            return 
                <div>
                     <p><a href='work.html?wid={$workId}'>{string($workId)}</a>, Fragmentation depth: <code>{$htmlData('fragmentation_depth')}</code></p>
                     {if (count($htmlData('missed_elements'))) then <p>{count($htmlData('missed_elements'))} missed elements:<br/>
                        {for $e in $htmlData('missed_elements') return <code>{local-name($e) || '(' || string($e/@xml:id) || '); '}</code>}</p>
                      else ()}
                     {if (count($htmlData('unidentified_elements'))) then <p>{count($htmlData('unidentified_elements'))} gathered, but (due to missing @xml:id) unprocessable elements:<br/>
                        {for $e in $htmlData('unidentified_elements') return <code>{local-name($e)}</code>}</p>
                      else ()}
                     <p>{count($htmlData('tei_fragment_roots'))} gathered elements {if (count($htmlData('tei_fragment_roots'))) then 'of the following types: ' || <br/> else ()}
                        <code>{distinct-values(for $i in $htmlData('tei_fragment_roots') return local-name($i) || '(' || count($htmlData('tei_fragment_roots')[local-name(.) = local-name($i)]) || ')')}</code></p>
                     <p>Computing time (HTML): {      
                          if ($runtime-ms-a < (1000 * 60))      then format-number($runtime-ms-a div 1000, '#.##') || ' sec.'
                          else if ($runtime-ms-a < (1000 * 60 * 60)) then format-number($runtime-ms-a div (1000 * 60), '#.##') || ' min.'
                          else                                            format-number($runtime-ms-a div (1000 * 60 * 60), '#.##') || ' h.'
                        }
                     </p>
                     <p>Computing time (TXT: orig and edit): {$txt-end-time} seconds.</p>
                     {if ($config:debug = 'trace') then $saveFragments else ()}
               </div>
    
    
    (: (3) UPDATE TEI & TXT CORPORA :)
    
    (: (re-)create txt and xml corpus zips :)
    let $corpus-start-time := util:system-time()
    let $debug := if ($config:debug = ("trace", "info")) then console:log("Corpus packages created and stored.") else ()
    let $createTeiCorpus := admin:createTeiCorpus(encode-for-uri($workId))
    let $createTxtCorpus := admin:createTxtCorpus(encode-for-uri($workId))
    let $corpus-end-time := ((util:system-time() - $corpus-start-time) div xs:dayTimeDuration('PT1S'))
    
    
    let $runtime-ms-raw       := ((util:system-time() - $start-time) div xs:dayTimeDuration('PT1S'))  * 1000 
    let $runtime-ms :=
        if ($runtime-ms-raw < (1000 * 60)) then format-number($runtime-ms-raw div 1000, "#.##") || " Sek."
        else if ($runtime-ms-raw < (1000 * 60 * 60)) then format-number($runtime-ms-raw div (1000 * 60), "#.##") || " Min."
        else format-number($runtime-ms-raw div (1000 * 60 * 60), "#.##") || " Std."
    
    
    (: make sure that fragments are to be found by reindexing :)
    (:let $index-start-time := util:system-time()
    let $reindex          := if ($config:instanceMode ne "testing") then xmldb:reindex($config:webdata-root) else ()
    let $index-end-time := ((util:system-time() - $index-start-time) div xs:dayTimeDuration('PT1S')):)
    let $debug := util:log('warn', '[ADMIN] Created HTML for work ' || $wid || ' in ' || $runtime-ms || ' ms.')
    return 
        <div>
            <h2>HTML &amp; TXT Rendering</h2>
            <p>To render: {count($todo)} work(s); total computing time:
                {$runtime-ms}
            </p>
            <p>Created TEI and TXT corpora in {$corpus-end-time} seconds.</p>
            <!--<p>/db/apps/salamanca/data reindiziert in {$index-end-time} Sekunden.</p>-->
            <hr/>
            {$createData}
        </div>
};

(:
 @param $processId: can be any string and serves only for avoiding conflicts with parallel corpus building routines
:)
declare function admin:createTeiCorpus($processId as xs:string) {
    let $corpusCollection := if (not(xmldb:collection-available($config:corpus-zip-root))) then xmldb:create-collection($config:webdata-root, 'corpus-zip') else ()
    (: Create temporary collection to be zipped :)
    let $checkTempRoot := if (not(xmldb:collection-available($config:temp-root))) then xmldb:create-collection($config:data-root, 'temp') else ()
    let $tempCollection := $config:temp-root || '/tei-corpus-temp-' || $processId
    let $removeStatus := if (xmldb:collection-available($tempCollection)) then xmldb:remove($tempCollection) else ()
    let $zipTmp := xmldb:create-collection($config:temp-root, 'tei-corpus-temp-' || $processId)  
    (: Get TEI data, expand them and store them in the temporary collection :)
    let $serializationOpts := 'method=xml expand-xincludes=yes omit-xml-declaration=no indent=yes encoding=UTF-8 media-type=application/tei+xml' 
    let $works := 
        for $reqWork in collection($config:tei-works-root)/tei:TEI/@xml:id[string-length(.) eq 5]/string()
            return if (doc-available($config:tei-works-root || '/' || $reqWork || '.xml')) then
                let $expanded := util:expand(doc($config:tei-works-root || '/' || $reqWork || '.xml')/tei:TEI, $serializationOpts) 
                let $store := xmldb:store-as-binary($tempCollection, $expanded/@xml:id || '.xml', $expanded)
                return $expanded
            else ()
    (: Create a zip archive from the temporary collection and store it :)
    let $zip := compression:zip(xs:anyURI($tempCollection), false())
    (: Clean the database from temporary files/collections :)
    let $removeStatus2 := for $work in $works return xmldb:remove($tempCollection, $work/@xml:id || '.xml')
    let $removeStatus3 := if (xmldb:collection-available($tempCollection)) then xmldb:remove($tempCollection) else ()
    let $filepath := $config:corpus-zip-root  || '/sal-tei-corpus.zip'
    let $debug := if ($config:debug = ("trace", "info")) then console:log("[ADMIN] Created and stored TEI corpus zip.") else ()
    let $filepath := $config:corpus-zip-root  || '/sal-tei-corpus.zip'
    let $removeStatus4 := 
        if (file:exists($filepath)) then
            xmldb:remove($filepath)
        else ()
    let $save := xmldb:store-as-binary($config:corpus-zip-root , 'sal-tei-corpus.zip', $zip)
    return
        <div>
            <h2>TEI Corpus</h2>
            <div>{
                if ($save) then <p>Created and saved corpus zip file at {$save}.</p>    
                else <p style="color:red">Corpus zip file could not be stored!</p>
            }</div>
        </div>
};

(:
 @param $processId: can be any string and serves only for avoiding conflicts with parallel corpus building routines
:)
declare function admin:createTxtCorpus($processId as xs:string) {
    let $tempCollection := $config:temp-root || '/txt-corpus-temp-' || $processId
    let $corpusCollection := if (not(xmldb:collection-available($config:corpus-zip-root))) then xmldb:create-collection($config:webdata-root, 'corpus-zip') else ()
    let $checkTempRoot := if (not(xmldb:collection-available($config:temp-root))) then xmldb:create-collection($config:data-root, 'temp') else ()
    (: Create temporary collection to be zipped :)
    let $removeStatus := if (xmldb:collection-available($tempCollection)) then xmldb:remove($tempCollection) else ()
    let $zipTmp := xmldb:create-collection($config:temp-root, 'txt-corpus-temp-' || $processId)  
    (: Get TXT data (or if they aren't available, render them officially) and store them in the temporary collection :)
    let $storeWorks := 
        for $wid in collection($config:tei-works-root)/tei:TEI/@xml:id[string-length(.) eq 5 and app:WRKisPublished(<dummy/>,map{},.)]/string()
            return 
                let $renderOrig := 
                    if (util:binary-doc-available($config:txt-root || '/' || $wid || '/' || $wid || '_orig.txt')) then ()
                    else 
                        let $tei := util:expand(doc($config:tei-works-root || '/' || $wid || '.xml')/tei:TEI)
                        let $debug := if ($config:debug = ("trace", "info")) then console:log('[ADMIN] Rendering txt version of work: ' || $config:tei-works-root || '/' || $wid || '.xml') else ()
                        let $origTxt := string-join(txt:dispatch($tei, 'orig'), '')
                        let $debug := if ($config:debug = ("trace", "info")) then console:log('[ADMIN] Rendered ' || $wid || ', string length: ' || string-length($origTxt)) else ()
                        return admin:saveFile($wid, $wid || "_orig.txt", $origTxt, "txt")
                let $storeOrig := xmldb:store-as-binary($tempCollection, $wid || '_orig.txt', util:binary-doc($config:txt-root || '/' || $wid || '/' || $wid || '_orig.txt'))
                let $renderEdit := 
                    if (util:binary-doc-available($config:txt-root || '/' || $wid || '/' || $wid || '_edit.txt')) then ()
                    else 
                        let $tei := util:expand(doc($config:tei-works-root || '/' || $wid || '.xml')/tei:TEI)
                        let $editTxt := string-join(txt:dispatch($tei, 'edit'), '')
                        return admin:saveFile($wid, $wid || "_edit.txt", $editTxt, "txt")
                let $storeEdit := xmldb:store-as-binary($tempCollection, $wid || '_edit.txt', util:binary-doc($config:txt-root || '/' || $wid || '/' || $wid || '_edit.txt'))
                return ()
    (: Create a zip archive from the temporary collection and store it :)    
    let $zip := compression:zip(xs:anyURI($tempCollection), false())
    (: Clean the database from temporary files/collections :)
    let $removeStatus2 := for $file in xmldb:get-child-resources($tempCollection) return xmldb:remove($tempCollection, $file)
    let $removeStatus3 := if (xmldb:collection-available($tempCollection)) then xmldb:remove($tempCollection) else ()
    let $filepath := $config:corpus-zip-root  || '/sal-txt-corpus.zip'
    let $removeStatus4 := 
        if (file:exists($filepath)) then
            xmldb:remove($filepath)
        else ()
    let $debug := if ($config:debug = ("trace", "info")) then console:log("[ADMIN] Created and stored TXT corpus zip.") else ()
    let $save := xmldb:store-as-binary($config:corpus-zip-root , 'sal-txt-corpus.zip', $zip)
    return
        <div>
            <h2>TXT Corpus</h2>
            <div>{
                if ($save) then <p>Created and saved corpus zip file at {$save}.</p>    
                else <p style="color:red">Corpus zip file could not be stored!</p>
            }</div>
        </div>
};



(: Generate fragments for sphinx' indexer to grok :)
(: NOTE: the largest part of the snippets creation takes place here, not in factory/*, since it applies to different
 types of texts (works, working papers) at once :)
declare function admin:sphinx-out($wid as xs:string*, $mode as xs:string?) {

    let $start-time := util:system-time()

    (: Which works are to be indexed? :)
    let $todo := 
        if ($wid = '*') then
            collection($config:tei-root)//tei:TEI[.//tei:text[@type = ("work_multivolume", "work_monograph", "author_article", "lemma_article", "working_paper")]]
        else
            collection($config:tei-root)//tei:TEI[@xml:id = distinct-values($wid)]
    let $expanded := 
        for $work-raw in $todo
            let $cleanStatus := admin:cleanCollection($work-raw/@xml:id, "snippets")
            return util:expand($work-raw)

    (: which parts of those works constitute a fragment that is to count as a hit? :)
    let $nodes := 
        for $w in $expanded return
            if (starts-with($w/@xml:id, 'W0')) then
                (: works :)
                $w/tei:text//*[index:isBasicNode(.)]
            else if (starts-with($w/@xml:id, 'WP')) then
                (: working papers :)
                $w//tei:profileDesc//(tei:p|tei:keywords)
            else () (: TODO: authors, lemmata, etc. :)
    let $hits := 
        for $hit at $index in $nodes
            (: for each fragment, populate our sphinx fields and attributes :)
            let $work              := $hit/ancestor-or-self::tei:TEI
            let $work_id           := xs:string($work/@xml:id)
            let $nodeType := 
                if (starts-with($work_id, 'W0')) then 'work' 
                else if (starts-with($work_id, 'WP')) then 'wp' 
                else if (starts-with($work_id, 'A')) then 'author'
                else if (starts-with($work_id, 'L')) then 'lemma'
                else ()
            
            (: NOTE: the following extraction of information from TEI is supposed to work for works AND working papers, atm.
               Perhaps it would be better to separate logic for different types of texts in the future (TODO) :)
            let $work_type         := xs:string($work/tei:text/@type)
            let $teiHeader         := $work/tei:teiHeader
            let $work_author_name := sutil:formatName($teiHeader//tei:titleStmt//tei:author//tei:persName)
            let $work_author_id   := string-join($teiHeader//tei:titleStmt//tei:author//tei:persName/@ref, " ")
            let $work_title :=   
                if ($teiHeader//tei:titleStmt/tei:title[@type="short"] and not($work//tei:text[@type = "working_paper"])) then
                    $teiHeader//tei:titleStmt/tei:title[@type="short"]/text()
                else if ($teiHeader//tei:titleStmt/tei:title[@type="main"]) then
                    $teiHeader//tei:titleStmt/tei:title[@type="main"]/text()
                else $teiHeader//tei:titleStmt/tei:title[1]/text()
            let $work_year :=    
                if ($teiHeader//tei:sourceDesc//tei:date[@type = "summaryThisEd"]) then
                    xs:string($teiHeader//tei:sourceDesc//tei:date[@type = "summaryThisEd"])
                else if  ($teiHeader//tei:sourceDesc//tei:date[@type = "thisEd"]) then
                    xs:string($teiHeader//tei:sourceDesc//tei:date[@type = "thisEd"])
                else if  ($teiHeader//tei:sourceDesc//tei:date[@type = "summaryFirstEd"]) then
                    xs:string($teiHeader//tei:sourceDesc//tei:date[@type = "summaryFirstEd"])
                else if  ($teiHeader//tei:sourceDesc//tei:date[@type = "firstEd"]) then
                    xs:string($teiHeader//tei:sourceDesc//tei:date[@type = "firstEd"])
                else if  ($teiHeader//tei:date[@type ="digitizedEd"]) then
                    xs:string($teiHeader//tei:date[@type = "digitizedEd"])
                else ()
            let $hit_type := local-name($hit)
            let $hit_id := xs:string($hit/@xml:id)
            let $hit_citetrail := if ($nodeType eq 'work') then sutil:getNodetrail($work_id, $hit, 'citetrail') else ()
(:                doc($config:index-root || '/' || $work_id || '_nodeIndex.xml')//sal:node[@n = $hit_id]/sal:citetrail:)
            let $hit_language := xs:string($hit/ancestor-or-self::tei:*[@xml:lang][1]/@xml:lang)
            let $hit_fragment := 
                if ($hit_id and xmldb:collection-available($config:html-root || '/' || $work_id)) then
                    sutil:getFragmentID($work_id, $hit_id)
                else ()
            let $hit_fragment_number := 
                if ($hit_fragment) then
                    xs:int(substring($hit_fragment, 1, 4))
                else ()
            let $hit_path := 
                if ($hit_fragment) then
                    $config:webserver || "/html/" || $work_id || "/" || $hit_fragment || ".html"
                else
                    "#No fragment discoverable!"
            let $hit_url :=      
                if ($hit_fragment and $nodeType eq 'work') then
                    $config:idserver || "/texts/"   || $work_id || ':' || $hit_citetrail
                else if ($nodeType eq 'author') then
                    $config:idserver || "/authors/" || $work_id
                else if ($nodeType eq 'lemma') then
                    $config:idserver || "/lemmata/" || $work_id
                else if ($nodeType eq 'wp') then
                    $config:webserver || "/workingPaper.html?wpid=" || $work_id
                else
                    "#No fragment discoverable!"

            (: Here we define the to-be-indexed content! :)
            let $hit_content_orig := 
                if ($hit_id) then
                    if ($nodeType eq 'work') then
                        string-join(txt:dispatch($hit, 'snippets-orig'), '')
                    else string-join(render-app:dispatch($hit, 'snippets-orig', ()), '')
                else
                    'There is no xml:id in the ' || $hit_type || ' hit!'
            let $hit_content_edit := 
                if ($hit_id) then
                    if ($nodeType eq 'work') then
                        string-join(txt:dispatch($hit, 'snippets-edit'), '')
                    else string-join(render-app:dispatch($hit, 'snippets-edit', ()), '')
                else
                    'There is no xml:id in the ' || $hit_type || ' hit!'
            
            (: Now build a sphinx "row" for the fragment :)
            let $sphinx_id    := xs:long(substring($work_id, functx:index-of-string-first($work_id, "0"))) * 1000000 + ( (string-to-codepoints(substring($work_id, 1, 1)) + string-to-codepoints(substring($work_id, 2, 1))) * 10000 ) + $index
            let $html_snippet :=
                <sphinx:document id="{$sphinx_id}">
                    <div>
                        <h3>Hit
                            <sphinx_docid>{$sphinx_id}</sphinx_docid>
                            in <sphinx_work_type>{$work_type}</sphinx_work_type>{$config:nbsp}<sphinx_work>{$work_id}</sphinx_work>:<br/>
                            <sphinx_author>{$work_author_name}</sphinx_author>
                            {if ($work_author_id) then " (" || <sphinx_authorid>{$work_author_id}</sphinx_authorid> || ")" else ()},
                            <sphinx_title>{$work_title}</sphinx_title>
                            (<sphinx_year>{$work_year}</sphinx_year>)
                        </h3>
                        <h4>Hit
                            language: &quot;<sphinx_hit_language>{$hit_language}</sphinx_hit_language>&quot;,
                            node type: &lt;<sphinx_hit_type>{$hit_type}</sphinx_hit_type>&gt;,
                            node xml:id: &quot;<sphinx_hit_id>{$hit_id}</sphinx_hit_id>&quot;
                        </h4>
                        <p>
                            <em><sphinx_description_orig>{$hit_content_orig}</sphinx_description_orig></em>
                        </p>
                        <p>
                            <em><sphinx_description_edit>{$hit_content_edit}</sphinx_description_edit></em>
                        </p>
                        <p>
                            find it in fragment number {$hit_fragment_number} here: <a href="{$hit_path}"><sphinx_html_path>{$hit_path}</sphinx_html_path></a><br/>
                            or here: <a href="{$hit_url}"><sphinx_fragment_path>{$hit_url}</sphinx_fragment_path></a>
                        </p>
                        <hr/>
                    </div>
                </sphinx:document>

            let $sphinx_snippet :=
                <sphinx:document id="{$sphinx_id}" xml:space="preserve">
                    <sphinx_docid>{$sphinx_id}</sphinx_docid>
                    <sphinx_work>{$work_id}</sphinx_work>
                    <sphinx_work_type>{$work_type}</sphinx_work_type>
                    <sphinx_author>{$work_author_name}</sphinx_author>
                    <sphinx_authorid>{$work_author_id}</sphinx_authorid>
                    <sphinx_title>{$work_title}</sphinx_title>
                    <sphinx_year>{$work_year}</sphinx_year>
                    <sphinx_hit_language>{$hit_language}</sphinx_hit_language>
                    <sphinx_hit_type>{$hit_type}</sphinx_hit_type>
                    <sphinx_hit_id>{$hit_id}</sphinx_hit_id>
                    <sphinx_description_orig>{$hit_content_orig}</sphinx_description_orig>
                    <sphinx_description_edit>{$hit_content_edit}</sphinx_description_edit>
                    <sphinx_html_path>{$hit_path}</sphinx_html_path>
                    <sphinx_fragment_path>{$hit_url}</sphinx_fragment_path>
                    <sphinx_fragment_number>{$hit_fragment_number}</sphinx_fragment_number>
                </sphinx:document>

            let $fileName := format-number($index, "00000") || "_" || $hit_id || ".snippet.xml"
            let $storeStatus := if ($hit_id) then admin:saveFile($work_id, $fileName, $sphinx_snippet, "snippets") else ()

            order by $work_id ascending
            return 
                if ($mode = "html") then
                    $html_snippet
                else if ($mode = "sphinx") then
                    $sphinx_snippet
                else ()

(: Now return statistics, schema and the whole document-set :)
    let $runtime-ms := ((util:system-time() - $start-time) div xs:dayTimeDuration('PT1S')) * 1000
    return 
        if ($mode = "html") then
            <div>
                <h2>Sphinx Snippets</h2>
                <div>
                    <sphinx:docset>
                        <p>
                            Zu indizieren: {count($todo)} Werk(e); {count($hits)} Fragmente generiert; gesamte Rechenzeit:
                            {if ($runtime-ms < (1000 * 60)) then format-number($runtime-ms div 1000, "#.##") || " Sek."
                             else if ($runtime-ms < (1000 * 60 * 60)) then format-number($runtime-ms div (1000 * 60), "#.##") || " Min."
                             else format-number($runtime-ms div (1000 * 60 * 60), "#.##") || " Std."
                            }
                        </p>
                        {$hits}
                    </sphinx:docset>
                </div>
            </div>
        else if ($mode = "sphinx") then
            <sphinx:docset>
                {$sphinx:schema}
                {$hits}
            </sphinx:docset>
        else
            <div>
                <h2>Sphinx Snippets</h2>
                <div>
                    <p>Called with unknown mode &quot;{$mode}&quot; (as httpget parameter).</p>
                </div>
            </div>
};


declare function admin:createNodeIndex($wid as xs:string*) {
(:    let $debug := if ($config:debug = ("trace", "info")) then util:log("warn", "[ADMIN] Creating node index for " || $wid || ".") else ():)
    let $start-time := util:system-time()
    
    (: define the works to be indexed: :)
    let $teiRoots := 
        if ($wid = '*') then
            collection($config:tei-works-root)//tei:TEI[.//tei:text[@type = ("work_multivolume", "work_monograph")]]
        else
            collection($config:tei-works-root)//tei:TEI[@xml:id = distinct-values($wid)]

    (: for each requested work, create an individual index :)
    let $indexResults :=
        for $tei in $teiRoots return
            let $start-time-a := util:system-time()
            let $wid := string($tei/@xml:id)
            let $indexing := index:makeNodeIndex($tei)
            let $index := $indexing('index')
            let $fragmentationDepth := $indexing('fragmentation_depth')
            let $missed-elements := $indexing('missed_elements')
            let $unidentified-elements := $indexing('unidentified_elements')
             
            (: save final index file :)
            let $debug := if ($config:debug = ("trace")) then console:log("Saving index file ...") else ()
            let $indexSaveStatus := admin:saveFile($wid, $wid || "_nodeIndex.xml", $index, "index")
            let $debug := if ($config:debug = ("trace")) then console:log("Node index of "  || $wid || " successfully created.") else ()
                
            (: Reporting... :)
            
            let $runtime-ms-a := ((util:system-time() - $start-time-a) div xs:dayTimeDuration('PT1S'))  * 1000
            (: render and store the work's plain text :)
            return 
                <div>
                     <h4>{$wid}</h4>
                     <p>Fragmentation depth: <code>{$fragmentationDepth}</code></p>
                     {if (count($missed-elements)) then <p>{count($missed-elements)} missed elements:<br/>
                        {for $e in $missed-elements return <code>{local-name($e) || "(" || string($e/@xml:id) || "); "}</code>}</p>
                      else ()}
                     {if (count($unidentified-elements)) then <p>{count($unidentified-elements)} gathered, but (due to missing @xml:id) unprocessable elements:<br/>
                        {for $e in $unidentified-elements return <code>{local-name($e)}</code>}</p>
                      else ()}
                     <p>{count($index//sal:node)} gathered elements {if ($indexing('target_set_count') gt 0) then "of the following types: " || <br/> else ()}
                        <code>{for $t in distinct-values($index//sal:node/@type) return $t || "(" || count($index//sal:node[@type eq $t]) || ")"}</code></p>
                     <p>Computing time: {      
                          if ($runtime-ms-a < (1000 * 60)) then format-number($runtime-ms-a div 1000, "#.##") || " Sek."
                          else if ($runtime-ms-a < (1000 * 60 * 60)) then format-number($runtime-ms-a div (1000 * 60), "#.##") || " Min."
                          else format-number($runtime-ms-a div (1000 * 60 * 60), "#.##") || " Std."
                        }
                     </p>
               </div>
    let $runtime-ms-raw := ((util:system-time() - $start-time) div xs:dayTimeDuration('PT1S'))  * 1000 
    let $runtime-ms :=
        if ($runtime-ms-raw < (1000 * 60)) then format-number($runtime-ms-raw div 1000, "#.##") || " Sek."
        else if ($runtime-ms-raw < (1000 * 60 * 60)) then format-number($runtime-ms-raw div (1000 * 60), "#.##") || " Min."
        else format-number($runtime-ms-raw div (1000 * 60 * 60), "#.##") || " Std."
    let $debug := if ($config:debug = ("trace", "info")) then util:log("warn", "[ADMIN] Finished node indexing for " || $wid || " in " || $runtime-ms || ".") else ()
    
    return 
        <div>
            <h4>Node Indexing</h4>
            {$indexResults}
        </div>
    
    
};

declare function admin:createRDF($rid as xs:string) {
    let $rid :=  
        if (starts-with($rid, "authors/")) then
            substring-after($rid, "authors/")
        else if (starts-with($rid, "texts/")) then
            substring-after($rid, "texts/")
        else $rid
    let $start-time := util:system-time()
    let $xtriplesUrl :=
        $config:webserver || '/xtriples/extract.xql?format=rdf&amp;configuration='
        || $config:webserver || '/xtriples/createConfig.xql?resourceId=' || $rid
    let $debug := 
        if ($config:debug eq 'trace') then
            util:log("warn", "Requesting " || $xtriplesUrl || ' ...')
        else ()
    let $rdf := 
        (: if this throws an "XML Parsing Error: no root element found", this might be due to the any23 service not being available
         - check it via "curl -X POST http://localhost:8880/any23/any23/rdfxml", for example:)
        doc($xtriplesUrl) 
    let $runtime-ms := ((util:system-time() - $start-time) div xs:dayTimeDuration('PT1S'))  * 1000
    let $runtimeString := 
        if ($runtime-ms < (1000 * 60)) then format-number($runtime-ms div 1000, "#.##") || " Sek."
        else if ($runtime-ms < (1000 * 60 * 60))  then format-number($runtime-ms div (1000 * 60), "#.##") || " Min."
        else format-number($runtime-ms div (1000 * 60 * 60), "#.##") || " Std."
    let $log  := util:log('warn', 'Extracted RDF for ' || $rid || ' in ' || $runtimeString)
    let $save := admin:saveFile($rid, $rid || '.rdf', $rdf, 'rdf')
    return 
        <div>
            <h2>RDF Extraction</h2>
            <p>Extracted RDF in {$runtimeString} and saved at {$save}</p>
            <div style="margin-left:5em;">{$rdf}</div>
        </div>
};

(:
~ Creates and stores a IIIF manifest/collection for work $wid.
:)
declare function admin:createIIIF($wid as xs:string) {
    let $start-time := util:system-time()
    let $debug := 
        if ($config:debug eq 'trace') then
            util:log("warn", "Creation of IIIF resource requested, work id: " || $wid || ".")
        else ()
    let $resource := 
        serialize(iiif:createResource($wid), 
            <output:serialization-parameters>
                <output:method>json</output:method>
            </output:serialization-parameters>)
    let $runtime-ms := ((util:system-time() - $start-time) div xs:dayTimeDuration('PT1S'))  * 1000
    let $runtimeString := 
        if ($runtime-ms < (1000 * 60)) then format-number($runtime-ms div 1000, "#.##") || " Sek."
        else if ($runtime-ms < (1000 * 60 * 60))  then format-number($runtime-ms div (1000 * 60), "#.##") || " Min."
        else format-number($runtime-ms div (1000 * 60 * 60), "#.##") || " Std."
    let $log  := util:log('warn', 'Extracted IIIF for ' || $wid || ' in ' || $runtimeString)
    let $store := if ($resource) then xmldb:store($config:iiif-root, $wid || '.json', $resource) else ()
    return $resource
};


declare function admin:createStats() {
    let $log  := if ($config:debug eq 'trace') then util:log('warn', '[ADMIN] Starting to extract stats...') else ()
    let $start-time := util:system-time()
(:    let $stats := stats:makeCorpusStats():)
    let $params := 
        <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
            <output:method value="json"/>
        </output:serialization-parameters>
    (: corpus stats :)
    let $corpusStats := serialize(stats:makeCorpusStats(), $params)
    let $save := admin:saveFile('dummy', 'corpus-stats.json', $corpusStats, 'stats')
    (: single work stats:)
    let $processSingleWorks :=
        for $wid in sutil:getPublishedWorkIds() return
            let $log := if ($config:debug eq 'trace') then util:log('warn', '[ADMIN] Creating single work stats for ' || $wid) else ()
            let $workStats := serialize(stats:makeWorkStats($wid), $params)
            let $saveSingle := admin:saveFile('dummy', $wid || '-stats.json', $workStats, 'stats')
            return $workStats
    let $runtime-ms := ((util:system-time() - $start-time) div xs:dayTimeDuration('PT1S'))  * 1000
    let $runtimeString :=
        if ($runtime-ms < (1000 * 60)) then format-number($runtime-ms div 1000, "#.##") || " Sek."
        else if ($runtime-ms < (1000 * 60 * 60))  then format-number($runtime-ms div (1000 * 60), "#.##") || " Min."
        else format-number($runtime-ms div (1000 * 60 * 60), "#.##") || " Std."
    let $log  := util:log('warn', '[ADMIN] Extracted corpus and works stats in ' || $runtimeString)
    
    return $corpusStats
};

(:
for $workId in collection($config:tei-works-root)/tei:TEI[tei:text/@type = ('work_monograph', 'work_multivolume')
                                                                           and sutil:WRKisPublished(./@xml:id)]/@xml:id/string()
                    return admin:createStats('work', $workId)
:)
