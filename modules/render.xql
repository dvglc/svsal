xquery version "3.0";

module namespace render            = "http://salamanca/render";
declare namespace exist            = "http://exist.sourceforge.net/NS/exist";
declare namespace output           = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei              = "http://www.tei-c.org/ns/1.0";
declare namespace sal              = "http://salamanca.adwmainz.de";
import module namespace request    = "http://exist-db.org/xquery/request";
import module namespace templates  = "http://exist-db.org/xquery/templates";
import module namespace xmldb      = "http://exist-db.org/xquery/xmldb";
import module namespace util       = "http://exist-db.org/xquery/util";
import module namespace console    = "http://exist-db.org/xquery/console";
import module namespace config     = "http://salamanca/config" at "config.xqm";
import module namespace app        = "http://salamanca/app"    at "app.xql";
import module namespace functx     = "http://www.functx.com";
import module namespace transform  = "http://exist-db.org/xquery/transform";

(:declare option exist:serialize       "method=html5 media-type=text/html indent=no";:)

(: ####====---- Helper Functions ----====#### :)

declare function render:authorString($node as node(), $model as map(*), $lang as xs:string?) {
    let $currentAuthorId  := $model('currentAuthor')/@xml:id/string()
    return <td><a href="author.html?aid={$currentAuthorId}">{$currentAuthorId} - {app:AUTname($node, $model)}</a></td>
};

declare function render:authorMakeHTML($node as node(), $model as map(*)) {
    let $currentAuthorId := $model('currentAuthor')/@xml:id/string()
    return if (render:needsRender($currentAuthorId)) then
                <td title="source from: {string(xmldb:last-modified($config:tei-authors-root, $currentAuthorId || '.xml'))}{if (xmldb:collection-available($config:temp) and xmldb:get-child-resources($config:temp) = $currentAuthorId || ".html") then concat(', rendered on: ', xmldb:last-modified($config:temp, $currentAuthorId || ".html")) else ()}"><a href="renderTheRest.html?aid={$currentAuthorId}"><b>Render NOW!</b></a></td>
            else
                <td title="source from: {string(xmldb:last-modified($config:tei-authors-root, $currentAuthorId || '.xml'))}, Rendered on: {xmldb:last-modified($config:temp, $currentAuthorId || '.html')}">Rendering unnecessary. <small><a href="renderTheRest.html?aid={$currentAuthorId}">Render anyway!</a></small></td>
};

declare function render:lemmaString($node as node(), $model as map(*), $lang as xs:string?) {
    let $currentLemmaId  := string($model('currentLemma')/@xml:id)
    return <td><a href="lemma.html?lid={$currentLemmaId}">{$currentLemmaId} - {app:LEMtitle($node, $model)}</a></td>
};

declare function render:lemmaMakeHTML($node as node(), $model as map(*)) {
    let $currentLemmaId := string($model('currentLemma')/@xml:id)
    return if (render:needsRender($currentLemmaId)) then
                <td title="source from: {string(xmldb:last-modified($config:tei-lemmata-root, $currentLemmaId || '.xml'))}{if (xmldb:collection-available($config:temp) and xmldb:get-child-resources($config:temp) = $currentLemmaId || ".html") then concat(', rendered on: ', xmldb:last-modified($config:temp, $currentLemmaId || ".html")) else ()}"><a href="renderTheRest.html?lid={$currentLemmaId}"><b>Render NOW!</b></a></td>
            else
                <td title="source from: {string(xmldb:last-modified($config:tei-lemmata-root, $currentLemmaId || '.xml'))}, Rendered on: {xmldb:last-modified($config:temp, $currentLemmaId || ".html")}">Rendering unnecessary. <small><a href="renderTheRest.html?lid={$currentLemmaId}">Render anyway!</a></small></td>
};
           
declare function render:WPString($node as node(), $model as map(*), $lang as xs:string?) {
    let $currentWPId  := string($model('currentWp')/@xml:id)
    return <td><a href="workingPaper.html?wpid={$currentWPId}">{$currentWPId} - {app:WPtitle($node, $model)}</a></td>
};

declare function render:needsRender($targetWorkId as xs:string) as xs:boolean {
    let $targetSubcollection := 
        for $subcollection in $config:tei-sub-roots return 
            if (doc-available(concat($subcollection, '/', $targetWorkId, '.xml'))) then $subcollection
            else ()
    let $workModTime := xmldb:last-modified($targetSubcollection, $targetWorkId || '.xml')
    return
        if (substring($targetWorkId,1,2) eq "W0") then
            if ($targetWorkId || "_nodeIndex.xml" = xmldb:get-child-resources($config:index-root)) then
                let $renderModTime := xmldb:last-modified($config:index-root, $targetWorkId || "_nodeIndex.xml")
                return if ($renderModTime lt $workModTime) then true() else false()
            else
                true()
        else if (substring($targetWorkId,1,2) = ("A0", "L0", "WP")) then
            (: TODO: this should point to the directory where author/lemma/... HTML will be stored... :)
            if (not(xmldb:collection-available($config:data-root))) then
                true()
            else if ($targetWorkId || ".html" = xmldb:get-child-resources($config:data-root)) then
                let $renderModTime := xmldb:last-modified($config:data-root, $targetWorkId || ".html")
                return if ($renderModTime lt $workModTime) then true() else false()
            else true()
        else true()
};

declare function render:workString($node as node(), $model as map(*), $lang as xs:string?) {
(:    let $debug := console:log(string($model('currentWork')/@xml:id)):)
    let $currentWorkId  := $model('currentWork')?('wid')
    let $author := <span>{$model('currentWork')?('author')}</span>
    let $titleShort := $model('currentWork')?('titleShort')
    return <td><a href="{$config:webserver}/en/work.html?wid={$currentWorkId}">{$currentWorkId}: {$author} - {$titleShort}</a></td>
};

declare function render:needsRenderString($node as node(), $model as map(*)) {
    let $currentWorkId := $model('currentWork')?('wid')
    return if (render:needsRender($currentWorkId)) then
                    <td title="Source from: {string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml'))}{if (xmldb:get-child-resources($config:index-root) = $currentWorkId || "_nodeIndex.xml") then concat(', rendered on: ', xmldb:last-modified($config:index-root, $currentWorkId || "_nodeIndex.xml")) else ()}"><a href="render.html?wid={$currentWorkId}"><b>Render NOW!</b></a></td>
            else
                    <td title="Source from: {string(xmldb:last-modified($config:tei-works-root, $currentWorkId || '.xml'))}, rendered on: {xmldb:last-modified($config:index-root, $currentWorkId || "_nodeIndex.xml")}">Rendering unnecessary. <small><a href="render.html?wid={$currentWorkId}">Render anyway!</a></small></td>
};


declare function render:needsTeiCorpusZip($node as node(), $model as map(*)) {
    let $worksModTime := max(for $work in xmldb:get-child-resources($config:tei-works-root) return xmldb:last-modified($config:tei-works-root, $work))    
    let $needsCorpusZip := 
        if (util:binary-doc-available($config:corpus-zip-root || '/sal-tei-corpus.zip')) then
            let $resourceModTime := xmldb:last-modified($config:corpus-zip-root, 'sal-tei-corpus.zip')
            return $resourceModTime lt $worksModTime
        else true()
    return if ($needsCorpusZip) then
                <td title="Most current source from: {string($worksModTime)}"><a href="corpus-admin.xql?format=tei"><b>Create TEI corpus NOW!</b></a></td>
            else
                <td title="{concat('TEI corpus created on: ', string(xmldb:last-modified($config:corpus-zip-root, 'sal-tei-corpus.zip')), ', most current source from: ', string($worksModTime), '.')}">Creating TEI corpus unnecessary. <small><a href="corpus-admin.xql?format=tei">Create TEI corpus zip anyway!</a></small></td>
};

declare function render:needsTxtCorpusZip($node as node(), $model as map(*)) {
    if (xmldb:collection-available($config:txt-root)) then
        let $worksModTime := max(for $work in xmldb:get-child-resources($config:txt-root) return xmldb:last-modified($config:txt-root, $work))    
        let $needsCorpusZip := 
            if (util:binary-doc-available($config:corpus-zip-root || '/sal-txt-corpus.zip')) then
                let $resourceModTime := xmldb:last-modified($config:corpus-zip-root, 'sal-txt-corpus.zip')
                return $resourceModTime lt $worksModTime
            else true()
        return if ($needsCorpusZip) then
                    <td title="Most current source from: {string($worksModTime)}"><a href="corpus-admin.xql?format=txt"><b>Create TXT corpus NOW!</b></a></td>
                else
                    <td title="{concat('TXT corpus created on: ', string(xmldb:last-modified($config:corpus-zip-root, 'sal-txt-corpus.zip')), ', most current source from: ', string($worksModTime), '.')}">Creating TXT corpus unnecessary. <small><a href="corpus-admin.xql?format=txt">Create TXT corpus zip anyway!</a></small></td>
    else <td title="No txt sources available so far!"><a href="corpus-admin.xql?format=txt"><b>Create TXT corpus NOW!</b></a></td>
};


(: Todo: :)
(:
   ✓ Fix lbs
   ✓ Fix pbs not to include sameAs pagebreaks
   ✓ Fix milestones and notes to have divs as predecessors, not p's
   - Add head,
         ref,
         reg,
         corr,
         ...?
:)





(:~
~ Creates 'verbose' citation strings (to be included with citation anchors).
~:)
declare function render:getPassagetrail($targetWork as node()*, $targetNode as node()) {
    (: ATM, only tei:div nodes/passages receive a citation string, but all other relevant nodes :)
    let $thisPassage :=
        typeswitch($targetNode)
            case element(tei:front) return $config:citationLabels('front')?('abbr')
            case element(tei:back) return $config:citationLabels('back')?('abbr')
            case element(tei:titlePage) return $config:citationLabels('titlepage')?('abbr')
            case element(tei:text) return 
                (: "vol. X" where X is the current volume number, don't use it at all for monographs :)
                if ($targetNode/@type='work_volume') then
                   concat('vol. ', count($targetNode/preceding::tei:text[@type eq 'work_volume']) + 1)
                else ()
            (:case element(tei:note) return 
                (\: "not. X" where X is the anchor used and "nXY" where Y is the number of times that X occurs inside the current div :\)
                concat(
                    $config:citationLabels('note')?('abbr'), 
                        ' "',
                        if ($targetNode/@n) then
                               concat($targetNode/@n,
                            if (count($targetNode/ancestor::tei:div[1]//tei:note[@n eq $targetNode/@n]) gt 1) then
                                concat($targetNode/@n, 
                                       ' (',
                                       string(count($targetNode/ancestor::tei:div[1]//tei:note intersect $targetNode/preceding::tei:note[@n eq $targetNode/@n])+1),
                                      ')'
                                      )
                            else upper-case(replace($targetNode/@n, '[^a-zA-Z0-9]', ''))
                        else count($targetNode/preceding::tei:note intersect $targetNode/ancestor::tei:div[1]//tei:note) + 1):)
            default return ()
    return ()
};


declare function render:getNodetrail ($targetWork as node()*, $targetNode as node(), $mode as xs:string, $fragmentIds as map()) {
    (: (1) get the trail ID for the current node :)
    let $currentNode := 
        if ($mode eq 'crumbtrail') then
            let $class := render:dispatch($targetNode, 'class')
            return
                if ($class) then
                    <a class="{$class}" href="{render:mkUrlWhileRendering($targetWork, $targetNode, $fragmentIds)}">{render:dispatch($targetNode, 'title')}</a>
                else 
                    <a href="{render:mkUrlWhileRendering($targetWork, $targetNode, $fragmentIds)}">{render:dispatch($targetNode, 'title')}</a>
        else if ($mode = 'citetrail') then
            (: no recursion here, makes single ID for the current node :)
            render:dispatch($targetNode, 'citetrail')
        else 
            (: neither html nor numeric mode :) 
            render:dispatch($targetNode, 'title')
    
    (: (2) get related element's (e.g., ancestor's) trail, if required, and glue it together with the current trail ID 
            - HERE is the RECURSION :)
    (: (a) trail of related element: :)
    let $trailPrefix := 
        if ($targetNode/ancestor::*[render:isCitetrailNode(.)]) then
            if ($targetNode[self::tei:pb] and ($targetNode/ancestor::tei:front|$targetNode/ancestor::tei:back|$targetNode/ancestor::tei:text[1][not(@xml:id = 'completeWork' or @type = "work_part")])) then
                (: within front, back, and single volumes, prepend front's or volume's crumb ID for avoiding multiple identical IDs in the same work :)
                render:getNodetrail($targetWork,  ($targetNode/ancestor::tei:front|$targetNode/ancestor::tei:back|$targetNode/ancestor::tei:text[1][not(@xml:id = 'completeWork' or @type = "work_part")])[last()], $mode, $fragmentIds)
            else if ($targetNode[self::tei:pb]) then ()
            else 
                (: === for all other node types, get parent node's trail (deep recursion) === :)
                render:getNodetrail($targetWork, $targetNode/ancestor::*[render:isCitetrailNode(.)][1], $mode, $fragmentIds)
        else ()
    (: (b) get connector MARKER: ".", " » ", or none :)
    let $connector :=
        if ($currentNode and $trailPrefix) then
            if ($mode eq 'crumbtrail') then ' » ' 
            else if ($mode eq 'citetrail') then '.' 
            else if ($mode eq 'passagetrail') then ' '
            else ()
        else ()
    (: (c) put it all together and out :)
    let $trail :=
        if ($mode eq 'crumbtrail') then ($trailPrefix, $connector, $currentNode)
        else if ($mode eq 'citetrail') then string-join(($trailPrefix, $connector, $currentNode), '')
        else if ($mode eq 'passagetrail') then string-join(($trailPrefix, $connector, $currentNode), '')
        else ()
        
    return $trail
};

(:
~ Determines whether a node should be identifiable through a specific citetrail.
:)
declare function render:isCitetrailNode($node as element()) as xs:boolean {
    (: any element type relevant for citetrail creation must be included in one of the following functions: :)
    render:isNamedCitetrailNode($node) or render:isUnnamedCitetrailNode($node)
};

(:
~ Determines whether a node is a specific citetrail element, i.e. one that is specially prefixed in citetrails.
:)
declare function render:isNamedCitetrailNode($node as element()) as xs:boolean {
    boolean(
        $node/self::tei:back or
        $node/self::tei:front or
        $node/self::tei:div[@type ne "work_part"] or (: TODO: included temporarily for div label experiment :)
        $node/self::tei:item[ancestor::tei:list[1][@type = ('dict', 'index', 'summaries')]] or
        $node/self::tei:list[@type = ('dict', 'index', 'summaries')] or
        $node/self::tei:note or
        $node/self::tei:text[not(@xml:id = 'completeWork' or @type = "work_part")]
    )
};

(:
~ Determines whether a node is a 'generic' citetrail element, i.e. one that isn't specially prefixed in citetrails.
:)
declare function render:isUnnamedCitetrailNode($node as element()) as xs:boolean {
    boolean(
        not(
            (: exclude certain contexts in which such nodes may not appear :)
            $node/ancestor::tei:note or
            $node/ancestor::tei:lg
        ) 
        and (
            (: type checking :)
            (:$node/self::tei:div[@type ne "work_part"] or:) (: TODO: commented out for div label experiment :)
            $node/self::tei:p or
            $node/self::tei:signed or
            $node/self::tei:label or (: labels, contrarily to headings, are simply counted :)
            $node/self::tei:lg or (: count only top-level lg, not single stanzas :)
            $node/self::tei:list[not(@type = ('dict', 'index', 'summaries'))]
        )
    )
};

(: currently not in use: :)
(:declare function render:mkAnchor ($targetWork as node()*, $targetNode as node()) {
    let $targetWorkId := string($targetWork/tei:TEI/@xml:id)
    let $targetNodeId := string($targetNode/@xml:id)
    return <a href="{render:mkUrl($targetWork, $targetNode)}">{render:sectionTitle($targetWork, $targetNode)}</a>    
};:)


declare function render:mkUrlWhileRendering($targetWork as node(), $targetNode as node(), $fragmentIds as map()) {
    let $targetWorkId := string($targetWork/@xml:id)
    let $targetNodeId := string($targetNode/@xml:id)
    let $viewerPage   :=      
        if (substring($targetWorkId, 1, 2) eq "W0") then
            "work.html?wid="
        else if (substring($targetWorkId, 1, 2) eq "L0") then
            "lemma.html?lid="
        else if (substring($targetWorkId, 1, 2) eq "A0") then
            "author.html?aid="
        else if (substring($targetWorkId, 1, 2) eq "WP") then
            "workingPaper.html?wpid="
        else
            "index.html?wid="
    let $targetNodeHTMLAnchor :=    
        if (contains($targetNodeId, '-pb-')) then
            concat('pageNo_', $targetNodeId)
        else $targetNodeId
    let $frag := $fragmentIds($targetNodeId)
    return concat($viewerPage, $targetWorkId, (if ($frag) then concat('&amp;frag=', $frag) else ()), '#', $targetNodeHTMLAnchor)
};

declare function render:getFragmentFile ($targetWorkId as xs:string, $targetNodeId as xs:string) {
    doc($config:index-root || '/' || $targetWorkId || '_nodeIndex.xml')//sal:node[@n = $targetNodeId][1]/sal:fragment/text()
};

(: ####====---- End Helper Functions ----====#### :)




(: ####====---- Actual Rendering Typeswitch Functions ----====#### :)


(: TODO: comment on new modes: citetrail, crumbtrail, passagetrail :)


(: $mode can be "orig", "edit" (both being plain text modes), "html" or, even more sophisticated, "work" :)
declare function render:dispatch($node as node(), $mode as xs:string) {
    typeswitch($node)
    (: Try to sort the following nodes based (approx.) on frequency of occurences, so fewer checks are needed. :)
        case text()                 return render:textNode($node, $mode)
        case element(tei:g)         return render:g($node, $mode)
        case element(tei:lb)        return render:lb($node, $mode)
        case element(tei:pb)        return render:pb($node, $mode)
        case element(tei:cb)        return render:cb($node, $mode)
        case element(tei:fw)        return ()

        case element(tei:head)      return render:head($node, $mode)
        case element(tei:p)         return render:p($node, $mode)
        case element(tei:note)      return render:note($node, $mode)
        case element(tei:div)       return render:div($node, $mode)
        case element(tei:milestone) return render:milestone($node, $mode)
        
        case element(tei:abbr)      return render:origElem($node, $mode)
        case element(tei:orig)      return render:origElem($node, $mode)
        case element(tei:sic)       return render:origElem($node, $mode)
        case element(tei:expan)     return render:editElem($node, $mode)
        case element(tei:reg)       return render:editElem($node, $mode)
        case element(tei:corr)      return render:editElem($node, $mode)
        
        case element(tei:persName)  return render:name($node, $mode)
        case element(tei:placeName) return render:name($node, $mode)
        case element(tei:orgName)   return render:name($node, $mode)
        case element(tei:title)     return render:name($node, $mode)
        case element(tei:term)      return render:term($node, $mode)
        case element(tei:bibl)      return render:bibl($node, $mode)

        case element(tei:hi)        return render:hi($node, $mode)
        case element(tei:emph)      return render:emph($node, $mode)
        case element(tei:ref)       return render:ref($node, $mode)
        case element(tei:quote)     return render:quote($node, $mode)
        case element(tei:soCalled)  return render:soCalled($node, $mode)

        case element(tei:list)      return render:list($node, $mode)
        case element(tei:item)      return render:item($node, $mode)
        case element(tei:gloss)     return render:gloss($node, $mode)
        case element(tei:eg)        return render:eg($node, $mode)

        case element(tei:birth)     return render:birth($node, $mode)
        case element(tei:death)     return render:death($node, $mode)

        case element(tei:lg)        return render:lg($node, $mode)
        case element(tei:signed)    return render:signed($node, $mode)
        case element(tei:titlePage) return render:titlePage($node, $mode)
        case element(tei:label)     return render:label($node, $mode)
        
        case element(tei:text)      return render:text($node, $mode)
        case element(tei:front)     return render:front($node, $mode)
        case element(tei:back)      return render:back($node, $mode)

        case element(tei:figDesc)     return ()
        case element(tei:teiHeader)   return ()
        case comment()                return ()
        case processing-instruction() return ()

        default return render:passthru($node, $mode)
};


declare function render:text($node as element(tei:text), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            if ($node/@type eq 'work_volume') then
                $node/@n/string()
            (: tei:text with solely technical information: :)
            else if ($node/@xml:id eq 'completeWork') then
                '[complete work]'
            else if (matches($node/@xml:id, 'work_part_[a-z]')) then
                '[process-technical part: ' || substring(string($node/@xml:id), 11, 1) || ']'
            else ()
        )
    else if ($mode eq 'class') then
        if ($node/@type eq 'work_volume') then 'tei-text' || $node/@type
        else if ($node/@xml:id eq 'completeWork') then 'tei-text-' || $node/@xml:id
        else if (matches($node/@xml:id, 'work_part_[a-z]')) then 'elem-text-' || $node/@xml:id
        else 'tei-text'
    else if ($mode eq 'citetrail') then
        (: "volX" where X is the current volume number, don't use it at all for monographs :)
        if ($node/@type eq 'work_volume') then
           concat('vol', count($node/preceding::tei:text[@type eq 'work_volume']) + 1)
        else ()
    else
        render:passthru($node, $mode)
};

declare function render:titlePart($node as element(tei:titlePart), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            render:teaserString($node, 'edit')
        )
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        (: "titlePage.X" where X is the number of parts where this occurs :)
        concat('titlepage.', string(count($node/preceding-sibling::tei:titlePart) + 1))
    else 
        render:passthru($node, $mode)
};

declare function render:lg($node as element(tei:lg), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            render:teaserString($node, 'edit')
        )
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        if (render:isUnnamedCitetrailNode($node)) then 
            string(count($node/preceding-sibling::*[render:isUnnamedCitetrailNode(.)]) + 1)
        else ()
    else
        render:passthru($node, $mode)
};

declare function render:signed($node as element(tei:signed), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            render:teaserString($node, 'edit')
        )
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        if (render:isUnnamedCitetrailNode($node)) then 
            string(count($node/preceding-sibling::*[render:isUnnamedCitetrailNode(.)]) + 1)
        else ()
    else
        render:passthru($node, $mode)
};

declare function render:titlePage($node as element(tei:titlePage), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            (:let $volumeString := 
                if ($node/ancestor::tei:text[@type='work_volume']) then 
                    concat('Vol. ', $node/ancestor::tei:text[@type='work_volume']/@n, ', ') 
                else ()
            let $volumeCount :=
                if (count($node/ancestor::tei:text[@type='work_volume']//tei:titlePage) gt 1) then 
                    string(count($node/preceding-sibling::tei:titlePage)+1) || ', '
                else ()
            return $volumeCount || $volumeString:)
            ()
        )
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        'titlepage'
    else
        render:passthru($node, $mode)
};

declare function render:label($node as element(tei:label), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            render:teaserString($node, 'edit')
        )
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        if (render:isUnnamedCitetrailNode($node)) then 
            string(count($node/preceding-sibling::*[render:isUnnamedCitetrailNode(.)]) + 1)
        else ()
    else
        render:passthru($node, $mode)
};

declare function render:front($node as element(tei:front), $mode as xs:string) {
    if ($mode eq 'title') then
        ()
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        'frontmatter'
    else
        render:passthru($node, $mode)
};

declare function render:back($node as element(tei:back), $mode as xs:string) {
    if ($mode eq 'title') then
        ()
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        'backmatter'
    else
        render:passthru($node, $mode)
};

declare function render:textNode($node as node(), $mode as xs:string) {
    if ($mode = ("orig", "edit", "html", "work")) then
        let $leadingSpace   := if (matches($node, '^\s+')) then ' ' else ()
        let $trailingSpace  := if (matches($node, '\s+$')) then ' ' else ()
        return concat($leadingSpace, 
                      normalize-space(replace($node, '&#x0a;', ' ')),
                      $trailingSpace)
    else ()
};

declare function render:passthru($nodes as node()*, $mode as xs:string) as item()* {
    for $node in $nodes/node() return render:dispatch($node, $mode)
};

declare function render:pb($node as element(tei:pb), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            (: any pb with @sameAs and @corresp probably won't even get reached, since they typically have note ancestors :)
            if ($node/@sameAs) then
                concat('[pb_sameAs_', $node/@sameAs, ']')
            else if ($node/@corresp) then
                concat('[pb_corresp_', $node/@corresp, ']')
            else
                (: prepend volume prefix? :)
                let $volumeString := ()
                    (:if ($node/ancestor::tei:text[@type='work_volume']) then 
                        concat('Vol. ', $node/ancestor::tei:text[@type='work_volume']/@n, ', ') 
                    else ():)
                return if (contains($node/@n, 'fol.')) then $volumeString || $node/@n
                else $volumeString || 'p. ' || $node/@n
        )
    
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    
    else if ($mode eq 'citetrail') then
        (: "pX" where X is page number :)
        concat('p',
            if (matches($node/@n, '[A-Za-z0-9]')) then
                upper-case(replace($node/@n, '[^a-zA-Z0-9]', ''))
            else substring($node/@facs, 6)
        )
        (: TODO: are collisions thinkable, esp. if pb's crumb does not inherit from the specific section (titlePage|div)? 
           -> for example, with repetitive page numbers in the appendix 
            (ideally, such collisions should be resolved in TEI markup, but one never knows...) :)
    
    else if ($mode = ("orig", "edit", "html", "work")) then
        if (not($node/@break = 'no')) then
            ' '
        else ()
    
    else () (: some sophisticated function to insert a pipe and a pagenumber div in the margin :)
};

declare function render:cb($node as element(tei:cb), $mode as xs:string) {
    if ($mode = ("orig", "edit", "html", "work")) then
        if (not($node/@break = 'no')) then
            ' '
        else ()
    else ()         (: some sophisticated function to insert a pipe and a pagenumber div in the margin :)
};

declare function render:lb($node as element(tei:lb), $mode as xs:string) {
    
    if ($mode = ("orig", "edit", "work")) then
        if (not($node/@break = 'no')) then
            ' '
        else ()
    
    else if ($mode = "html") then 
        <br/>
    
    (: INACTIVE (lb aren't relevant for sal:index): :)
    (:else if ($mode eq 'citetrail') then
        (\: "pXlineY" where X is page and Y line number :\)
        concat('l',          
            if (matches($node/@n, '[A-Za-z0-9]')) then (\: this is obsolete since usage of lb/@n is deprecated: :\)
                replace(substring-after($node/@n, '_'), '[^a-zA-Z0-9]', '')
            (\: TODO: make this dependent on whether the ancestor is a marginal:  :\)
            else string(count($node/preceding::tei:lb intersect $node/preceding::tei:pb[1]/following::tei:lb) + 1)
        ):)
    
    else () 
};

declare function render:p($node as element(tei:p), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            render:teaserString($node, 'edit')
        )
    
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    
    else if ($mode eq 'citetrail') then
        if (render:isUnnamedCitetrailNode($node)) then 
            string(count($node/preceding-sibling::*[render:isUnnamedCitetrailNode(.)]) + 1)
        else ()
    else if ($mode = ("orig", "edit")) then
        if ($node/ancestor::tei:note) then
            if ($node/following-sibling::tei:p) then
                (render:passthru($node, $mode), $config:nl)
            else
                render:passthru($node, $mode)
        else
            ($config:nl, render:passthru($node, $mode), $config:nl)
    
    else if ($mode = "html") then
        if ($node/ancestor::tei:note) then
            render:passthru($node, $mode)
        else
            <p class="hauptText" id="{$node/@xml:id}">
                {render:passthru($node, $mode)}
            </p>
    
    else if ($mode = "work") then   (: the same as in html mode except for distinguishing between paragraphs in notes and in the main text. In the latter case, make them a div, not a p and add a tool menu. :)
        if ($node/parent::tei:note) then
            render:passthru($node, $mode)
        else
            <p class="hauptText" id="{$node/@xml:id}">
                {render:passthru($node, $mode)}
            </p>
    
    else
        render:passthru($node, $mode)
};
declare function render:note($node as element(tei:note), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            if ($node/@n) then
                let $noteNumber :=
                    if (count($node/ancestor::tei:div[1]//tei:note[upper-case(normalize-space(@n)) eq upper-case(normalize-space($node/@n))]) gt 1) then
                        ' (' || string(count($node/preceding::tei:note[upper-case(normalize-space(@n)) eq upper-case(normalize-space($node/@n))] intersect $node/ancestor::tei:div[1]//tei:note) + 1) || ')'
                    else ()
                return '&#34;' || normalize-space($node/@n) || '&#34;' || $noteNumber
            else string(count($node/preceding::tei:note intersect $node/ancestor::tei:div[1]//tei:note) + 1)
        )
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    else if ($mode eq 'citetrail') then
        (: "nX" where X is the anchor used (if it is alphanumeric) and "nXY" where Y is the number of times that X occurs inside the current div
            (important: nodes are citetrail children of div (not of p) and are counted as such) :)
        concat('n',  
            if (matches($node/@n, '^[A-Za-z0-9\[\]]+$')) then
                if (count($node/ancestor::tei:div[1]//tei:note[upper-case(replace(@n, '[^a-zA-Z0-9]', '')) eq upper-case(replace($node/@n, '[^a-zA-Z0-9]', ''))]) gt 1) then
                    concat(
                        upper-case(replace($node/@n, '[^a-zA-Z0-9]', '')),
                        string(count($node/ancestor::tei:div[1]//tei:note intersect $node/preceding::tei:note[upper-case(replace(@n, '[^a-zA-Z0-9]', '')) eq upper-case(replace($node/@n, '[^a-zA-Z0-9]', ''))])+1)
                    )
                else upper-case(replace($node/@n, '[^a-zA-Z0-9]', ''))
            else count($node/preceding::tei:note intersect $node/ancestor::tei:div[1]//tei:note) + 1
        )
    else if ($mode = ("orig", "edit")) then
        ($config:nl, "        {", render:passthru($node, $mode), "}", $config:nl)
    else if ($mode = ("html", "work")) then
        let $normalizedString := normalize-space(string-join(render:passthru($node, $mode), ' '))
        let $identifier       := $node/@xml:id
        return
            (<sup>*</sup>,
            <span class="marginal note" id="note_{$identifier}">
                {if (string-length($normalizedString) gt $config:chars_summary) then
                    (<a class="{string-join(for $biblKey in $node//tei:bibl/@sortKey return concat('hi_', $biblKey), ' ')}" data-toggle="collapse" data-target="#subdiv_{$identifier}">{concat('* ', substring($normalizedString, 1, $config:chars_summary), '…')}<i class="fa fa-angle-double-down"/></a>,<br/>,
                     <span class="collapse" id="subdiv_{$identifier}">{render:passthru($node, $mode)}</span>)
                 else
                    <span><sup>* </sup>{render:passthru($node, $mode)}</span>
                }
            </span>)
    else
        render:passthru($node, $mode)
};

(:
~  Creates a teaser string of limited length (defined in $config:chars_summary) from a given node.
~  @param mode: must be one of 'orig', 'edit' (default)
:)
declare function render:teaserString($node as element(), $mode as xs:string?) as xs:string {
    let $thisMode := if ($mode = ('orig', 'edit')) then $mode else 'edit'
    let $string := normalize-space(string-join(render:dispatch($node, $thisMode)))
    return 
        if (string-length($string) gt $config:chars_summary) then
            concat('&#34;', normalize-space(substring($string, 1, $config:chars_summary)), '…', '&#34;')
        else
            concat('&#34;', $string, '&#34;')
};

declare function render:body($node as element(tei:body)) {
    () (: currently INACTIVE :)
};

declare function render:div($node as element(tei:div), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
                '&#34;' || string($node/@n) || '&#34;'
            else if ($node/(tei:head|tei:label)) then
                render:teaserString(($node/(tei:head|tei:label))[1], 'edit')
            (: purely numeric section titles: :)
            else if ($node/@n and (matches($node/@n, '^[0-9\[\]]+$')) and ($node/@type)) then
                $node/@n/string()
            (: otherwise, try to derive a title from potential references to the current node :)
            else if ($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)]) then
                render:teaserString($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)][1], 'edit')
            else ()
        )
    
    else if ($mode eq 'class') then
        'tei-div-' || $node/@type
    
    else if ($mode eq 'citetrail') then
        if (render:isNamedCitetrailNode($node)) then
            (: use abbreviated form of @type (without dot), possibly followed by position :)
            (: TODO: div label experiment (delete the following block if this isn't deemed plausible) :)
            let $prefix :=
                if ($config:citationLabels($node/@type)?('abbr')) then 
                    lower-case(substring-before($config:citationLabels($node/@type)?('abbr'), '.'))
                else 'div' (: divs for which we haven't defined an abbr. :)
            let $position :=
                if (count($node/parent::*[self::tei:body or render:isCitetrailNode(.)]/tei:div[$config:citationLabels(@type)?('abbr') eq $config:citationLabels($node/@type)?('abbr')]) gt 0) then
                    string(count($node/preceding-sibling::tei:div[$config:citationLabels(@type)?('abbr') eq $config:citationLabels($node/@type)?('abbr')]) + 1)
                else ()
            return $prefix || $position
        else if (render:isUnnamedCitetrailNode($node)) then 
            string(count($node/preceding-sibling::*[render:isUnnamedCitetrailNode(.)]) + 1)
        else ()
    
    else if ($mode = "orig") then
         ($config:nl, render:passthru($node, $mode), $config:nl)
    
    else if ($mode = "edit") then
        if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
            (concat($config:nl, '[ *', string($node/@n), '* ]'), $config:nl, render:passthru($node, $mode), $config:nl)
(: oder das hier?:   <xsl:value-of select="key('targeting-refs', concat('#',@xml:id))[1]"/> :)
        else
            ($config:nl, render:passthru($node, $mode), $config:nl)
    
    else if ($mode = "html") then
        if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
            (<h4 id="{$node/@xml:id}">{string($node/@n)}</h4>,<p id="p_{$node/@xml:id}">{render:passthru($node, $mode)}</p>)
(: oder das hier?:   <xsl:value-of select="key('targeting-refs', concat('#',@xml:id))[1]"/> :)
        else
            <div id="{$node/@xml:id}">{render:passthru($node, $mode)}</div>
    
    else if ($mode = "work") then     (: basically, the same except for eventually adding a <div class="summary_title"/> the data for which is complicated to retrieve :)
        render:passthru($node, $mode)
    
    else
        render:passthru($node, $mode)
};


declare function render:milestone($node as element(tei:milestone), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
                '&#34;' || string($node/@n) || '&#34;'
            (: purely numeric section titles: :)
            else if ($node/@n and (matches($node/@n, '^[0-9\[\]]+$')) and ($node/@unit)) then
                $node/@n/string()
            (: otherwise, try to derive a title from potential references to the current node :)
            else if ($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)]) then
                render:teaserString($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)][1], 'edit')
            else ()
        )
        
    else if ($mode eq 'class') then
        'tei-milestone-' || $node/@unit
        
    else if ($mode eq 'citetrail') then
        (: "XY" where X is the unit and Y is the anchor or the number of milestones where this occurs :)
        if ($node/@n[matches(., '[a-zA-Z0-9]')]) then 
            let $precedingMs := 
                count($node/ancestor::tei:div[1]//tei:milestone[@unit eq $node/@unit and upper-case(replace(@n, '[^a-zA-Z0-9]', '')) eq upper-case(replace($node/@n, '[^a-zA-Z0-9]', ''))])
            return
                if ($precedingMs gt 0) then
                    $node/@unit || upper-case(replace($node/@n, '[^a-zA-Z0-9]', '')) || string($precedingMs + 1)
                else $node/@unit || upper-case(replace($node/@n, '[^a-zA-Z0-9]', ''))
        else $node/@unit || string(count($node/preceding::tei:milestone intersect $node/ancestor::tei:div[1]//tei:milestone[@unit eq $node/@unit]) + 1)
    
    else if ($mode = "orig") then
        if ($node/@rendition = '#dagger') then '†'
        else if ($node/@rendition = '#asterisk') then '*'
        else '[*]'
    
    else if ($mode = "edit") then
        if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
            concat('[', string($node/@n), ']')
        else if ($node/@n and matches($node/@n, '^[0-9\[\]]+$')) then
            concat('[',  $config:citationLabels($node/@unit)?('abbr'), ' ', string($node/@n), ']')
            (: TODO: remove normalization parentheses '[', ']' here (and elsewhere?) :)
        else '[*]'
    
    else if ($mode = "html") then
        let $anchor :=  if ($node/@rendition = '#dagger') then
                            '†'
                        else if ($node/@rendition = '#asterisk') then
                            '*'
                        else ()
        let $summary := if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
                            <div class="summary_title" id="{string($node/@xml:id)}">{string($node/@n)}</div>
                        else if ($node/@n and matches($node/@n, '^[0-9\[\]]+$')) then
                            <div class="summary_title" id="{string($node/@xml:id)}">{concat($config:citationLabels($node/@unit)?('abbr'), ' ', string($node/@n))}</div>
(: oder das hier?:   <xsl:value-of select="key('targeting-refs', concat('#',@xml:id))[1]"/> :)
                        else ()
        return ($anchor, $summary)
    
    else if ($mode = "work") then ()    (: basically, the same except for eventually adding a <div class="summary_title"/> :)
    
    else ()
};

(: FIXME: In the following, the #anchor does not take account of html partitioning of works. Change this to use semantic section id's. :)
declare function render:head($node as element(tei:head), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            render:teaserString($node, 'edit')
        )
    
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    
    else if ($mode eq 'citetrail') then
        concat(
            'heading', 
            (if (count($node/(parent::tei:back|parent::tei:div[@type ne "work_part"]|parent::tei:front|parent::tei:list|parent::tei:titlePart)/tei:head) gt 1) then          
                (: we have several headings on this level of the document ... :)
                string(count($node/preceding-sibling::tei:head) + 1)
             else ())
        )
    
    else if ($mode = ("orig", "edit")) then
        (render:passthru($node, $mode), $config:nl)
    
    else if ($mode = ("html", "work")) then
        let $lang   := request:get-attribute('lang')
        let $page   :=      if ($node/ancestor::tei:text/@type="author_article") then
                                "author.html?aid="
                       else if ($node/ancestor::tei:text/@type="lemma_article") then
                                "lemma.html?lid="
                       else
                                "work.html?wid="
        return    
            <h3 id="{$node/@xml:id}">
                <a class="anchorjs-link" id="{$node/parent::tei:div/@xml:id}" href="{session:encode-url(xs:anyURI($page || $node/ancestor::tei:TEI/@xml:id || '#' || $node/parent::tei:div/@xml:id))}">
                    <span class="anchorjs-icon"></span>
                </a>
                {render:passthru($node, $mode)}
            </h3>
    
    else 
        render:passthru($node, $mode)
};

declare function render:origElem($node as element(), $mode as xs:string) {
    if ($mode = "orig") then
        render:passthru($node, $mode)
    else if ($mode = "edit") then
        if (not($node/(preceding-sibling::tei:expan|preceding-sibling::tei:reg|preceding-sibling::tei:corr|following-sibling::tei:expan|following-sibling::tei:reg|following-sibling::tei:corr))) then
            render:passthru($node, $mode)
        else ()
    else if ($mode = ("html", "work")) then
        let $editedString := render:dispatch($node/parent::tei:choice/(tei:expan|tei:reg|tei:corr), "edit")
        return  if ($node/parent::tei:choice) then
                    <span class="original {local-name($node)} unsichtbar" title="{string-join($editedString, '')}">
                        {render:passthru($node, $mode)}
                    </span>
                else
                    render:passthru($node, $mode)
    else
        render:passthru($node, $mode)
};
declare function render:editElem($node as element(), $mode as xs:string) {
    if ($mode = "orig") then ()
    else if ($mode = "edit") then
        render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        let $originalString := render:dispatch($node/parent::tei:choice/(tei:abbr|tei:orig|tei:sic), "orig")
        return  
            <span class="edited {local-name($node)}" title="{string-join($originalString, '')}">
                {render:passthru($node, $mode)}
            </span>
    else
        render:passthru($node, $mode)
};
declare function render:g($node as element(tei:g), $mode as xs:string) {
    if ($mode="orig") then
        let $glyph := $node/ancestor::tei:TEI//tei:char[@xml:id = substring(string($node/@ref), 2)]
        return if ($glyph/tei:mapping[@type = 'precomposed']) then
                string($glyph/tei:mapping[@type = 'precomposed'])
            else if ($glyph/tei:mapping[@type = 'composed']) then
                string($glyph/tei:mapping[@type = 'composed'])
            else if ($glyph/tei:mapping[@type = 'standardized']) then
                string($glyph/tei:mapping[@type = 'standardized'])
            else
                render:passthru($node, $mode)
    else if ($mode = "edit") then
        let $glyph := $node/ancestor::tei:TEI//tei:char[@xml:id = substring(string($node/@ref), 2)]
        return  if ($glyph/tei:mapping[@type = 'standardized']) then
                    string($glyph/tei:mapping[@type = 'standardized'])
                else
                    render:passthru($node, $mode)
    else if ($mode = "work") then
        let $originalGlyph := render:g($node, "orig")
        return
            (<span class="original glyph unsichtbar" title="{$node/text()}">
                {$originalGlyph}
            </span>,
            <span class="edited glyph" title="{$originalGlyph}">
                {$node/text()}
            </span>)
    else
        render:passthru($node, $mode)
};

(: FIXME: In the following, work mode functionality has to be added - also paying attention to intervening pagebreak marginal divs :)
declare function render:term($node as element(tei:term), $mode as xs:string) {
    if ($mode = "orig") then
        render:passthru($node, $mode)
    else if ($mode = "edit") then
        if ($node/@key) then
            (render:passthru($node, $mode), ' [', string($node/@key), ']')
        else
            render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        let $elementName    := "term"
        let $key            := $node/@key
        let $getLemmaId     := tokenize(tokenize($node/@ref, 'lemma:')[2], ' ')[1]
        let $highlightName  :=  if ($node/@ref) then
                                    concat('hi_', translate(translate(translate(tokenize($node/@ref, ' ')[1], ',', ''), ' ', ''), ':', ''))
                                else if ($node/@key) then
                                    concat('hi_', translate(translate(translate(tokenize($node/@key, ' ')[1], ',', ''), ' ', ''), ':', ''))
                                else ()
        let $dictLemmaName  :=  if ($node/ancestor::tei:list[@type="dict"] and not($node/preceding-sibling::tei:term)) then
                                    'dictLemma'
                                else ()
        let $classes        := normalize-space(string-join(($elementName, $highlightName, $dictLemmaName), ' '))
    
        return                
            <span class="{$classes}" title="{$key}">
                {if ($getLemmaId) then
                    <a href="{session:encode-url(xs:anyURI('lemma.html?lid=' || $getLemmaId))}">{render:passthru($node, $mode)}</a>
                 else
                    render:passthru($node, $mode)
                }
            </span>
    else
        render:passthru($node, $mode)
};
declare function render:name($node as element(*), $mode as xs:string) {
    if ($mode = "orig") then
        render:passthru($node, $mode)
    else if ($mode = "edit") then
        if ($node/(@key|@ref)) then
            (render:passthru($node, $mode), ' [', string-join(($node/@key, $node/@ref), '/'), ']')
        else
            render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        let $nodeType       := local-name($node)
        let $lang           := request:get-attribute('lang')
        let $getWorkId      := tokenize(tokenize($node/@ref, 'work:'  )[2], ' ')[1]
        let $getAutId       := tokenize(tokenize($node/@ref, 'author:')[2], ' ')[1]
        let $getCerlId      := tokenize(tokenize($node/@ref, 'cerl:'  )[2], ' ')[1]
        let $getGndId       := tokenize(tokenize($node/@ref, 'gnd:'   )[2], ' ')[1]
        let $getGettyId     := tokenize(tokenize($node/@ref, 'getty:' )[2], ' ')[1]
        let $key            := $node/@key

        return
           if ($getWorkId) then
                 <span class="{($nodeType || ' hi_work_' || $getWorkId)}">
                     <a href="{concat($config:idserver, '/works.', $getWorkId)}" title="{$key}">{render:passthru($node, $mode)}</a>
                 </span> 
           else if ($getAutId) then
                 <span class="{($nodeType || ' hi_author_' || $getAutId)}">
                     <a href="{concat($config:idserver, '/authors.', $getAutId)}" title="{$key}">{render:passthru($node, $mode)}</a>
                 </span> 
            else if ($getCerlId) then 
                 <span class="{($nodeType || ' hi_cerl_' || $getCerlId)}">
                    <a target="_blank" href="{('http://thesaurus.cerl.org/cgi-bin/record.pl?rid=' || $getCerlId)}" title="{$key}">{render:passthru($node, $mode)}{$config:nbsp}<span class="glyphicon glyphicon-new-window" aria-hidden="true"></span></a>
                 </span>
            else if ($getGndId) then 
                 <span class="{($nodeType || ' hi_gnd_' || $getGndId)}">
                    <a target="_blank" href="{('http://d-nb.info/' || $getGndId)}" title="{$key}">{render:passthru($node, $mode)}{$config:nbsp}<span class="glyphicon glyphicon-new-window" aria-hidden="true"></span></a>
                 </span>
            else if ($getGettyId) then 
                 <span class="{($nodeType || ' hi_getty_' || $getGettyId)}">
                    <a target="_blank" href="{('http://www.getty.edu/vow/TGNFullDisplay?find=&amp;place=&amp;nation=&amp;english=Y&amp;subjectid=' || $getGettyId)}" title="{$key}">{render:passthru($node, $mode)}{$config:nbsp}<span class="glyphicon glyphicon-new-window" aria-hidden="true"></span></a>
                 </span>
            else
                <span>{render:passthru($node, $mode)}</span>
    else
        render:passthru($node, $mode)
};
(: titles are dealt with using the general name function above...
declare function render:title($node as element(tei:title), $mode as xs:string) {
    if ($mode = "orig") then
        render:passthru($node, $mode)
    else if ($mode = "edit") then
        if ($node/@key) then
            string($node/@key)
        else
            render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        if ($node/@ref) then
             <span class="bibl-title"><a target="blank" href="{$node/@ref}">{render:passthru($node, $mode)}<span class="glyphicon glyphicon-new-window" aria-hidden="true"/></a></span>
        else
             <span class="bibl-title">{render:passthru($node, $mode)}</span>
    else
        render:passthru($node, $mode)
};:)
declare function render:bibl($node as element(tei:bibl), $mode as xs:string) {
    if ($mode = "orig") then
        render:passthru($node, $mode)
    else if ($mode = "edit") then
        if ($node/@sortKey) then
            (render:passthru($node, $mode), ' [', replace(string($node/@sortKey), '_', ', '), ']')
        else
            render:passthru($node, $mode)
    else if ($mode = "work") then
        let $getBiblId :=  $node/@sortKey
        return if ($getBiblId) then
                    <span class="{('work hi_' || $getBiblId)}">
                        {render:passthru($node, $mode)}
                    </span>
                else
                    render:passthru($node, $mode)
    else
        render:passthru($node, $mode)
};


declare function render:emph($node as element(tei:emph), $mode as xs:string) {
    if ($mode = ("orig", "edit")) then
        render:passthru($node, $mode)
    else if ($mode = "work") then
            <span class="emph">{render:passthru($node, $mode)}</span>
    else if ($mode = "html") then
            <em>{render:passthru($node, $mode)}</em>
    else
        render:passthru($node, $mode)
};
declare function render:hi($node as element(tei:hi), $mode as xs:string) {
    if ($mode = ("orig", "edit")) then
        render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        if ("#b" = $node/@rendition) then
            <b>
                {render:passthru($node, $mode)}
            </b>
        else if ("#initCaps" = $node/@rendition) then
            <span class="initialCaps">
                {render:passthru($node, $mode)}
            </span>
        else if ("#it" = $node/@rendition) then
            <it>
                {render:passthru($node, $mode)}
            </it>
        else if ("#l-indent" = $node/@rendition) then
            <span style="display:block;margin-left:4em;">
                {render:passthru($node, $mode)}
            </span>
        else if ("#r-center" = $node/@rendition) then
            <span style="display:block;text-align:center;">
                {render:passthru($node, $mode)}
            </span>
        else if ("#sc" = $node/@rendition) then
            <span class="smallcaps">
                {render:passthru($node, $mode)}
            </span>
        else if ("#spc" = $node/@rendition) then
            <span class="spaced">
                {render:passthru($node, $mode)}
            </span>
        else if ("#sub" = $node/@rendition) then
            <sub>
                {render:passthru($node, $mode)}
            </sub>
        else if ("#sup" = $node/@rendition) then
            <sup>
                {render:passthru($node, $mode)}
            </sup>
        else
            <it>
                {render:passthru($node, $mode)}
            </it>
    else 
        render:passthru($node, $mode)
};
declare function render:ref($node as element(tei:ref), $mode as xs:string) {
    if ($mode = ("orig", "edit")) then
        render:passthru($node, $mode)
    else if ($mode = "html" and $node/@type = "url") then
        if (substring($node/@target, 1, 4) = "http") then
            <a href="{$node/@target}" target="_blank">{render:passthru($node, $mode)}</a>
        else
            <a href="{$node/@target}">{render:passthru($node, $mode)}</a>
    else if ($mode = "work") then                                       (: basically the same, but use the resolveURI functions to get the actual target :)
        <a href="{$node/@target}">{render:passthru($node, $mode)}</a>
    else
        render:passthru($node, $mode)
};
declare function render:soCalled($node as element(tei:soCalled), $mode as xs:string) {
    if ($mode=("orig", "edit")) then
        ("'", render:passthru($node, $mode), "'")
    else if ($mode = ("html", "work")) then
        <span class="soCalled">{render:passthru($node, $mode)}</span>
    else
        ("'", render:passthru($node, $mode), "'")
};
declare function render:quote($node as element(tei:quote), $mode as xs:string) {
    if ($mode=("orig", "edit")) then
        ('"', render:passthru($node, $mode), '"')
    else if ($mode = ("html", "work")) then
        <span class="quote">{render:passthru($node, $mode)}</span>
    else
        ('"', render:passthru($node, $mode), '"')
};

declare function render:list($node as element(tei:list), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
                '&#34;' || string($node/@n) || '&#34;'
            else if ($node/(tei:head|tei:label)) then
                render:teaserString(($node/(tei:head|tei:label))[1], 'edit')
            (: purely numeric section titles: :)
            else if ($node/@n and (matches($node/@n, '^[0-9\[\]]+$')) and ($node/@type)) then
                $node/@n/string()
            (: otherwise, try to derive a title from potential references to the current node :)
            else if ($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)]) then
                render:teaserString($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)][1], 'edit')
            else ()
        )
    
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
    
    else if ($mode eq 'citetrail') then
        (: dictionaries, indices and summaries get their type prepended to their number :)
        if($node/@type = ('dict', 'index', 'summaries')) then
            concat(
                $node/@type, 
                string(
                    count($node/preceding::tei:list 
                          intersect $node/(ancestor::tei:div|ancestor::tei:body|ancestor::tei:front|ancestor::tei:back)[last()]//tei:list[@type eq $node/@type]
                    ) + 1)
               )
        (: other types of lists are simply counted :)
        else if (render:isUnnamedCitetrailNode($node)) then 
            string(count($node/preceding-sibling::*[render:isUnnamedCitetrailNode(.)]) + 1)
        else ()
            (:
            string(count($node/preceding-sibling::tei:p|
                         ($node/preceding::tei:list[not(@type = ('dict', 'index', 'summaries'))] 
                          intersect $node/(ancestor::tei:div|ancestor::tei:body|ancestor::tei:front|ancestor::tei:back)[last()]//tei:list)) + 1):)
    else if ($mode = "orig") then
        ($config:nl, render:passthru($node, $mode), $config:nl)
    
    else if ($mode = "edit") then
        if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
            (concat($config:nl, ' [*', string($node/@n), '*]', $config:nl), render:passthru($node, $mode), $config:nl)
            (: or this?:   <xsl:value-of select="key('targeting-refs', concat('#',@xml:id))[1]"/> :)
        else
            ($config:nl, render:passthru($node, $mode), $config:nl)
    
    else if ($mode = ("html", "work")) then
        if ($node/@type = "ordered") then
            <section>
                {if ($node/child::tei:head) then
                    for $head in $node/tei:head
                        return
                            <h4>
                                {render:passthru($head, $mode)}
                            </h4>
                 else ()
                }
                <ol>
                    {for $item in $node/tei:*[not(local-name() = "head")]
                            return
                                render:dispatch($item, $mode)
                    }
                </ol>
            </section>
        else if ($node/@type = "simple") then
            <section>
                {if ($node/tei:head) then
                    for $head in $node/tei:head
                        return
                            <h4>{render:passthru($head, $mode)}</h4>
                 else ()
                }
                {for $item in $node/tei:*[not(local-name() = "head")]
                        return
                                render:dispatch($item, $mode)
                }
            </section>
        else
            <figure class="{$node/@type}">
                {if ($node/child::tei:head) then
                    for $head in $node/tei:head
                        return
                            <h4>{render:passthru($head, $mode)}</h4>
                 else ()
                }
                <ul>
                    {for $item in $node/tei:*[not(local-name() = "head")]
                            return
                                render:dispatch($item, $mode)
                    }
                </ul>
            </figure>
    
    else
        ($config:nl, render:passthru($node, $mode), $config:nl)
};
declare function render:item($node as element(tei:item), $mode as xs:string) {
    if ($mode eq 'title') then
        normalize-space(
            if ($node/parent::tei:list/@type='dict' and $node//tei:term[1][@key]) then
                (: TODO: collision with div/@type='lemma'? :)
                concat(
                    '&#34;',
                        concat(
                            $node//tei:term[1]/@key,
                            if (count($node/parent::tei:list/tei:item[.//tei:term[1]/@key eq $node//tei:term[1]/@key]) gt 1) then
                                concat(' - ', count($node/preceding::tei:item[tei:term[1]/@key eq $node//tei:term[1]/@key] intersect $node/ancestor::tei:div[1]//tei:item[tei:term[1]/@key eq $node//tei:term[1]/@key]) + 1)
                            else ()
                        ),
                    '&#34;'
                )
            else if ($node/@n and not(matches($node/@n, '^[0-9\[\]]+$'))) then
                '&#34;' || string($node/@n) || '&#34;'
            else if ($node/(tei:head|tei:label)) then
                render:teaserString(($node/(tei:head|tei:label))[1], 'edit')
            (: purely numeric section titles: :)
            else if ($node/@n and (matches($node/@n, '^[0-9\[\]]+$'))) then
                $node/@n/string()
            (: otherwise, try to derive a title from potential references to the current node :)
            else if ($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)]) then
                render:teaserString($node/ancestor::tei:TEI//tei:ref[@target = concat('#', $node/@xml:id)][1], 'edit')
            else ()
        )
        
    else if ($mode eq 'class') then
        'tei-' || local-name($node)
        
    else if ($mode eq 'citetrail') then
        (: "entryX" where X is the section title (render:item($node, 'title')) in capitals, use only for items in indexes and dictionary :)
        if($node/ancestor::tei:list/@type = ('dict', 'index')) then
            concat('entry', upper-case(replace(render:item($node, 'title'), '[^a-zA-Z0-9]', '')))
        else string(count($node/preceding-sibling::tei:item) + 1) (: TODO: we could also use render:isUnnamedCitetrailNode() for this :)
    
    else if ($mode = ("orig", "edit")) then
        let $leader :=  if ($node/parent::tei:list/@type = "numbered") then
                            '#' || $config:nbsp
                        else if ($node/parent::tei:list/@type = "simple") then
                            $config:nbsp
                        else
                            '-' || $config:nbsp
        return ($leader, render:passthru($node, $mode), $config:nl)
   
    else if ($mode = ("html", "work")) then
        if ($node/parent::tei:list/@type="simple") then
            render:passthru($node, $mode)
        else
            <li>{render:passthru($node, $mode)}</li>
    
    else
        render:passthru($node, $mode)
};
declare function render:gloss($node as element(tei:gloss), $mode as xs:string) {
    if ($mode = ("orig", "edit")) then
        render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        render:passthru($node, $mode)
    else
        render:passthru($node, $mode)
};

declare function render:eg($node as element(tei:eg), $mode as xs:string) {
    if ($mode = ("orig", "edit")) then
        render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        <pre>{render:passthru($node, $mode)}</pre>
    else 
        render:passthru($node, $mode)
};


declare function render:birth($node as element(tei:birth), $mode as xs:string) {
    if ($mode = ("orig", "edit")) then
        render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        <span>*&#xA0;{render:name($node/tei:placeName[1], $mode) || ': ' || $node/tei:date[1]}</span>
    else ()
};
declare function render:death($node as element(tei:death), $mode as xs:string) {
    if ($mode = ("orig", "edit")) then
        render:passthru($node, $mode)
    else if ($mode = ("html", "work")) then
        <span>†&#xA0;{render:name($node/tei:placeName[1], $mode) || ': ' || $node/tei:date[1]}</span>
    else ()
};



(: TODO: still undefined: titlePage descendants: titlePart, docTitle, ...; choice, l; author fields: state etc. :)

