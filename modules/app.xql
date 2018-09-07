xquery version "3.1";

module namespace app         = "http://salamanca.school/ns/app";
declare namespace exist      = "http://exist.sourceforge.net/NS/exist";
declare namespace opensearch = "http://a9.com/-/spec/opensearch/1.1/";
declare namespace output     = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rdf        = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace sal        = "http://salamanca.school/ns/sal";
declare namespace session    = "http://exist-db.org/xquery/session";
declare namespace srw        = "http://www.loc.gov/zing/srw/";
declare namespace tei        = "http://www.tei-c.org/ns/1.0";
declare namespace transform  = "http://exist-db.org/xquery/transform";
declare namespace util       = "http://exist-db.org/xquery/util";
declare namespace xhtml      = "http://www.w3.org/1999/xhtml";
declare namespace xi         = "http://www.w3.org/2001/XInclude";
import module namespace config    = "http://salamanca.school/ns/config"                at "config.xqm";
import module namespace render    = "http://salamanca.school/ns/render"                at "render.xql";
import module namespace sphinx    = "http://salamanca.school/ns/sphinx"                at "sphinx.xql";
import module namespace console   = "http://exist-db.org/xquery/console";
import module namespace functx    = "http://www.functx.com";
import module namespace i18n      = "http://exist-db.org/xquery/i18n"        at "i18n.xql";
import module namespace kwic      = "http://exist-db.org/xquery/kwic";
import module namespace request   = "http://exist-db.org/xquery/request";
import module namespace templates = "http://exist-db.org/xquery/templates";
import module namespace iiif      = "http://salamanca.school/ns/iiif"                  at "iiif.xql";
import module namespace util      = "http://salamanca.school/ns/util"                  at "util.xql";


(: ============ List functions =================
 : create lists, 
 : load datasets,
 : with javascript and without javascript function
 : order: datasets for js support: authors, lemmata and works (in alphabetical order)
 : then: for simple output (without js): authors, lemmata, news, working papers, works (in alphabetical order)
 :)

(: --- Facets --- :)
declare
function app:AUTfinalFacets ($node as node(), $model as map (*), $lang as xs:string?) {
    for $item in collection($config:tei-authors-root)//tei:TEI[.//tei:text/@type eq "author_article"]//tei:listPerson/tei:person[1]
        let $aid            :=  xs:string($item/ancestor::tei:TEI/@xml:id)
        let $authorUrl      :=  'author.html?aid=' || $aid
        let $status         :=  xs:string($item/ancestor-or-self::tei:TEI//tei:revisionDesc/@status)
        let $name           :=  app:formatName($item/tei:persName[1])
        let $sortName       :=  $item//tei:persName[1]/tei:surname
        let $firstChar      :=  substring($sortName, 1, 1)
        let $nameFacet      :=       if ($firstChar = ('A','B','C','D','E','F')) then 'A - F'
                                else if ($firstChar = ('G','H','I','J','K','L')) then 'G - L'
                                else if ($firstChar = ('M','N','O','P','Q','R')) then 'M - R'
                                else                                                  'S - Z'
        let $birth          :=  if (contains($item/tei:birth/tei:date[1]/@when, '-')) then
                                    substring-before($item/tei:birth/tei:date[1]/@when, '-')
                                else
                                    replace(number($item/tei:birth/tei:date[1]/@when), 'NaN', '?')
        let $death          :=  if (contains($item/tei:death/tei:date[1]/@when, '-')) then
                                    substring-before($item/tei:death/tei:date[1]/@when, '-')
                                else
                                    replace(number($item/tei:death/tei:date[1]/@when), 'NaN', '?')
        let $deathFacet     :=       if ($death < "1501") then '1501-1550'
                                else if ($death < "1551") then '1501-1550'
                                else if ($death < "1601") then '1551-1600'
                                else if ($death < "1651") then '1601-1650'
                                else if ($death < "1701") then '1651-1700'
                                else if ($death eq "?")  then '?'
                                else ()
        let $orders         :=  for $a in distinct-values($item/tei:affiliation//tei:orgName/@key)
                                    return i18n:process(<i18n:text key="{$a}">{$a}</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", "en")
        let $ordersString   :=  string-join($orders, ", ")
        let $orderFacet     :=  '"' || string-join($orders, '","') || '"'
        let $disciplines    :=  for $a in distinct-values($item/tei:education/@key)
                                    return i18n:process(<i18n:text key="{$a}">{$a}</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", "en")
        let $disciplinesString := string-join($disciplines, ", ")
        let $disciplineFacet :=  '"' || string-join($disciplines, '","') || '"'
        let $places         :=  for $b in distinct-values(for $a in ($item//tei:placeName) order by string($a/@key) collation "?lang=es" return
                                    let $placeName := if ($a/@key) then string($a/@key) else $a/text() 
                                    return $placeName) return $b
        let $placesString   :=  string-join($places, ", ")
        let $placeFacet     :=  '"' || string-join($places, '","') || '"'
        let $output :=
                   '&#123;'
                || '"authorUrl":'        || '"' || $authorUrl         || '",'
                || '"name":'             || '"' || $name              || '",' 
                || '"status":'           || '"' || $status            || '",'
                || '"sortName":'         || '"' || $sortName          || '",'        (:default sorting:)
                || '"nameFacet":'        || '"' || $nameFacet         || '",'        (:facet I:)
                || '"birth":'            || '"' || $birth             || '",' 
                || (if ($death) then             '"death":'            || '"' || $death             || '",' 
                                              || '"deathFacet":'       || '"' || $deathFacet        || '",'        (:facet II:)
                    else ())
                || (if ($ordersString) then      '"orders":'           || '"' || $ordersString      || '",'
                                              || '"orderFacet":'       || '[' || $orderFacet        || '],'        (:facet III:)
                    else ())
                || (if ($disciplinesString) then '"disciplines":'      || '"' || $disciplinesString || '",'
                                              || '"disciplineFacet":'  || '[' || $disciplineFacet   || '],'        (:facet IV:) 
                    else ())
                || (if ($placesString) then      '"places":'           || '"' || $placesString      || '",'
                                              || '"placeFacet":'       || '[' || $placeFacet        || '],'        (:facet V:)
                    else ())

                || '&#125;'  || ','
        return $output
};

declare
function app:LEMfinalFacets ($node as node(), $model as map (*), $lang as xs:string?) {
    for $item in (collection($config:tei-lemmata-root)//tei:TEI[.//tei:text/@type eq "lemma_article"])
        let $title          :=  $item//tei:titleStmt/tei:title[@type='short']
        let $status         :=  $item//tei:revisionDesc/@status/string()
        let $firstChar      :=  substring($title, 1, 1)
        let $titleFacet     :=       if ($firstChar = ('A','B','C','D','E','F')) then 'A - F'
                                else if ($firstChar = ('G','H','I','J','K','L')) then 'G - L'
                                else if ($firstChar = ('M','N','O','P','Q','R')) then 'M - R'
                                else                                                  'S - Z'
        let $author         :=  string-join(for $coauthor in $item//tei:titleStmt/tei:author/tei:persName return app:rotateFormatName($coauthor), ', ') 
        let $sortName       :=  $item//tei:titleStmt/tei:author[1]//tei:surname
        let $firstCharAut   :=  substring($item//tei:titleStmt/tei:author[1]//tei:surname, 1, 1)
        let $authorFacet   :=        if ($firstCharAut = ('A','B','C','D','E','F')) then 'A - F'
                                else if ($firstCharAut = ('G','H','I','J','K','L')) then 'G - L'
                                else if ($firstCharAut = ('M','N','O','P','Q','R')) then 'M - R'
                                else                                                     'S - Z'
        let $getLemmaId     :=  $item/@xml:id
        let $lemmaRefString :=  'lemma.html?lid=' || $getLemmaId
        return
                '&#123;' 
                || '"title":'                    || '"'|| $title          || '",'     (:default sorting:)
                || '"titleFacet":'               || '"'|| $titleFacet     || '",' (:facet I:)
                || '"status":'                   || '"'|| $status         || '",'
                || '"author":'                   || '"'|| $author         || '",'
                || '"sortName":'                 || '"'|| $sortName       || '",'     (:second sorting:)
                || '"authorFacet":'              || '"'|| $authorFacet    || '",' (:facet II:)
                || '"lemmaRefString":'           || '"'|| $lemmaRefString || '",'
                || '&#125;' || ','
};

declare
function app:WRKfinalFacets ($node as node(), $model as map (*), $lang as xs:string?) {
    for $item in (collection($config:tei-works-root)//tei:teiHeader[parent::tei:TEI//tei:text/@type = ("work_monograph", "work_multivolume")])
        let $wid            :=  xs:string($item/parent::tei:TEI/@xml:id)
        let $title          :=  $item//tei:monogr/tei:title[@type = 'short']
        let $status         :=  xs:string($item/ancestor-or-self::tei:TEI//tei:revisionDesc/@status)
        let $WIPstatus      :=  if ($item/ancestor-or-self::tei:TEI//tei:revisionDesc/@status =
                                                         ( 'a_raw',
                                                           'b_cleared',
                                                           'c_hyph_proposed',
                                                           'd_hyph_approved',
                                                           'e_emended_unenriched',
                                                           'f_enriched'
                                                         )) then "yes"
                                else "no"
        let $wrkLink        :=  'work.html?wid=' || $wid

        let $name           :=  app:rotateFormatName($item//tei:sourceDesc//tei:author/tei:persName)
        let $sortName       :=  $item//tei:sourceDesc//tei:author/tei:persName/tei:surname
        let $firstChar      :=  substring($item//tei:sourceDesc//tei:author//tei:surname, 1, 1)
        let $nameFacet      :=       if ($firstChar = ('A','B','C','D','E','F')) then 'A - F'
                                else if ($firstChar = ('G','H','I','J','K','L')) then 'G - L'
                                else if ($firstChar = ('M','N','O','P','Q','R')) then 'M - R'
                                else                                                  'S - Z'

        let $workDetails    :=  'workDetails.html?wid=' ||  $wid
        let $DetailsInfo    :=  i18n:process(<i18n:text key="details">Katalogeintrag</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", "en")

        let $workImages     :=  'mirador.html?wid=' ||  $wid
        let $FacsInfo       :=  i18n:process(<i18n:text key="facsimiles">Bildansicht</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", "en")

        let $printingPlace  :=  if ($item//tei:pubPlace[@role = 'thisEd']) then $item//tei:pubPlace[@role = 'thisEd'] 
                                else $item//tei:pubPlace[@role = 'firstEd']
        let $placeFirstChar :=  substring($printingPlace/@key, 1, 1)
        let $facetPlace     :=       if ($placeFirstChar = ('A','B','C','D','E','F')) then 'A - F'
                                else if ($placeFirstChar = ('G','H','I','J','K','L')) then 'G - L'
                                else if ($placeFirstChar = ('M','N','O','P','Q','R')) then 'M - R'
                                else                                                       'S - Z'
        let $date           :=  if ($item//tei:date[@type = 'thisEd']) then $item//tei:date[@type = 'thisEd'][1]/@when
                                else $item//tei:date[@type = 'firstEd'][1]/@when
        let $datefacet      :=       if ($date < 1501) then '1501-1550'
                                else if ($date < 1551) then '1501-1550'
                                else if ($date < 1601) then '1551-1600'
                                else if ($date < 1651) then '1601-1650'
                                else if ($date < 1701) then '1651-1700'
                                else                        '??' 
        let $printer    := if ($item//tei:sourceDesc//tei:publisher[@n="thisEd"]) then 
                                ': ' || $item//tei:sourceDesc//tei:publisher[@n="thisEd"][1]/tei:persName[1]/tei:surname
                           else ': ' || $item//tei:sourceDesc//tei:publisher[@n="firstEd"][1]/tei:persName[1]/tei:surname

        let $language       :=  i18n:process(if ($item/parent::tei:TEI//tei:text/@xml:lang = 'la') then
                                                <i18n:text key="latin">Latein</i18n:text>
                                             else
                                                <i18n:text key="spanish">Spanisch</i18n:text>
                                    , $lang, "/db/apps/salamanca/data/i18n", "en")

        let $completeWork   :=  $item/parent::tei:TEI//tei:text[@xml:id="completeWork"]
        let $volIcon        :=  if ($completeWork/@type='work_multivolume') then 'icon-text' else ()
        let $volLabel       :=  if ($completeWork/@type='work_multivolume') then
                                       <span>{i18n:process(<i18n:text key="volumes">Bände</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", "en") || ':' || $config:nbsp || $config:nbsp}</span>
                                else ()
        let $volumesString  :=  
            for $volume at $index in util:expand($completeWork)//tei:text[@type="work_volume"]
                                        let $volId      := xs:string($volume/@xml:id)
                                        let $volIdShort := $volume/@n
                                        let $volFrag    := render:getFragmentFile($wid, $volId)
                                        let $volLink    := 'work.html?wid=' || $wid || "&amp;frag=" || $volFrag || "#" || $volId
                                        let $volContent := $volIdShort||'&#xA0;&#xA0;'
                                        return '"vol' || $index || '":' || '"' || $volLink || '","vol' || $index || 'Cont":'|| '"' ||$volContent ||'",'

        let $output         :=
                                   '&#123;'
                                || '"title":'         || '"' || $title          || '",'
                                || '"status":'        || '"' || $status         || '",'
                                || '"WIPstatus":'     || '"' || $WIPstatus      || '",'
                                || '"monoMultiUrl":'  || '"' || $wrkLink        || '",'
                                || '"workDetails":'   || '"' || $workDetails    || '",'
                                || '"titAttrib":'     || '"' || $DetailsInfo    || '",'
                                || '"workImages":'    || '"' || $workImages     || '",'
                                || '"facsAttrib":'    || '"' || $FacsInfo       || '",'
                                || '"printer":'       || '"' || $printer        || '",'
                                || '"name":'          || '"' || $name           || '",'
                                || '"sortName":'      || '"' || $sortName       || '",'     (:default sorting:)
                                || '"nameFacet":'     || '"' || $nameFacet      || '",'     (:facet I:)
                                || '"date":'          || '"' || $date           || '",'  
                                || '"chronology":'    || '"' || $datefacet      || '",'     (:facet II:)
                                || '"textLanguage":'  || '"' || $language       || '",'     (:facet III:)
                                || '"printingPlace":' || '"' || $printingPlace  || '",'
                                || '"facetPlace":'    || '"' || $facetPlace     || '",'     (:facet IV:)
  (:                            ||'"sourceUrlAll":'   || '"' || $wid            || '",' :)
                                || '"volLabel":'      || '"' || $volLabel       || '",'
                                || string-join($volumesString, '')
                                || '&#125;' || ','

  (:        let $dbg := console:log($output) :)
        return $output
};

declare
function app:loadWRKfacets ($node as node(), $model as map (*), $lang as xs:string?) {
 if ($lang = 'de') then
    doc($config:data-root || "/" || 'works_de.xml')/sal/text()
 else  if ($lang = 'en') then
    doc($config:data-root || "/" || 'works_en.xml')/sal/text()
 else
    doc($config:data-root || "/" || 'works_es.xml')/sal/text()
};


(:  ==== AUTHORS-LIST (no js) ====  :)
declare
    %templates:wrap  
function app:sortAUT ($node as node(), $model as map(*), $lang as xs:string?)  {
    let $output := 
        <span>&#xA0;&#xA0;&#xA0;<span class="lead"><span class="glyphicon glyphicon-sort-by-alphabet" aria-hidden="true"></span> <i18n:text key="sort">Sortierung</i18n:text></span>
            <ul class="list-unstyled">
                 <li><a href="{('authors.html?sort=surname')}" role="button" class="btn btn-link"><i18n:text key="surname">Nachname</i18n:text></a></li>
                 <li><a href="{('authors.html?sort=order')}" role="button" class="btn btn-link"><i18n:text key="order">Orden</i18n:text></a></li>
                 <li><a href="{('authors.html?sort=death')}" role="button" class="btn btn-link"><i18n:text key="death">Todesdatum</i18n:text></a></li>
            </ul>
        </span>
            return  i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", "en")                
};        

declare
    %templates:wrap
 function app:countAUTsnoJs($node as node(), $model as map(*)) as xs:integer {
        <span>{count($model('listOfAuthors'))}</span>
};

declare
    %templates:wrap
    %templates:default("sort", "surname")
function app:loadListOfAuthors($node as node(), $model as map(*), $sort as xs:string) as map(*) {
            let $coll := collection($config:tei-authors-root)//tei:TEI[.//tei:text/@type eq "author_article"]
            let $result := 
                if ($sort eq 'surname') then 
                    for $item in $coll
                        order by $item//tei:listPerson/tei:person[1]/tei:persName[1]/tei:surname ascending
                        return $item
                else if ($sort eq 'death') then 
                    for $item in $coll
                        let $order := substring-before($item//tei:listPerson/tei:person[1]/tei:death/tei:date[1]/@when, '-')
                        order by $order ascending
                        return $item
                else if ($sort eq 'order') then 
                    for $item in $coll
                        order by $item//tei:listPerson/tei:person[1]/tei:affiliation[1]/tei:orgName[1]/@key ascending
                        return $item
                else if ($sort eq 'discipline') then 
                    for $item in $coll
                        order by $item//tei:listPerson/tei:person[1]/tei:occupation[last()]/@key ascending
                        return $item
                else if ($sort eq 'placesOfAction') then 
                    for $item in $coll
                        let $placeName := if ($item//tei:listPerson/tei:person[1]/(tei:affiliation | tei:occupation | tei:education)//tei:placeName/@key) then
                                                string($item//tei:listPerson/tei:person[1]/(tei:affiliation | tei:occupation | tei:education)//tei:placeName/@key[1])
                                          else
                                                $item//tei:listPerson/tei:person[1]/(tei:affiliation | tei:occupation | tei:education)//tei:placeName/text()[1]                    
                        order by $placeName ascending
                        return $item                   
                else
                    for $item in $coll
                        return $item
            return map { 'listOfAuthors' := $result }
};


(:  ==== LEMMATA-LIST (no js) ====  :)
declare
    %templates:wrap  
function app:sortLEM ($node as node(), $model as map(*), $lang as xs:string?)  {
        let $output := 
            <span>&#xA0;&#xA0;&#xA0;<span class="lead" ><span class="glyphicon glyphicon-sort-by-alphabet" aria-hidden="true"></span> <i18n:text key="sort">Sortierung</i18n:text></span>
                <ul class="list-unstyled">
                     <li><a href="{('dictionary.html?sort=lemma')}" role="button" class="btn btn-link"><i18n:text key="lemma">Lemma</i18n:text></a></li>
                     <li><a href="{('dictionary.html?sort=author')}" role="button" class="btn btn-link"><i18n:text key="author">Autor</i18n:text></a></li>
                </ul>
            </span>
        return  i18n:process($output, "de", "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))                
}; 

declare
    %templates:wrap
function app:countLEMsnoJs($node as node(), $model as map(*)) as xs:integer {
        let $items  :=  (collection($config:tei-lemmata-root)//tei:TEI)//tei:text[@type = 'lemma_article']
        return <span>{count($items)}</span>
};

 declare
    %templates:wrap
    %templates:default("sort", "lemma")
function app:loadListOfLemmata($node as node(), $model as map(*), $sort as xs:string) as map(*) {
            let $coll := (collection($config:tei-lemmata-root)//tei:TEI[.//tei:text/@type eq 'lemma_article'])
            let $result := 
                if ($sort eq 'lemma') then
                    for $item in $coll
                    order by $item//tei:titleStmt/tei:title[@type = 'short'] ascending
                    return $item
                else if ($sort eq 'author') then
                    for $item in $coll
                    order by $item//tei:titleStmt/tei:author[1]/tei:persName/tei:surname ascending
                    return $item
                else() 
            return map { 'listOfLemmata' := $result }
};


(:  ====NEWS-LIST (no js) ==== :)
declare
    %templates:wrap
function app:loadListOfNews($node as node(), $model as map(*)) as map(*) {
            let $result := for $item in collection($config:tei-news-root)//tei:TEI[.//tei:text/@type eq "news"]
                            order by $item//tei:change[1]/@when/string() descending
                            return $item
            return map { 'listOfNews' := $result }
};

(:  ==== WORKING-PAPERS-LIST (no js) ==== :)
declare
    %templates:wrap
 function app:loadListOfWps($node as node(), $model as map(*)) as map(*) {
            let $result := for $item in collection($config:tei-workingpapers-root)/tei:TEI[.//tei:text/@type eq "working_paper"]
                           order by $item/tei:teiHeader//tei:titleStmt/tei:title[@type='short'] descending
                           return $item
            return map { 'listOfWps' := $result }
};

(:   ==== WORKS-LIST (no js) ==== :) (:works with noscript. NOTE: this function is ONLY USED ON THE ADMIN PAGE:)
declare
    %templates:wrap
    %templates:default("sort", "surname")
function app:loadListOfWorks($node as node(), $model as map(*), $sort as xs:string) as map(*) {
            let $coll := (collection($config:tei-works-root)//tei:TEI[.//tei:text/@type = ("work_monograph", "work_multivolume")])
            let $result := 
                            if ($sort eq 'surname') then 
                                for $item in $coll
                                    order by $item//tei:sourceDesc//tei:author[1]//tei:surname ascending
                                    return $item
                             else if ($sort eq 'title') then 
                                 for $item in $coll
                                    order by $item//tei:sourceDesc//tei:title[@type = 'short'] ascending
                                    return $item
                            else if ($sort eq 'year') then    
                                 for $item in $coll
                                    order by $item//tei:sourceDesc//tei:date[@type = 'firstEd']/@when ascending
                                    return $item
                            else if ($sort eq 'place') then    
                                for $item in $coll
                                    order by $item//tei:sourceDesc//tei:pubPlace[@role = 'firstEd'] ascending
                                    return $item
                             else
                                for $item in $coll
                                    order by $item/@xml:id ascending
                                    return $item
            return map { 'listOfWorks' := $result }     
};

declare
    %templates:wrap %private
function app:WRKpublication($node as node(), $model as map(*)) {
        let $root           :=      $model('currentWork')
        let $thisEd         :=      $root//tei:pubPlace[@role = 'thisEd']
        let $firstEd        :=      $root//tei:pubPlace[@role = 'firstEd']
        let $publisher      :=      if ($thisEd) then $root//tei:imprint/tei:publisher[@n = 'thisEd']/tei:persName[1]/tei:surname else $root//tei:imprint/tei:publisher[@n = 'firstEd']/tei:persName[1]/tei:surname
        let $place          :=      if ($thisEd) then $thisEd else $firstEd
        let $year           :=      if ($thisEd) 
                                    then $root//tei:date[@type = 'thisEd']/@when/string() 
                                    else $root//tei:date[@type = 'firstEd']/@when/string()
        let $vol            :=      if ($root/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                    then concat(', ', $model('currentWork')/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                    else ()                         
        let $pubDetails     :=  $place || '&#32;'||": " || $publisher || ", " || $year || $vol
        return $pubDetails
};

declare
    %templates:wrap
    %private
function app:WRKlinks($node as node(), $model as map (*), $lang as xs:string?) {
        for $item in util:expand($model('currentWork'))//tei:text[@type="work_multivolume"]
        let $wid            :=  xs:string($item/ancestor::tei:TEI/@xml:id)
        let $completeWork   :=  $item[@xml:id="completeWork"]
        let $volumesString  :=  for $volume(: at $index:) in util:expand($completeWork)//tei:text[@type="work_volume"]
            let $volId      := xs:string($volume/@xml:id)
            let $volFrag    := render:getFragmentFile($wid, $volId)
            let $volLink    :=  'work.html?wid=' || $wid || "&amp;frag=" || $volFrag || "#" || $volId
            let $volContent := $volId || '&#32;&#32;'
            return  	<a href="{$volLink}">{$volId||'&#32;'}</a>
        return $volumesString
};
        
declare
    %templates:wrap  
function app:sortWRK ($node as node(), $model as map(*), $lang as xs:string?)  {
        let $output := 
            <span>&#xA0;&#xA0;&#xA0;<span class="lead" style="color: #999999;"><span class="glyphicon glyphicon-sort-by-alphabet" aria-hidden="true"></span> <i18n:text key="sort">Sortierung</i18n:text></span>
               <ul class="list-unstyled">
                  <li><a href="{('works.html?sort=surname')}" role="button" class="btn btn-link"><i18n:text key="surname">Nachname</i18n:text></a></li>
                  <li><a href="{('works.html?sort=title')}" role="button" class="btn btn-link"><i18n:text key="title">Titel</i18n:text></a></li>
                  <li><a href="{('works.html?sort=year')}" role="button" class="btn btn-link"><i18n:text key="year">Jahr</i18n:text></a></li>
                  <li ><a href="{('works.html?sort=place')}" role="button" class="btn btn-link"><i18n:text key="place">Ort</i18n:text></a></li>
                </ul>
            </span>
        return  i18n:process($output, "de", "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))                
};        

declare
    %templates:wrap
function app:countWRKsnoJs($node as node(), $model as map(*)) as xs:integer {
        let $items  :=  (collection($config:tei-works-root)//tei:TEI)//tei:text[@type = ('work_monograph', 'work_multivolume')]
        return <span>{count($items)}</span>
};

declare
    %templates:wrap
function app:WRKcreateListSurname($node as node(), $model as map(*), $lang as xs:string?) {
        let $items      :=  for $item in (collection($config:tei-works-root)//tei:TEI)//tei:text[@type = ('work_monograph', 'work_multivolume')]
                                let $root       :=  $item/ancestor::tei:TEI
                                let $id         :=  (session:encode-url( xs:anyURI( 'work.html?wid=' ||  $root/@xml:id ) ))
                                let $details    :=  (session:encode-url( xs:anyURI( 'workDetails.html?wid=' ||  $root/@xml:id ) ))
                                let $title      :=  $root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@type = 'short']/string()
                                let $author     :=  app:rotateFormatName($root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:author/tei:persName)
                                order by $root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:author/tei:persName/tei:surname ascending
                                    return
                                        <div class="col-md-6"> 
                                            <div class="panel panel-default">
                                                <div class="panel-body">
                                                    <a class="lead" href="{$id}"><span class="glyphicon glyphicon-file"></span>&#xA0;{$title}</a>
                                                    <br/>  
                                                    <span class="lead">{$author}</span>
                                                    <br/>
                                                    {
                                                    let $thisEd         :=      $root//tei:pubPlace[@role = 'thisEd']
                                                    let $firstEd        :=      $root//tei:pubPlace[@role = 'firstEd']
                                                    let $publisher      :=      if ($thisEd) then $root//tei:imprint/tei:publisher[@n = 'thisEd']/tei:persName[1]/tei:surname else $root//tei:imprint/tei:publisher[@n = 'firstEd']/tei:persName[1]/tei:surname
                                                    let $place          :=      if ($thisEd) then $thisEd else $firstEd
                                                    let $year           :=      if ($thisEd) 
                                                                                then $root//tei:date[@type = 'thisEd']/@when/string() 
                                                                                else $root//tei:date[@type = 'firstEd']/@when/string()
                                                    let $vol            :=      if ($root/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                then concat(', ', $model('currentWork')/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                else ()                         
                                                    let $pubDetails     :=      $place || '&#32;'||": " || $publisher || ", " || $year || $vol
                                                    return $pubDetails
                                                    }
                                                    <br/>  
                                                    {
                                                    let $wid    := string($root/@xml:id)
                                                    for $a in (doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI//tei:text[@type="work_multivolume"])
                                                         let $completeWork   :=  $a[@xml:id="completeWork"]
                                                         let $volumesString  :=  for $volume in util:expand($completeWork)//tei:text[@type="work_volume"]
                                                                                    let $volId      := xs:string($volume/@xml:id)
                                                                                    let $volFrag    := render:getFragmentFile($wid, $volId)
                                                                                    let $volLink    :=  'work.html?wid=' || $wid || "&amp;frag=" || $volFrag || "#" || $volId
                                                                                    let $volContent := $volId || '&#32;&#32;'
                                                         return  	<a href="{$volLink}">{$volId||'&#32;'}</a>   
                                                         return  $volumesString
                                                   }
                                                    <br/> 
                                                   <a  href="{$details}"  title="bibliographical details about this book"> <span class="icon-info2 pull-right" style="font-size: 1.3em;"> </span></a>
                                               </div>
                                            </div>  
                                        </div>
                                return $items
};

declare
    %templates:wrap
function app:WRKcreateListTitle($node as node(), $model as map(*), $lang as xs:string?) {
        let $items      :=  for $item in (collection($config:tei-works-root)//tei:TEI)//tei:text[@type = ('work_monograph', 'work_multivolume')]
                                let $root       :=  $item/ancestor::tei:TEI
                                let $id         :=  (session:encode-url( xs:anyURI( 'work.html?wid=' ||  $root/@xml:id ) ))
                                let $details    :=  (session:encode-url( xs:anyURI( 'workDetails.html?wid=' ||  $root/@xml:id ) ))
                                let $title      :=  $root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@type = 'short']/string()
                                let $author     :=  app:rotateFormatName($root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:author/tei:persName)
                                order by $root/tei:teiHeader//tei:sourceDesc//tei:title[@type = 'short'] ascending
                                    return
                                        <div class="col-md-6"> 
                                            <div class="panel panel-default">
                                                <div class="panel-body">
                                                    <a class="lead" href="{$id}"><span class="glyphicon glyphicon-file"></span>&#xA0;{$title}</a>
                                                    <br/>  
                                                    <span class="lead">{$author}</span>
                                                    <br/>
                                                    {
                                                    let $thisEd         :=      $root//tei:pubPlace[@role = 'thisEd']
                                                    let $firstEd        :=      $root//tei:pubPlace[@role = 'firstEd']
                                                    let $publisher      :=      if ($thisEd) then $root//tei:imprint/tei:publisher[@n = 'thisEd']/tei:persName[1]/tei:surname else $root//tei:imprint/tei:publisher[@n = 'firstEd']/tei:persName[1]/tei:surname
                                                    let $place          :=      if ($thisEd) then $thisEd else $firstEd
                                                    let $year           :=      if ($thisEd) 
                                                                                then $root//tei:date[@type = 'thisEd']/@when/string() 
                                                                                else $root//tei:date[@type = 'firstEd']/@when/string()
                                                    let $vol            :=      if ($root/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                then concat(', ', $model('currentWork')/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                else ()                         
                                                    let $pubDetails     :=      $place || '&#32;'||": " || $publisher || ", " || $year || $vol
                                                    return $pubDetails
                                                    }
                                                    <br/>  
                                                    {
                                                    let $wid    := string($root/@xml:id)
                                                    for $a in (doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI//tei:text[@type="work_multivolume"])
                                                         let $completeWork   :=  $a[@xml:id="completeWork"]
                                                         let $volumesString  :=  for $volume in util:expand($completeWork)//tei:text[@type="work_volume"]
                                                                                    let $volId      := xs:string($volume/@xml:id)
                                                                                    let $volFrag    := render:getFragmentFile($wid, $volId)
                                                                                    let $volLink    :=  'work.html?wid=' || $wid || "&amp;frag=" || $volFrag || "#" || $volId
                                                                                    let $volContent := $volId || '&#32;&#32;'
                                                         return  	<a href="{$volLink}">{$volId||'&#32;'}</a>   
                                                         return  $volumesString
                                                   }
                                                    <br/> 
                                                   <a  href="{$details}"  title="bibliographical details about this book"> <span class="icon-info2 pull-right" style="font-size: 1.3em;"> </span></a>
                                               </div>
                                            </div>  
                                        </div>
                                return $items
};

declare
    %templates:wrap
function app:WRKcreateListYear($node as node(), $model as map(*), $lang as xs:string?) {
        let $items      :=  for $item in (collection($config:tei-works-root)//tei:TEI)//tei:text[@type = ('work_monograph', 'work_multivolume')]
                                let $root       :=  $item/ancestor::tei:TEI
                                let $id         :=  (session:encode-url( xs:anyURI( 'work.html?wid=' ||  $root/@xml:id ) ))
                                let $details    :=  (session:encode-url( xs:anyURI( 'workDetails.html?wid=' ||  $root/@xml:id ) ))
                                let $title      :=  $root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@type = 'short']/string()
                                let $author     :=  app:rotateFormatName($root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:author/tei:persName)
                                order by $root/tei:teiHeader//tei:sourceDesc//tei:date[@type = 'firstEd']/@when ascending
                                    return
                                        <div class="col-md-6"> 
                                            <div class="panel panel-default">
                                                <div class="panel-body">
                                                    <a class="lead" href="{$id}"><span class="glyphicon glyphicon-file"></span>&#xA0;{$title}</a>
                                                    <br/>  
                                                    <span class="lead">{$author}</span>
                                                    <br/>
                                                    {
                                                    let $thisEd         :=      $root//tei:pubPlace[@role = 'thisEd']
                                                    let $firstEd        :=      $root//tei:pubPlace[@role = 'firstEd']
                                                    let $publisher      :=      if ($thisEd) then $root//tei:imprint/tei:publisher[@n = 'thisEd']/tei:persName[1]/tei:surname else $root//tei:imprint/tei:publisher[@n = 'firstEd']/tei:persName[1]/tei:surname
                                                    let $place          :=      if ($thisEd) then $thisEd else $firstEd
                                                    let $year           :=      if ($thisEd) 
                                                                                then $root//tei:date[@type = 'thisEd']/@when/string() 
                                                                                else $root//tei:date[@type = 'firstEd']/@when/string()
                                                    let $vol            :=      if ($root/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                then concat(', ', $model('currentWork')/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                else ()                         
                                                    let $pubDetails     :=      $place || '&#32;'||": " || $publisher || ", " || $year || $vol
                                                    return $pubDetails
                                                    }
                                                    <br/>  
                                                    {
                                                    let $wid    := string($root/@xml:id)
                                                    for $a in (doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI//tei:text[@type="work_multivolume"])
                                                         let $completeWork   :=  $a[@xml:id="completeWork"]
                                                         let $volumesString  :=  for $volume in util:expand($completeWork)//tei:text[@type="work_volume"]
                                                                                    let $volId      := xs:string($volume/@xml:id)
                                                                                    let $volFrag    := render:getFragmentFile($wid, $volId)
                                                                                    let $volLink    :=  'work.html?wid=' || $wid || "&amp;frag=" || $volFrag || "#" || $volId
                                                                                    let $volContent := $volId || '&#32;&#32;'
                                                         return  	<a href="{$volLink}">{$volId||'&#32;'}</a>   
                                                         return  $volumesString
                                                   }
                                                    <br/> 
                                                   <a  href="{$details}"  title="bibliographical details about this book"> <span class="icon-info2 pull-right" style="font-size: 1.3em;"> </span></a>
                                               </div>
                                            </div>  
                                        </div>
                                return $items
};

declare
    %templates:wrap
function app:WRKcreateListPlace($node as node(), $model as map(*), $lang as xs:string?) {
        let $items      :=  for $item in (collection($config:tei-works-root)//tei:TEI)//tei:text[@type = ('work_monograph', 'work_multivolume')]
                                let $root       :=  $item/ancestor::tei:TEI
                                let $id         :=  (session:encode-url( xs:anyURI( 'work.html?wid=' ||  $root/@xml:id ) ))
                                let $details    :=  (session:encode-url( xs:anyURI( 'workDetails.html?wid=' ||  $root/@xml:id ) ))
                                let $title      :=  $root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@type = 'short']/string()
                                let $author     :=  app:rotateFormatName($root/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:author/tei:persName)
                                let $order      :=  if ($root/tei:teiHeader//tei:sourceDesc//tei:pubPlace[@role = 'thisEd']) then $root/tei:teiHeader//tei:sourceDesc//tei:pubPlace[@role = 'thisEd']
                                                    else $root/tei:teiHeader//tei:sourceDesc//tei:pubPlace[@role = 'firstEd'] 
                                order by $order ascending
                                
                                    return
                                        <div class="col-md-6"> 
                                            <div class="panel panel-default">
                                                <div class="panel-body">
                                                    <a class="lead" href="{$id}"><span class="glyphicon glyphicon-file"></span>&#xA0;{$title}</a>
                                                    <br/>  
                                                    <span class="lead">{$author}</span>
                                                    <br/>
                                                    {
                                                    let $thisEd         :=      $root//tei:pubPlace[@role = 'thisEd']
                                                    let $firstEd        :=      $root//tei:pubPlace[@role = 'firstEd']
                                                    let $publisher      :=      if ($thisEd) then $root//tei:imprint/tei:publisher[@n = 'thisEd']/tei:persName[1]/tei:surname else $root//tei:imprint/tei:publisher[@n = 'firstEd']/tei:persName[1]/tei:surname
                                                    let $place          :=      if ($thisEd) then $thisEd else $firstEd
                                                    let $year           :=      if ($thisEd) 
                                                                                then $root//tei:date[@type = 'thisEd']/@when/string() 
                                                                                else $root//tei:date[@type = 'firstEd']/@when/string()
                                                    let $vol            :=      if ($root/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                then concat(', ', $model('currentWork')/tei:teiHeader//tei:monogr//tei:title[@type = 'volume']) 
                                                                                else ()                         
                                                    let $pubDetails     :=      $place || '&#32;'||": " || $publisher || ", " || $year || $vol
                                                    return $pubDetails
                                                    }
                                                    <br/>  
                                                    {
                                                    let $wid    := string($root/@xml:id)
                                                    for $a in (doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI//tei:text[@type="work_multivolume"])
                                                         let $completeWork   :=  $a[@xml:id="completeWork"]
                                                         let $volumesString  :=  for $volume in util:expand($completeWork)//tei:text[@type="work_volume"]
                                                                                    let $volId      := xs:string($volume/@xml:id)
                                                                                    let $volFrag    := render:getFragmentFile($wid, $volId)
                                                                                    let $volLink    :=  'work.html?wid=' || $wid || "&amp;frag=" || $volFrag || "#" || $volId
                                                                                    let $volContent := $volId || '&#32;&#32;'
                                                         return  	<a href="{$volLink}">{$volId||'&#32;'}</a>   
                                                         return  $volumesString
                                                   }
                                                    <br/> 
                                                   <a  href="{$details}"  title="bibliographical details about this book"> <span class="icon-info2 pull-right" style="font-size: 1.3em;"> </span></a>
                                               </div>
                                            </div>  
                                        </div>
                                return $items
};

declare
function app:loadWRKsnoJs ($node as node(), $model as map (*), $lang as xs:string?, $sort as xs:string?) {
         if ($sort = 'surname' and $lang ='de') then doc($config:data-root || "/" || 'worksNoJs_de_surname.xml')/sal
    else if ($sort = 'title'   and $lang ='de') then doc($config:data-root || "/" || 'worksNoJs_de_title.xml')/sal
    else if ($sort = 'year'    and $lang ='de') then doc($config:data-root || "/" || 'worksNoJs_de_year.xml')/sal
    else if ($sort = 'place'   and $lang ='de') then doc($config:data-root || "/" || 'worksNoJs_de_place.xml')/sal
    else if ($sort = 'surname' and $lang ='en') then doc($config:data-root || "/" || 'worksNoJs_en_surname.xml')/sal
    else if ($sort = 'title'   and $lang ='en') then doc($config:data-root || "/" || 'worksNoJs_en_title.xml')/sal
    else if ($sort = 'year'    and $lang ='en') then doc($config:data-root || "/" || 'worksNoJs_en_year.xml')/sal
    else if ($sort = 'place'   and $lang ='en') then doc($config:data-root || "/" || 'worksNoJs_en_place.xml')/sal
    else if ($sort = 'surname' and $lang ='es') then doc($config:data-root || "/" || 'worksNoJs_es_surname.xml')/sal
    else if ($sort = 'title'   and $lang ='es') then doc($config:data-root || "/" || 'worksNoJs_es_title.xml')/sal
    else if ($sort = 'year'    and $lang ='es') then doc($config:data-root || "/" || 'worksNoJs_es_year.xml')/sal
    else if ($sort = 'place'   and $lang ='es') then doc($config:data-root || "/" || 'worksNoJs_es_place.xml')/sal
    else if ($lang ='de')                       then doc($config:data-root || "/" || 'worksNoJs_de_surname.xml')/sal
    else if ($lang ='en')                       then doc($config:data-root || "/" || 'worksNoJs_en_surname.xml')/sal
    else if ($lang ='es')                       then doc($config:data-root || "/" || 'worksNoJs_es_surname.xml')/sal
    else()
};

declare
    %templates:wrap  
function app:WRKsNotice ($node as node(), $model as map(*), $lang as xs:string?)  {
        let $output := 
            <div style="padding:0.2em;text-align:justify">
                    <i18n:text key="worksNotice"/>
                    <a href="guidelines.html">
                        <i18n:text key="guidelines">Editionsrichtlinien</i18n:text>
                    </a>.
            </div>
        return  i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", "en")                
};


(: ====================== End  List functions ========================== :)



(: =========== Load single author, lemma, news-entry, working paper, work (in alphabetical order) ============= :)

(: ====Author==== :)
declare
    %templates:default("field", "all")
function app:loadSingleAuthor($node as node(), $model as map(*), $aid as xs:string?){
    let $context  := if ($aid) then
                        util:expand(doc($config:tei-authors-root || "/" || $aid || ".xml")/tei:TEI)
                     else if ($model("currentAuthor")) then
                        let $aid := $model("currentAuthor")/@xml:id 
                        return ($model("currentAuthor"))
                     else
                        ()
    return map { "currentAuthor"    := $context }
};

declare
    %templates:wrap
function app:AUTloadEntryHtml($node as node(), $model as map(*), $aid as xs:string?, $lid as xs:string?){
     let $switchType         :=  if (request:get-parameter('aid', '')) then $aid else $lid
     return   doc($config:data-root || "/" || $switchType||'.html')/div
};

declare
    %templates:wrap
function app:AUTloadCitedHtml($node as node(), $model as map(*), $aid as xs:string?, $lid as xs:string?){
    let $switchType         :=  if (request:get-parameter('aid', '')) then $aid else $lid
     return   doc($config:data-root || "/" || $switchType||'_cited.html')/div/ul
};

declare
    %templates:wrap
function app:AUTloadLemmataHtml($node as node(), $model as map(*), $aid as xs:string?, $lid as xs:string?){
    let $switchType         :=  if (request:get-parameter('aid', '')) then $aid else $lid
     return   doc($config:data-root || "/" || $switchType||'_lemmata.html')/div/ul
};

declare
    %templates:wrap
function app:AUTloadPersonsHtml($node as node(), $model as map(*), $aid as xs:string?, $lid as xs:string?){
    let $switchType         :=  if (request:get-parameter('aid', '')) then $aid else $lid
     return   doc($config:data-root || "/" || $switchType||'_persons.html')/div/ul
};

declare
    %templates:wrap
function app:AUTloadPlacesHtml($node as node(), $model as map(*), $aid as xs:string?, $lid as xs:string?){
    let $switchType         :=  if (request:get-parameter('aid', '')) then $aid else $lid
     return  doc($config:data-root || "/" || $switchType||'_places.html')/div/ul
};

(: ====Lemma==== :)
declare
    %templates:default("field", "all")
function app:loadSingleLemma($node as node(), $model as map(*), $lid as xs:string?) {
    let $context  := if ($lid) then
                        util:expand(doc($config:tei-lemmata-root || "/" || $lid || ".xml")/tei:TEI)
                     else if ($model("currentLemma")) then
                        let $lid := $model("currentLemma")/@xml:id
                        return ($model("currentLemma"))
                     else
                        ()
    return map { "currentLemma"    := $context }
};

declare
    %templates:wrap
function app:LEMloadEntryHtml($node as node(), $model as map(*), $lid as xs:string?){
    doc($config:data-root || "/" || $lid||'.html')/span
};

declare
    %public
function app:displaySingleLemma($node as node(), $model as map(*), $lid as xs:string?, $q as xs:string?) {   
    let $lemma-id    :=  if ($lid) then
                            $lid
                        else
                            $model("currentLemma")/@xml:id
    let $doc        :=  if ($q and $model("results")) then
                            util:expand($model("results")/ancestor::tei:TEI)
                        else
                            util:expand(doc($config:tei-lemmata-root || "/" || $lemma-id || ".xml")/tei:TEI)
    let $stylesheet := doc(xs:anyURI($config:app-root || "/resources/xsl/reading_view.xsl"))
    let $parameters :=  <parameters>
                            <param name="exist:stop-on-warn" value="yes"/>
                            <param name="exist:stop-on-error" value="yes"/>
                            <param name="docURL" value="{request:get-url() || '?lid=' || $lemma-id}"/>                       
                        </parameters>
    return 
            <div>{transform:transform($doc, $stylesheet, $parameters)}

                <span>
                      lid = {$lid}<br/>
                      lemma-id = {$lemma-id}<br/>
                      doc/id = {$doc/@xml:id/string()}<br/>
                      model(currentLemma)/id  = {$model("currentLemma")/@xml:id/string()}<br/>
                      count(m(results))      = {count($model("results"))}<br/>
                </span>

            </div>
};

(: ====News==== :)
declare
    %templates:default
function app:loadSingleNews($node as node(), $model as map(*), $nid as xs:string?){
    let $context  := if ($nid) then
                        doc($config:tei-news-root || "/" || $nid || ".xml")/tei:TEI
                     else if ($model("currentNews")) then
                        let $nid := $model("currentNews")/@xml:id 
                        return ($model("currentNews"))
                     else
                        ()
    return map { "currentNews"    := $context }
};


(: ====Working paper==== :)
declare
    %templates:default
function app:loadSingleWp($node as node(), $model as map(*), $wpid as xs:string?){
    let $context  := if ($wpid) then
                        doc($config:tei-workingpapers-root || "/" || $wpid || ".xml")/tei:TEI
                     else if ($model("currentWp")) then
                        let $wpid := $model("currentWp")/@xml:id 
                        return ($model("currentWp"))
                     else
                        ()
    return map { "currentWp"    := $context }
};

(: ====Work==== :)

declare
function app:watermark($node as node(), $model as map(*), $wid as xs:string?, $lang as xs:string?) {
    let $watermark :=   if (($model('currentAuthor')//tei:revisionDesc/@status |
                             $model('currentLemma')//tei:revisionDesc/@status  |
                             doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI//tei:revisionDesc/@status)[1]  (: $model("currentWork")//tei:revisionDesc/@status)[1] :)
                                                        = ('a_raw',
                                                           'b_cleared',
                                                           'c_hyph_proposed',
                                                           'd_hyph_approved',
                                                           'e_emended_unenriched',
                                                           'f_enriched'
                                                          )) then
                            <p class="watermark-wip-text">
                                <i18n:text key="workInProgress">Work in Progress!</i18n:text>
                            </p>
                        else
                            <p class="watermark-wip-text">
                                {string(($model('currentAuthor')//tei:revisionDesc/@status |
                                         $model('currentLemma')//tei:revisionDesc/@status  |
                                         $model("currentWork")//tei:revisionDesc/@status)[1])}          <!-- (: $model("currentWork")//tei:revisionDesc/@status)[1] :) -->
                            </p>
    return i18n:process($watermark, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
};

declare
function app:watermark-txtonly($node as node(), $model as map(*), $wid as xs:string?, $lang as xs:string?) {
    let $watermark :=   if (($model('currentAuthor')//tei:revisionDesc/@status |
                             $model('currentLemma')//tei:revisionDesc/@status  |
                             doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI//tei:revisionDesc/@status)[1]  (: $model("currentWork")//tei:revisionDesc/@status)[1] :)
                                                        = ('a_raw',
                                                           'b_cleared',
                                                           'c_hyph_proposed',
                                                           'd_hyph_approved',
                                                           'e_emended_unenriched',
                                                           'f_enriched'
                                                          )) then
                            <span>{i18n:process(<i18n:text key="workInProgress">Work in Progress!</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))}</span>
                        else
                            <span>{string(($model('currentAuthor')//tei:revisionDesc/@status |
                                     $model('currentLemma')//tei:revisionDesc/@status  |
                                     $model("currentWork")//tei:revisionDesc/@status)[1])}</span>
    return $watermark
};

declare
    %templates:wrap
function app:loadSingleWork($node as node(), $model as map(*), $wid as xs:string?) {
    let $context  :=   if (doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI//tei:text[@type="work_multivolume"]) then
                            util:expand(doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI)
                     else
                            doc($config:tei-works-root || "/" || $wid || ".xml")/tei:TEI
    return  map {"currentWork"    := $context}
};

declare
function app:displaySingleWork($node as node(), $model as map(*),
                                            $wid as xs:string?,
                                            $frag as xs:string?,
                                            $q as xs:string?,
                                            $mode as xs:string?,
                                            $viewer as xs:string?, 
                                            $lang as xs:string?) {   
    let $workId             := if ($wid) then $wid else $model("currentWork")/@xml:id

    let $targetFragment    :=   if (xmldb:collection-available($config:html-root || "/" || $workId)) then
                                    if ($frag and $frag || ".html" = xmldb:get-child-resources($config:html-root || "/" || $workId)) then
                                        $frag || ".html"
                                    else if (xmldb:collection-available($config:html-root || "/" || $workId)) then
                                        functx:sort(xmldb:get-child-resources($config:html-root || "/" || $workId))[1]
                                    else ()
                                else ()

    let $originalDoc    := doc($config:html-root || "/" || $workId || "/" || $targetFragment)

    (: Fill in all parameters (except frag) in pagination links :)
    let $urlParameters  := string-join((
                                        if (exists($q)) then 'q=' || $q else (),
                                        if (exists($mode)) then 'mode=' || $mode else (),
                                        if (exists($viewer)) then 'viewer=' || $viewer else (),
                                        if (exists($lang)) then 'lang=' || $lang else ()
                                       ), '&amp;')
    let $xslSheet       := <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
                                <xsl:output omit-xml-declaration="yes" indent="yes"/>
                                <xsl:param name="urlParameters"/>

                                <!-- Default: Copy everything -->
                                <xsl:template match="node()|@*" priority="2">
                                    <xsl:copy>
                                        <xsl:apply-templates select="node()|@*"/>
                                    </xsl:copy>
                                </xsl:template>

                                <!-- Change on-site href parameters -->
                                <xsl:template match="a/@href[not(contains(., 'http'))]" priority="80">
                                    <xsl:variable name="openingChar">
                                        <xsl:choose>
                                            <xsl:when test="contains(., '?')">
                                                <xsl:text>&amp;</xsl:text>
                                            </xsl:when>                                                            
                                            <xsl:otherwise>
                                                <xsl:text>?</xsl:text>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:variable>

                                    <xsl:attribute name="href">
                                        <xsl:choose>
                                            <xsl:when test="starts-with(., '#')">
                                                <xsl:value-of select="."/>
                                            </xsl:when>
                                            <xsl:when test="contains(., '#')">
                                                <xsl:value-of select="replace(., '#', concat($openingChar, $urlParameters, '#'))"/>
                                            </xsl:when>                                                            
                                            <xsl:otherwise>
                                                <xsl:value-of select="concat(., $openingChar, $urlParameters)"/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:attribute>
                                </xsl:template>
                            </xsl:stylesheet>
    let $parameters     := <parameters>
                                          <param name="exist:stop-on-warn"  value="yes"/>
                                          <param name="exist:stop-on-error" value="yes"/>
                                          <param name="urlParameters"       value="{$urlParameters}"/>
                                      </parameters>
    let $parametrizedDoc    := transform:transform($originalDoc, $xslSheet, $parameters)

    (: If we have an active query string, highlight the original html fragment accordingly :)
    let $outHTML := if ($q) then 
                                    sphinx:highlight($parametrizedDoc, $q)//item[1]/description
                                 else
                                    $parametrizedDoc

    let $debugOutput   := if ($config:debug = "trace") then
                                <p>
                                    wid: {$wid}<br/>
                                    $model("currentWork")/@xml:id: {xs:string($model("currentWork")/@xml:id)}<br/>
                                    workId: {$workId}<br/>
                                    q: {$q}<br/>
                                    mode: {$mode}<br/>
                                    viewer: {$viewer}<br/>
                                    lang: {$lang}<br/>
                                    doc($config:html-root || "/" || $workId || "/" || $targetFragment): {substring(serialize(doc($config:html-root || "/" || $workId || "/" || $targetFragment)), 1, 300)}
                                </p>
                            else ()
    let $workNotAvailable := <h2><span class="glyphicon glyphicon-file"></span> <i18n:text key="workNotAvailable">Dieses Werk ist noch nicht verfügbar.</i18n:text></h2>

    return
        if ($targetFragment) then
            <div>
                {$debugOutput}
                {$outHTML}
            </div>
        else
            (: TODO: redirect to genuine error or resource-not-available page :)
            i18n:process($workNotAvailable, $lang, "/db/apps/salamanca/data/i18n", "en")
};

declare
function app:searchResultsNav($node as node(), $model as map(*), $q as xs:string?, $lang as xs:string?) {
    let $nav := if ($q) then
                    <div class="searchResultsNav col-lg-8 col-md-8 col-sm-9 col-xs-12">
                        Search for "{$q}". <a href="#" class="gotoResult" id="gotoPrevResult">Previous</a>{$config:nbsp || $config:nbsp}<a href="#" class="gotoResult" id="gotoNextResult">Next</a>
                    </div>
                else ()
    return $nav
};

(: =========== End of Load single author, lemma, news-entry, working paper, work (in alphabetical order) ============= :)

(: ============== Retrieve single *pieces* of information ... =========
 : extract title etc. from $model('currentLemma').
 :)

(: ----------------- ... from AUTHORs ------------------- :)
declare
    %templates:wrap 
function app:AUTname($node as node(), $model as map(*)) {
         stool:rotateFormatName($model("currentAuthor")//tei:listPerson/tei:person[1]/tei:persName[1])
}; 

declare
function app:AUTarticleAuthor($node as node(), $model as map(*)) {
        <div style="text-align:right">
            {stool:rotateFormatName($model("currentAuthor")//tei:titleStmt//tei:author/tei:persName)}
        </div>
};

declare 
    %templates:wrap
function app:AUTworks($node as node(), $model as map(*), $lang as xs:string) {
        let $autId := $model('currentAuthor')/@xml:id/string()
        let $works := for $hit in collection($config:tei-works-root)//tei:TEI[contains(.//tei:titleStmt/tei:author/tei:persName/@ref, $autId)][tei:text/@type = ("work_monograph", "work_multivolume")]
            let $getAutString   := $hit//tei:titleStmt/tei:author/tei:persName/@ref/string()
            let $workTitle      := $hit//tei:sourceDesc//tei:title[1]/text()
            let $firstEd        := $hit//tei:sourceDesc//tei:date[@type = 'firstEd']
            let $thisEd         := $hit//tei:sourceDesc//tei:date[@type = 'thisEd']
            let $ed             := if ($thisEd) then $thisEd else $firstEd
            let $ref            := session:encode-url(xs:anyURI('work.html?wid=' || $hit/@xml:id/string()))
            order by $workTitle ascending
            return 
                    <p><a href="{$ref}"><span class="glyphicon glyphicon-file" aria-hidden="true"/>&#xA0;{$workTitle||'&#160;'}({$ed})</a></p>
        return $works
};

declare
function app:cited ($node as node(), $model as map(*), $lang as xs:string?, $aid as xs:string?, $lid as xs:string?) {
        <ul class="list-unstyled">
        {(:let $analyze-section  := if (request:get-parameter('aid', '')) then $model('currentAuthor')//tei:text else  $model('currentLemma')//tei:text:)
        let $analyze-section  := if (request:get-parameter('aid', '')) then doc($config:tei-authors-root || "/" || $aid || ".xml")//tei:text else  doc($config:tei-lemmata-root || "/" || $lid || ".xml")//tei:text
        let $cited :=
            for $entity in $analyze-section//tei:bibl[@sortKey]
                let $ansetzungsform := $entity/@sortKey/string()
                let $author         := app:formatName($entity//tei:persName[1])
                let $title          :=  if ($entity//tei:title/@key) then
                                            ($entity//tei:title/@key)[1]
                                        else ()
                let $display-title  :=  if ($author and $title) then
                                            concat($author, ': ', $title)
                                        else
                                            replace($ansetzungsform, '_', ': ')
                order by $entity/@sortKey
                return
                    if ($entity is ($analyze-section//tei:bibl[@sortKey][@sortKey = $entity/@sortKey])[1]) then
                            <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;cursor:pointer;" onclick="highlightSpanClassInText('hi_{translate($entity/@sortKey, ':', '_')}',this)">
                                <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$display-title} ({count($analyze-section//tei:bibl[@sortKey][@sortKey eq $entity/@sortKey])})
                            </li>
                        else ()
       return if ($cited) then $cited  else  <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;">no data</li> }
        </ul>
};

declare
function app:lemmata ($node as node(), $model as map(*), $lang as xs:string?, $aid as xs:string?, $lid as xs:string?) {
        <ul class="list-unstyled">
            {(:let $analyze-section  := if (request:get-parameter('aid', '')) then $model('currentAuthor')//tei:text else  $model('currentLemma')//tei:text:)
            let $analyze-section  := if (request:get-parameter('aid', '')) then doc($config:tei-authors-root || "/" || $aid || ".xml")//tei:text else  doc($config:tei-lemmata-root || "/" || $lid || ".xml")//tei:text
            let $lemmata :=
                for $entity in $analyze-section//tei:term
                    let $ansetzungsform := $entity/@key/string()
                    order by $entity/@key
                    return if ($entity is ($analyze-section//tei:term[(tokenize(string(@ref), ' '))[1] = (tokenize(string($entity/@ref), ' '))[1]])[1]) then
                                <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;cursor:pointer;" onclick="highlightSpanClassInText('hi_{translate((tokenize(string($entity/@ref), ' '))[1], ':', '_')}',this)">
                                     <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$ansetzungsform} ({count($analyze-section//tei:term[@ref eq $entity/@ref])})
                                </li>
                            else()
            return if ($lemmata) then $lemmata else  <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;">no data</li> }
        </ul>
};

declare
function app:persons ($node as node(), $model as map(*), $aid as xs:string?, $lid as xs:string?) {
        <ul class="list-unstyled">{
            let $analyze-section    :=  if (request:get-parameter('aid', '')) then
                                            doc($config:tei-authors-root || "/" || $aid || ".xml")//tei:text
                                        else
                                            doc($config:tei-lemmata-root || "/" || $lid || ".xml")//tei:text
            let $persons :=
                for $entity in $analyze-section//tei:persName[not(parent::tei:author)]
                    let $ansetzungsform := app:resolvePersname($entity)
                    order by $entity/@key
                    return
                        (:exclude author entity:)
                        if (substring($entity/@ref, 8,5) eq $analyze-section/ancestor::tei:TEI/@xml:id) then ()
                        else if ($entity is ($analyze-section//tei:persName[(tokenize(string(@ref), ' '))[1] = (tokenize(string($entity/@ref), ' '))[1]])[1]) then
                           <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial; cursor:pointer;" onclick="highlightSpanClassInText('hi_{translate((tokenize(string($entity/@ref), ' '))[1], ':', '_')}',this)">
                                <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$ansetzungsform} ({count($analyze-section//tei:persName[@ref eq $entity/@ref])})
                           </li>
                        else ()
            return if ($persons) then $persons else  <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;">no data</li>
        }</ul>
};

declare
function app:places ($node as node(), $model as map(*), $aid as xs:string?, $lid as xs:string?) {
        <ul class="list-unstyled">{
             let $analyze-section  := if (request:get-parameter('aid', '')) then doc($config:tei-authors-root || "/" || $aid || ".xml")//tei:text else  doc($config:tei-lemmata-root || "/" || $lid || ".xml")//tei:text
             let $places :=
                     for $entity in $analyze-section//tei:placeName
                        let $ansetzungsform := if ($entity/@key) then
                                                    xs:string($entity/@key)
                                              else
                                                    xs:string($entity)
                        order by $entity/@key
                        return if ($entity is ($analyze-section//tei:placeName[(tokenize(string(@ref), ' '))[1] = (tokenize(string($entity/@ref), ' '))[1]])[1]) then
                                   <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;cursor:pointer;" onclick="highlightSpanClassInText('hi_{translate((tokenize(string($entity/@ref), ' '))[1], ':', '_')}',this)">
                                        <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$ansetzungsform} ({count($analyze-section//tei:placeName[@ref = $entity/@ref])})
                                   </li>
                                else()
            return if ($places) then $places else  <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;">no data</li>
        }</ul>
};

(: ----------------- ... from LEMMAta ------------------- :)
 declare
function app:LEMtitle($node as node(), $model as map(*)) {
       $model('currentLemma')//tei:titleStmt/tei:title[@type='short']/text()
};
  
declare
    %public
function app:LEMentry($node as node(), $model as map(*), $lid as xs:string) {
    render:dispatch(doc($config:tei-lemmata-root || "/" || $lid || ".xml")//tei:body, "work")
};

(: ----------------- ... from NEWs ------------------- :)
declare 
function app:NEWsList($node as node(), $model as map(*), $lang as xs:string?) {
    let $image          := $model('currentNews')//tei:title[1]/tei:ref
    let $link           := <a href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$model('currentNews')/@xml:id/string()}</a>
    let $followTeaser   := <a href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}"><i18n:text key="more">mehr</i18n:text>&#32;&#32;<i class="fa fa-share"></i></a>
    let $title :=        if ($lang eq 'de') then <span style="text-decoration: none; color: #333333;">{$model('currentNews')//tei:title[@type='main'][@xml:lang='de']/string()}</span>
                    else if ($lang eq 'en') then <span style="text-decoration: none; color: #333333;">{$model('currentNews')//tei:title[@type='main'][@xml:lang='en']/string()}</span>
                    else if ($lang eq 'es') then <span style="text-decoration: none; color: #333333;">{$model('currentNews')//tei:title[@type='main'][@xml:lang='es']/string()}</span>
                    else ()
    let $sub :=          if ($lang eq 'de') then $model('currentNews')//tei:title[@type='sub'][@xml:lang='de']/string()
                    else if ($lang eq 'en') then $model('currentNews')//tei:title[@type='sub'][@xml:lang='en']/string()
                    else if ($lang eq 'es') then $model('currentNews')//tei:title[@type='sub'][@xml:lang='es']/string()
                    else ()     
                    
   let $teaser :=         if ($lang eq 'de')  then <p class="lead">{concat(substring($model('currentNews')//tei:div[@type='entry'][@xml:lang='de']/tei:p[1], 1 , 150), '&#32;...&#32;&#32;'), $followTeaser} </p>
                     else if ($lang eq 'en')  then <p class="lead">{concat(substring($model('currentNews')//tei:div[@type='entry'][@xml:lang='en']/tei:p[1], 1 , 150), '&#32;...&#32;&#32;'), $followTeaser} </p>
                     else if ($lang eq 'es')  then <p class="lead">{concat(substring($model('currentNews')//tei:div[@type='entry'][@xml:lang='es']/tei:p[1], 1 , 150), '&#32;...&#32;&#32;'), $followTeaser} </p>
                     else()
    let $date           := $model('currentNews')//tei:change[1]/@when/string() 
    let $output :=
       (:imageleft:)
        if ($image/@rendition='ImageLeft') then
            <div class="row"><hr/>
                <div class="col-md-4 hidden-sm hidden-xs">
                    <a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">
                        <img class="featurette-image img-circle img-responsive pull-left" src="{$image/@target}" style="max-height: 15em;"/>
                     </a>
                 </div>
                <div class="col-md-8 hidden-sm hidden-xs">
                     <h2>
                        <a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$title}</a>&#32;
                        <span class="text-muted">{$sub}</span>
                     </h2><br/><br/>
                    {$teaser}
                </div>
                <div class="col-sm-8 hidden-md hidden-lg hidden-xs">
                     <h2>
                        <a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$title}</a>&#32;
                        <span class="text-muted">{$sub}</span>
                     </h2><br/><br/>
                    {$teaser}
                </div>
                <div class="col-xs-12 hidden-lg hidden-sm hidden-md">
                     <h3>
                        <a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$title}</a>&#32;
                        <span class="text-muted">{$sub}</span>
                     </h3><br/><br/>
                    {$teaser}
                </div>
                <div class="col-sm-4 hidden-md hidden-lg hidden-xs">
                    <a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">
                        <img class="featurette-image img-circle img-responsive pull-right" src="{$image/@target}" style="max-height: 15em;"/>
                     </a>
                 </div>
            </div>
          
        (: image right:)
        else if ($image/@rendition='ImageRight') then
            <div class="row"><hr/>
                 <div class="col-md-8 hidden-sm hidden-xs">
                    <h2><a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$title}</a>&#32;
                         <span class="text-muted">{$sub}</span>
                     </h2><br/><br/>
                    {$teaser}
                 </div>
                 <div class="col-md-4 hidden-sm hidden-xs">
                 <a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">
                     <img class="featurette-image img-circle img-responsive pull-right" src="{$image/@target}" style="max-height: 15em;"/>
                 </a>
             </div>
             <div class="col-sm-8 hidden-md hidden-lg hidden-xs">
                    <h2><a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$title}</a>&#32;
                         <span class="text-muted">{$sub}</span>
                     </h2><br/><br/>
                    {$teaser}
                 </div>
                 <div class="col-xs-12 hidden-lg hidden-sm hidden-md">
                    <h3><a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$title}</a>&#32;
                         <span class="text-muted">{$sub}</span>
                     </h3><br/><br/>
                    {$teaser}
                 </div>
                 <div class="col-sm-4 hidden-md hidden-lg hidden-xs">
                 <a style="text-decoration: none;" href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">
                     <img class="featurette-image img-circle img-responsive pull-right" src="{$image/@target}" style="max-height: 15em;"/>
                 </a>
             </div>
         </div>
       else ()
       return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri())) 
};
    
declare
    %templates:wrap 
function app:NEWsEntry($node as node(), $model as map(*), $lang as xs:string) {
    let $image  :=  $model('currentNews')//tei:title[1]/tei:ref
    let $link   :=  <a href="{session:encode-url(xs:anyURI('newsEntry.html?nid=' || $model('currentNews')/@xml:id))}">{$model('currentNews')/@xml:id/string()}</a>
    let $title  :=  if ($lang eq 'de') then $model('currentNews')//tei:title[@type='main'][@xml:lang='de']/string()
                        else if ($lang eq 'en') then $model('currentNews')//tei:title[@type='main'][@xml:lang='en']/string()
                        else if ($lang eq 'es') then $model('currentNews')//tei:title[@type='main'][@xml:lang='es']/string()
                        else ()
    let $sub    :=  if ($lang eq 'de') then $model('currentNews')//tei:title[@type='sub'][@xml:lang='de']/string()
                        else if ($lang eq 'en') then $model('currentNews')//tei:title[@type='sub'][@xml:lang='en']/string()
                        else if ($lang eq 'es') then $model('currentNews')//tei:title[@type='sub'][@xml:lang='es']/string()
                        else ()
    let $date   :=  $model('currentNews')//tei:change[1]/@when/string()
    let $output :=
            <div>
                <div class="row">
                    <div class="col-md-6 col-md-offset-2 col-sm-7 hidden-xs">
                        <h2> 
                            <a href="news.html">
                                <i class="fa fa-reply"></i>&#32;&#32;<!--<i18n:text key="back">zurück</i18n:text>-->
                            </a>
                            {$title}&#32;
                            <span class="text-muted">{$sub}</span>
                        </h2>
                        <hr/>
                        </div>
                        <div class="col-xs-12 hidden-sm hidden-md hidden-lg">
                             <h3> 
                                <a href="news.html">
                                    <i class="fa fa-reply"></i>&#32;&#32;<!--<i18n:text key="back">zurück</i18n:text>-->
                                </a>
                               {$title}&#32;
                               <span class="text-muted">{$sub}</span>
                             </h3>
                        <hr/>
                        </div>
                        <div class="col-md-3 col-sm-5 hidden-xs">
                           <img class="img-responsive" src="{$image/@target}" style="margin:15px;"/>
                        </div>
                    </div>
                    <div class="row-fluid">
                    <div class="col-md-8 col-md-offset-2">
                       {local:NEWsBody($node, $model, $lang), $date}
                      <br/>
                    </div>
                </div>
            </div>
    return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri())) 
};

declare
function local:NEWsBody($node as node(), $model as map(*), $lang as xs:string) {
        let $doc := $model('currentNews')//tei:text
        let $parameters :=  <parameters>
                                <param name="exist:stop-on-warn" value="yes"/>
                                <param name="exist:stop-on-error" value="yes"/>
                            </parameters>
        return  
        if ($lang eq 'de')  then 
        transform:transform($doc//tei:div[@xml:lang='de'], doc(($config:app-root || "/resources/xsl/news.xsl")), $parameters)
        else if  ($lang eq 'en')  then 
        transform:transform($doc//tei:div[@xml:lang='en'], doc(($config:app-root || "/resources/xsl/news.xsl")), $parameters)
        else if  ($lang eq 'es')  then
        transform:transform($doc//tei:div[@xml:lang='es'], doc(($config:app-root || "/resources/xsl/news.xsl")), $parameters)
        else()
};

(: ----------------- ... from WORKING PAPERs ------------------- :)
declare
    %templates:wrap
function app:WPtitle ($node as node(), $model as map(*)) {
       <span style="text-align: justify;">{$model('currentWp')//tei:titleStmt/tei:title[1]/string()}</span>
};

declare
    %templates:wrap
function app:WPauthor ($node as node(), $model as map(*)) {
        stool:rotateFormatName($model('currentWp')/tei:teiHeader//tei:biblStruct/tei:monogr/tei:author/tei:persName)
};

declare
    %templates:wrap
function app:WPdate ($node as node(), $model as map(*)) {
        $model('currentWp')/tei:teiHeader//tei:biblStruct//tei:date[@type = 'firstEd']/string()
};

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:WPvol  ($node as node(), $model as map(*), $lang as xs:string?) {
       let $link := 'workingPaper.html?wpid=' || $model('currentWp')/@xml:id/string()
       let $vol := $model('currentWp')//tei:titleStmt/tei:title[@type='short']/string()
       return <h4><a  href="{$link}">{$vol}</a></h4>
};

declare
    %templates:wrap
function app:WPvolNoLink  ($node as node(), $model as map(*), $lang as xs:string?) {
       $model('currentWp')//tei:titleStmt/tei:title[@type='short']/string()     
};

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:WPimg ($node as node(), $model as map(*), $lang as xs:string?) {
    let $link := 'workingPaper.html?wpid=' || $model('currentWp')/@xml:id/string()
    let $img  := if ($model('currentWp')//tei:graphic/@url) then
                       <img style="border: 0.5px solid #E7E7E7; width:90%; height: auto;" src="{$model('currentWp')//tei:graphic/@url/string()}"/>
                 else ()
    return
       <a href="{$link}">{$img}</a>
};

declare
    %templates:wrap
function app:urn ($node as node(), $model as map(*)) {
    let $urn := $model('currentWp')//tei:teiHeader//tei:biblStruct/tei:ref[@type = 'url'][starts-with(., 'urn')]
    return
       <a href="{$config:urnresolver || $urn}" target="_blank">{ $urn }&#xA0;<span class="glyphicon glyphicon-new-window" aria-hidden="true"></span></a>
};

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:citation ($node as node(), $model as map(*), $lang as xs:string?) {
    let $urn := $model('currentWp')//tei:biblStruct/tei:ref[@type = 'url'][starts-with(., 'urn')]
    let $translate  :=  if ($lang = 'de') then
                            'Zitiervorschlag'
                        else if ($lang ='en') then
                            'Citation'
                        else
                            'Citación'
    let $citationsString := string-join(app:WPauthor($node,$model), ', ') || ' (' ||
                            app:WPdate($node,$model)   || '): ' ||
                            app:WPtitle($node,$model)  || ' - Salamanca Working Paper Series (ISSN 2509-5080) ' ||
                            $model('currentWp')//tei:titleStmt/tei:title[@type='short']/string() ||
                            '. ' || $urn || ' ('  ||
                            replace(current-date(),'(\d{4})-(\d{2})-(\d{2})([+].*)','$3.$2.$1') || ').'

    return
      <span>{$urn}&#xA0;&#xA0;<button type="button" class="btn btn-link"
                                      data-container="body" data-toggle="popover"
                                      data-placement="bottom" title="{$translate}: {$citationsString}"
                                      data-original-title="" data-content="{$citationsString}"><i style="margin-bottom: 6px" class="fa fa-question-circle"/></button></span>
};

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:WPpdf ($node as node(), $model as map(*), $lang as xs:string?) {
    let $link   := $model('currentWp')//tei:biblStruct/tei:ref[@type = 'url'][ends-with(., '.pdf')]/string()
    let $output :=
                    <a href="{$link}">
                        <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span>&#xA0;
                        <i18n:text key="download">herunterladen</i18n:text>
                    </a>
    return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))  
};

declare
    %templates:wrap
function app:WPabstract ($node as node(), $model as map(*)) {
       $model('currentWp')//tei:abstract/string()
};

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:WPshowSingle ($node as node(), $model as map(*), $lang as xs:string?) {
        let $work := <a href="workingPaper.html?wpid=' {$model('currentWp')/@xml:id/string()}">{$model('currentWp')/@xml:id/string()}</a> 
        return i18n:process($work, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri())) 
};

declare
    %templates:wrap
function app:WPkeywords ($node as node(), $model as map(*)) {
    string-join($model('currentWp')//tei:keywords/tei:term, ', ')
};    

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:WPlang ($node as node(), $model as map(*), $lang as xs:string) {
    let $language := $model('currentWp')/tei:teiHeader//tei:langUsage[1]
    let $result :=
             if ($language/tei:language/@ident = 'en') then <i18n:text key="english">Englisch</i18n:text>
        else if ($language/tei:language/@ident = 'es') then <i18n:text key="spanish">Spanisch</i18n:text>
        else if ($language/tei:language/@ident = 'de') then <i18n:text key="german">Deutsch</i18n:text>
        else ()
    return i18n:process($result, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri())) 
};

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:WPgoBack ($node as node(), $model as map(*), $lang as xs:string?) {
        let $link       := 'workingPapers.html'
        let $icon       := <i class="fa fa-reply"></i>
        let  $translate := <i18n:text key="back">zurück</i18n:text>
        return <a title="{$translate}" href="{$link}">{$icon}&#xA0;&#xA0;</a>
};

declare
    %templates:wrap
    %templates:default("lang", "en")
function app:WpEditiorial ($node as node(), $model as map(*), $lang as xs:string?) {
        let $more := <i18n:text key="more">Mehr</i18n:text>
        return 
            <a href="editorialWorkingPapers.html?">&#32;&#32;{i18n:process($more, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))}&#160;<i class="fa fa-share"></i></a>
};


(: ============== Functions for page workDetails.html ... ========= :)
declare
    %templates:wrap
function app:WRKtype($node as node(), $model as map(*), $lang as xs:string?) {
       let $type      :=  if ($model('currentWork')//tei:text[@type='work_multivolume']/string())  then <i18n:text key="multivolume">Mehrbandwerk</i18n:text> else ()
       let $translate := i18n:process($type, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
       return if ($model('currentWork')//tei:text[@type='work_multivolume']) then
                    ' ('|| $translate ||') '
              else ()
};

(:Ansetzungstitel= Normalisierung von v zu u ... :)
declare
function app:WRKtitleProper($node as node(), $model as map(*)) {
        $model('currentWork')/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@type = '245a']/string()   
};

(:Werktitel:)
declare
function app:WRKtitleMain($node as node(), $model as map(*)) {
        $model('currentWork')/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@type = 'main']/string()  
};

(:Zitiertitel:)
declare
function app:WRKtitleShort($node as node(), $model as map(*)) {
       $model('currentWork')/tei:teiHeader//tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@type = 'short']/string()
};

declare
function app:WRKtitle($node as node(), $model as map(*), $lang as xs:string?) {
    let $titleShort:=   if (app:WRKtitleShort($node, $model)) then 
                            <tr>
                                <td class="col-md-4">
                                    <i18n:text key="titleShort">Zitiertitel</i18n:text>:
                                </td>
                                <td class="col-md-8">
                                    {app:WRKtitleShort($node, $model)}
                                </td>
                           </tr>
                        else()
    let $titleProper := if (app:WRKtitleProper($node, $model)) then 
                            <tr>
                                <td class="col-md-4">
                                    <i18n:text key="titleProper">Ansetzungstitel</i18n:text>:
                                </td>
                                <td class="col-md-8">
                                    {app:WRKtitleProper($node, $model)}
                                </td>
                           </tr>
                        else 
                            <tr>
                                <td class="col-md-4">
                                    <i18n:text key="title">Titel</i18n:text>:
                                </td>
                                <td class="col-md-8">
                                    {app:WRKtitleMain($node, $model)}
                                </td>
                            </tr>
    let $output := ($titleShort, $titleProper)
    return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
};  

declare
function app:WRKdateOfOrigin($node as node(), $model as map(*), $lang as xs:string?, $wid as xs:string?) {
        let $output :=  if ($model('currentWork')//tei:text[@type = 'work_multivolume']) then
                            <tr>
                                <td class="col-md-4"><i18n:text key="periodOfOrigin">Erscheinungsverlauf</i18n:text>:</td>
                                <td class="col-md-8">
                                {app:WRKread($node, $model, $lang, $wid)}
                                </td>
                            </tr>
                        else
                            <tr>
                                <td class="col-md-4"><i18n:text key="dateOfOrigin">Erscheinungsjahr</i18n:text>:</td>
                                <td>
                                {  if ($model('currentWork')/tei:teiHeader//tei:sourceDesc//tei:date[@type = 'thisEd']) then
                                        $model('currentWork')/tei:teiHeader//tei:sourceDesc//tei:date[@type = 'thisEd']
                                 else
                                        $model('currentWork')/tei:teiHeader//tei:sourceDesc//tei:date[@type = 'firstEd']
                                }
                                </td>
                                <td class="col-md-8">
                                </td>
                            </tr>
        return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
};

declare
    %templates:wrap 
function app:WRKread ($node as node(), $model as map(*), $lang as xs:string?, $wid as xs:string?) {
        let $base   := $model('currentWork')
        let $status := $base//tei:revisionDesc/@status/string()
        let $books   := $base//tei:text[@type ='work_volume']
        let $output := for $item in $books
                            let $volId      := $item/@xml:id/string()
                            let $volNumber  := $item/@n/string()
                            let $sourceDesc  := doc($config:tei-works-root || "/" || $wid ||'_'|| $volId || '.xml')/tei:TEI//tei:fileDesc/tei:sourceDesc
                            let $firstEd    := $sourceDesc//tei:date[@type = 'firstEd']/@when/string()
                            let $thisEd     := $sourceDesc//tei:date[@type = 'thisEd']/@when/string()
                            let $date       := if ($thisEd) then $thisEd else $firstEd                                       
                            let $vol        := doc($config:data-root || "/" || $wid || '_nodeIndex.xml')//sal:node[@n=$volId]/sal:crumbtrail/a[last()]/@href/string()
                            return  if ($item is ($model('currentWork')//tei:text)[last()]) then
                                            <a class="{$status}" href="{if ($status = ("a_raw", "b_cleared", "c_hyph_proposed", "d_hyph_approved", "e_emended_unenriched", "f_enriched")) then 'javascript:' else $vol}">{concat($volNumber||': ', $date)}</a>
                                    else
                                        <span>
                                            <a class="{$status}" href="{if ($status = ("a_raw", "b_cleared", "c_hyph_proposed", "d_hyph_approved", "e_emended_unenriched", "f_enriched")) then 'javascript:' else $vol}">{concat($volNumber||': ', $date)}</a>{'&#xA0;-&#xA0;'}
                                        </span>  
        return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
};

(: Creates a HTML snippet containing bibliographical information about the digital edition of a work (as opposed to the 
 : bibliographical record of the original edition, see app:sourceBibliographicalRecord()).
 :)
declare
    %templates:wrap
function app:WRKdigitalEditionRecord($node as node(), $model as map(*), $lang as xs:string?, $wid as xs:string?) {
    
    let $teiHeader          := util:expand($model('currentWork'))//tei:teiHeader
    let $status             := $teiHeader//tei:revisionDesc/@status/string()
    
    let $workEditors := if ($status eq 'g_enriched_approved') then
        let $editorNames := for $ed in $teiHeader/tei:fileDesc/tei:titleStmt/tei:editor/tei:persName 
                                return concat($ed/tei:forename/string(), ' ', $ed/tei:surname/string())
        let $editorsString := string-join($editorNames, '; ')
        let $editors := 
        <tr>
            <td class="col-md-4">
                <i18n:text key="alphaEditors">Editors (in alphabetical order)</i18n:text>:
            </td>
            <td class="col-md-8">
                {$editorsString}
            </td>
        </tr>
        return $editors
    else ()
    
    let $seriesInfo := if ($status eq 'g_enriched_approved') then
        let $series :=
            <tr>
                <td class="col-md-4">
                    <i18n:text key="series">Series</i18n:text>:
                </td>
                <td class="col-md-8">
                    <i18n:text key="editionSeries">The School of Salamanca. A Digital Collection of Sources</i18n:text>
                </td>
            </tr>
        let $editorsNames  := for $ed in $teiHeader/tei:fileDesc/tei:seriesStmt/tei:editor/tei:persName
                              return concat($ed/tei:forename/string(), ' ', $ed/tei:surname/string())
        let $seriesEditors :=
            <tr>
                <td class="col-md-4">
                    <i18n:text key="editorsInChief">Editors of the Series</i18n:text>:
                </td>
                <td class="col-md-8">
                    {string-join($editorsNames, '; ')}
                </td>
            </tr>
        let $currentVolume := $teiHeader/tei:fileDesc/tei:seriesStmt/tei:biblScope/@n/string()
        let $volume :=
            <tr>
                <td class="col-md-4">
                    <i18n:text key="volume">Volume</i18n:text>:
                </td>
                <td class="col-md-8">
                    {$currentVolume}
                </td>
            </tr>
        let $digitalPubDate := i18n:convertDate($teiHeader/tei:fileDesc/tei:editionStmt/tei:edition/tei:date/@when/string(), $lang, 'verbose')
        let $digitalPublication :=
            <tr>
                <td class="col-md-4">
                    <i18n:text key="digitalPublication">Digital Publication</i18n:text>:
                </td>
                <td class="col-md-8">
                    {$digitalPubDate}
                </td>
            </tr>
        return ($series, $seriesEditors, $volume, $digitalPublication)
    else ()
    
    let $output :=
    <table class="borderless table table-hover">
        <tr>
            <td class="col-md-4"><i18n:text key="author">Autor</i18n:text>:</td>
            <td class="col-md-8">{app:WRKauthor($node, $model)}</td>
        </tr>
        {app:WRKtitle($node, $model, $lang)}
        {app:WRKdateOfOrigin($node, $model, $lang, $wid)}
        {$workEditors}
        {$seriesInfo}
    </table>
    
    return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
};

declare
    %templates:wrap 
function app:sourceBibliographicalRecord($node as node(), $model as map(*), $lang as xs:string?, $wid as xs:string?) {
  (: *** AW: Last minute new approach: Get workDetails data from rdf rather than from TEI/nodeIndex (shall we? *** :)
  (:
        let $metadata     := doc($config:rdf-root || '/' || $wid || '.rdf')
        let $debug1       := if ($config:debug = ("trace", "info")) then console:log("Retrieving $metadata//rdf:Description[@rdf:about = $reqResource]/rdfs:seeAlso[1]/@rdf:resource[contains(., '.html')]") else ()
        let $resolvedPath := string(($metadata//*[@rdf:about eq $reqResource]/rdfs:seeAlso[1]/@rdf:resource[contains(., ".html")])[1])

        for $item in $metadata/rdf:Description/@rdf:about[../rdf:type/@rdf:resource="http://purl.org/spar/doco/part"]
            let $textId := $item
            let $volNumber := 

  :)

        let $base               := util:expand($model('currentWork'))
        let $baseId             := $base/@xml:id
        let $status             := $base//tei:revisionDesc/@status/string()
        let $books              := $base//tei:text[@type ='work_volume' or @type ='work_monograph']

        for $item in $books(:[not(./preceding-sibling::tei:teiHeader[@n='test'])]:)
            let $textId         := $item/@xml:id/string()
            let $volNumber      := $item/@n/string()
            let $sourceDesc      := doc($config:tei-works-root || "/" || $wid || (if ($item/@type ='work_volume') then concat('_', $textId) else ()) || '.xml')//tei:sourceDesc
            let $title          := $sourceDesc//tei:title[@type ='245a']/text()
            let $volNumberTitle := $sourceDesc//tei:title[@type ='volume']/text()
            let $printingPlace     := $sourceDesc//tei:pubPlace[@role = 'firstEd']/text()
            let $printingPlaceThis := $sourceDesc//tei:pubPlace[@role = 'thisEd']/text()
            let $printer        := app:rotateFormatName($sourceDesc//tei:publisher[@n="firstEd"]/tei:persName)
            let $printerThis    := app:rotateFormatName($sourceDesc//tei:publisher[@n="thisEd"]/tei:persName)   
            let $firstEd        := $sourceDesc//tei:date[@type eq 'firstEd']/@when/string()
            let $thisEd         := $sourceDesc//tei:date[@type eq 'thisEd']/@when/string()
            let $extent         := $sourceDesc//tei:extent
            let $master         := $base//tei:publicationStmt/tei:publisher/tei:orgName
  (:            let $material       := $base//tei:editionStmt/tei:edition:)
            let $nodeIndex      := doc($config:data-root || "/" || $wid || '_nodeIndex.xml')
            let $facs           := if ($nodeIndex//sal:node[@type eq "text"]) then
                                       $nodeIndex//sal:node[@type eq "text"][@n eq $textId]/following-sibling::sal:node[@type eq "pb"][1]/@n/string()
                                    else
                                       $nodeIndex//sal:node[@type eq "pb"][1]/@n/string()
  (:            let $img            :=  if ($nodeIndex//sal:node[@subtype eq "work_multivolume"]) then
                                        replace($facs,'facs_(W\d{4})-([A-Z])-(\d{4})',  'http://wwwuser.gwdg.de/~svsal/thumbs/$1/$2/$1-$2-$3.jpg')
                                    else
                                        replace($facs,'facs_(W\d{4})-(\d{4})',          'http://wwwuser.gwdg.de/~svsal/thumbs/$1/$1-$2.jpg'):)
            let $titlepage      := ($base//tei:titlePage[1]/following::tei:pb)[1]
            
            let $bookId       := if ($item/@type eq 'work_volume' and contains($baseId, '_Vol')) then concat(substring-before($baseId, '_Vol'), '_', $textId) 
                                 else if ($item/@type eq 'work_volume') then concat($baseId, '_', $textId)
                                 else $baseId
            let $img            := map:get(map:get(iiif:fetchResource($bookId), 'thumbnail'), '@id')
            let $debug := console:log("Todo: Fix image-url generating work-around in app:sourceBibliographicalRecord! image-source = '" || $img || "'.")
            (: if there are several providers of digitized material, we only state the first (i.e., main) one :)
            let $primaryEd      := if ($sourceDesc//tei:note[@xml:id="ownerOfPrimarySource"]/tei:ref[@type eq "institution" and @subtype eq "main"]) then 
                                       $sourceDesc//tei:note[@xml:id="ownerOfPrimarySource"]/tei:ref[@type eq "institution" and @subtype eq "main"][1]
                                   else $sourceDesc//tei:note[@xml:id="ownerOfPrimarySource"]/tei:ref[@type eq "institution"][1]
            let $catalogue      := if ($sourceDesc//tei:note[@xml:id="ownerOfPrimarySource"]/tei:ref[@type eq "catLink" and @subtype eq "main"]) then
                                       $sourceDesc//tei:note[@xml:id="ownerOfPrimarySource"]/tei:ref[@type eq "catLink" and @subtype eq "main"][1]/@target/string()
                                   else $sourceDesc//tei:note[@xml:id="ownerOfPrimarySource"]/tei:ref[@type eq "catLink"][1]/@target/string()
            
            let $extLink        := i18n:process(<i18n:text key="external Window">externer Link</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
            let $target         :=  if ($item/@type ='work_volume') then
                                        doc($config:data-root || "/" || $wid || '_nodeIndex.xml')//sal:node[@n=$textId]/sal:crumbtrail/a[last()]/@href/string()
                                    else
                                        concat('work.html?wid=', $wid)

            let $output         := 
                <div class="row"><hr/>
                    <div class="col-md-3">
                        <div>
                            <a class="{$status}" href="{if ($status = ("a_raw", "b_cleared", "c_hyph_proposed", "d_hyph_approved", "e_emended_unenriched", "f_enriched")) then 'javascript:' else $target}">
                                <img src="{$img}" class="img-responsive thumbnail" alt="Titlepage {functx:capitalize-first(substring($item/@type, 6))}"/>
                            </a>
                            <a class="btn btn-info button {$status}" href="{if ($status = ("a_raw", "b_cleared", "c_hyph_proposed", "d_hyph_approved", "e_emended_unenriched", "f_enriched")) then 'javascript:' else $target}">
                                <span class="glyphicon glyphicon-file"></span>{$config:nbsp || $config:nbsp}
                                {if ($item/@type = 'work_volume') then
                                    <span><i18n:text key="volume">Band</i18n:text>{$config:nbsp || $volNumber}</span>
                                 else
                                    <i18n:text key="readWork">Lesen</i18n:text>
                                }
                            </a>
                        </div>
                    </div>
                    <div class="col-md-1"/>
                    <div class="col-md-8" style="left: -0.7%">
                        <table class="borderless table table-hover">
                            <tbody>
                                {if ($item/@type ='work_volume') then
                                    <tr>
                                        <td class="col-md-4" style="line-height: 1.2"><i18n:text key="volTitle">Titel des Bandes/Reihe</i18n:text>:</td>
                                        <td class="col-md-8" style="line-height: 1.2">{$title}</td>
                                    </tr>
                                 else ()
                                }
                                {if ($item/@type ='work_volume') then
                                    <tr>
                                        <td class="col-md-4" style="line-height: 1.2"><i18n:text key="volNo">Bandnummer</i18n:text>:</td>
                                        <td class="col-md-8" style="line-height: 1.2">{$volNumberTitle}</td>
                                        </tr>
                                 else ()
                                } 
                                {if ($printingPlaceThis) then
                                    <tr>
                                        <td class="col-md-4" style="line-height: 1.2"><i18n:text key="imprintWRK">Impressum</i18n:text>:</td>
                                        <td class="col-md-8" style="line-height: 1.2">{$printingPlaceThis || $config:nbsp}: {$printerThis},{$config:nbsp || $thisEd}</td>
                                    </tr>
                                 else ()}
                              <tr>
                                    <td class="col-md-4" style="line-height: 1.2"><i18n:text key="imprintWRK">Impressum [Erstausgabe]</i18n:text>:</td>
                                    <td class="col-md-8" style="line-height: 1.2">{$printingPlace || $config:nbsp}: {$printer},{$config:nbsp || $firstEd}</td>
                              </tr>
                              <tr>
                                    <td class="col-md-4" style="line-height: 1.2"><i18n:text key="extent">Umfang, Format</i18n:text>:</td>
                                    <td class="col-md-8" style="line-height: 1.2">{$extent}</td>
                              </tr>
                              <tr>
                                <td class="col-md-4" style="line-height: 1.2"><i18n:text key="language">Sprache</i18n:text>:</td>
                                    <td class="col-md-8" style="line-height: 1.2">
                                        {
                                             if ($item/@xml:lang = 'la') then <i18n:text key="latin">Latein</i18n:text>
                                        else if ($item/@xml:lang = 'es') then <i18n:text key="spanish">Spanisch</i18n:text>
                                        else ()
                                        }
                                    </td>
                              </tr>
                              <tr>
                                    <td class="col-md-4" style="line-height: 1.2"><i18n:text key="ownerMaster">Digital Master</i18n:text>:</td>
                                    <td class="col-md-8" style="line-height: 1.2">{$master}</td>
                              </tr>
                              <tr>
                                    <td class="col-md-4" style="line-height: 1.2"><i18n:text key="ownerPrimaryEd">Digitalisierungsvorlage</i18n:text>:</td>
                                    <td class="col-md-8" style="line-height: 1.2">{$primaryEd}</td>
                              </tr>
                              <tr>
                                    <td class="col-md-4" style="line-height: 1.2"><i18n:text key="catLink">Katalogisat der Vorlage</i18n:text>:</td>
                                    <td class="col-md-8" style="line-height: 1.2">{if ($catalogue) then <a  href="{$catalogue}" title="{$extLink}" target="_blank">{($catalogue || '&#32;')} <span class="glyphicon glyphicon-new-window"></span></a> else ()}</td>
                              </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
                (: the following may be added once the proper information is avaliable:
                <tr>
                                    <td class="col-md-4" style="line-height: 1.2"><i18n:text key="material">Material</i18n:text>:</td>
                                    <td class="col-md-8" style="line-height: 1.2">{$material}</td>
                </tr>:)
        order by $volNumber ascending
        return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
}; 
        
(: Combined title on work.html in left box :)
declare
    %templates:wrap
function app:WRKcombined($node as node(), $model as map(*), $wid as xs:string?) {
        let $path           :=  doc($config:tei-works-root || "/" || $wid || ".xml")
        let $author         :=  string-join($path//tei:biblStruct/tei:monogr/tei:author/tei:persName/tei:surname, ', ')
        let $title          :=  $path//tei:biblStruct/tei:monogr/tei:title[@type = 'short']
        let $thisEd         :=  $path//tei:pubPlace[@role = 'thisEd']
        let $firstEd        :=  $path//tei:pubPlace[@role = 'firstEd']
        let $publisher      :=  if ($thisEd) then
                                    $path//tei:imprint/tei:publisher[@n = 'thisEd']/tei:persName[1]/tei:surname
                                else
                                    $path//tei:imprint/tei:publisher[@n = 'firstEd']/tei:persName[1]/tei:surname
        let $place          :=  if ($thisEd) then
                                    $thisEd
                                else
                                    $firstEd
        let $year           :=  if ($thisEd) then 
                                    $path//tei:date[@type = 'thisEd']/@when/string() 
                                else
                                    $path//tei:date[@type = 'firstEd']/@when/string()
        let $pubDetails     :=  $place || '&#32;'||": " || $publisher || ", " || $year
            return ($author||':  '||$title||'. '||$pubDetails||'.') 
};  

(: Jump from work.html to corresponding work_volume in workDatails.html :) (:FIXME:)
declare
function app:WRKdetailsCurrent($node as node(), $model as map(*), $lang as xs:string?) {
(:
    let $multiRoot := replace($model('currentWork')/@xml:id, '(W\d{4})(_Vol\d{2})', '$1')
    return if ($model("currentWork")//tei:text[@type='work_volume']) then <a class="btn btn-info" href="{session:encode-url(xs:anyURI('workDetails.html?wid=' || $multiRoot))||'#'||$model('currentWork')/tei:text/@xml:id}"><span class="glyphicon glyphicon-file"></span>{'&#32;' ||i18n:process(<i18n:text key="details">Details</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri())) 
    ||'&#32;'||i18n:process(<i18n:text key="volume">Band</i18n:text>, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))        || '&#32;' ||$model("currentWork")//tei:text[@type='work_volume']/@n/string()}</a>
    else
:) 
        let $output :=
        <a class="btn btn-link" href="workDetails.html?wid={request:get-parameter('wid', '')}"><!--<i class="fa fa-info-circle">--><i class="fa fa-file-text-o"></i>&#32; <i18n:text key="details">Katalogeintrag</i18n:text></a>
        return $output (: i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", 'en') :)
};

(: ================= End Retrieve single pieces of information ======== :)


(: ================= GUI Elements ================= :)

(: ------ Construct Highlighting Boxes ------
 : TODO:
 : - group bibls, and hightlight them fully
 :)
declare
    %templates:default('startnodeId', 'none')
function app:WRKhiliteBox($node as node(), $model as map(*), $lang as xs:string, $startnodeId as xs:string, $wid as xs:string?, $q as xs:string?) {
      let $debug := console:log('$startnodeId = ' || $startnodeId)

      let $work := if (count($model('currentWork'))) then
                        $model('currentWork')
                   else
                        if ($wid) then
                            let $debug := console:log('Getting work based on $wid = ' || $config:tei-works-root || "/" || $wid || ".xml." )
                            return doc($config:tei-works-root || "/" || $wid || ".xml")
                        else ()
      let $debug := console:log('count($work) = ' || count($work))

      let $workId         := if ($wid) then
                                $wid
                            else
                                $work/@xml:id
      let $debug := console:log('$workId = ' || $workId)

      let $startnode := $work//*[@xml:id = $startnodeId]
      let $analyze-section  := if ($startnodeId ne 'none') then
                                   if (local-name($startnode) eq "milestone") then
                                        $startnode/ancestor::tei:div[1]
                                    else
                                        $startnode
                               else
                                   $work//tei:text
      let $debug := console:log('$analyze-section = ' || string($analyze-section/@xml:id))

      let $milestone        :=  if ($startnodeId ne 'none') then
                                    if (local-name($startnode) eq "milestone") then
                                        $startnode
                                    else
                                        false()
                                else
                                    false()

      let $analyze-section-title := if (not($milestone)) then
                                        app:sectionTitle($model('currentWork'), $analyze-section[1])
                                    else
                                        app:sectionTitle($model('currentWork'), $milestone)

      let $persons :=
          for $entity in $analyze-section//tei:persName[@ref][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])]
            let $ansetzungsform := app:resolvePersname($entity)
            order by $ansetzungsform
            return
                if ($entity is ($analyze-section//tei:persName[tokenize(string($entity/@ref), ' ')[1] = tokenize(string(@ref), ' ')[1]][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])[1]) then
                    <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;" onclick="highlightSpanClassInText('hi_{translate((tokenize(string($entity/@ref), ' '))[1], ':', '')}',this)"> 
                        <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$ansetzungsform} ({count($analyze-section//tei:persName[@ref][@ref = $entity/@ref][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])})
                    </li>
                else ()

        let $places :=
          for $entity in $analyze-section//tei:placeName[@ref][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])]
            let $ansetzungsform := if ($entity/@key) then string($entity/@key) else normalize-space(string-join($entity//text(), ''))
            order by $ansetzungsform
            return
                if ($entity is ($analyze-section//tei:placeName[(tokenize(string(@ref), ' '))[1] = (tokenize(string($entity/@ref), ' '))[1]][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])[1]) then
                    <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;" onclick="highlightSpanClassInText('hi_{translate((tokenize($entity/@ref, ' '))[1], ':', '')}',this)">
                        <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$ansetzungsform} ({count($analyze-section//tei:placeName[@ref][@ref = $entity/@ref][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])})
                    </li>
                else ()
                
        let $lemma :=
         for $entity in $analyze-section//tei:term[@ref][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])]
            let $ansetzungsform := string($entity/@key)
            order by $ansetzungsform
            return
                if ($entity is ($analyze-section//tei:term[@ref = $entity/@ref][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])[1]) then
                    <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;" onclick="highlightSpanClassInText('hi_{translate($entity/@ref, ':', '')}',this)">
                        <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$ansetzungsform} ({count($analyze-section//tei:term[@ref][@ref = $entity/@ref][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])})
                    </li>
                else ()

        let $titles :=
         for $entity in $analyze-section//tei:bibl[@sortKey][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])]
            let $ansetzungsform := string($entity/@sortKey)
            let $author         := app:formatName($entity//tei:persName)
            let $title          := if ($entity//tei:title/@key) then $entity//tei:title/@key else ()
            let $display-title  := if ($author and $title) then
                                       concat($author, ': ', $title)
                                   else
                                        translate($ansetzungsform, '_', ': ')
            order by $ansetzungsform
            return
                if ($entity is ($analyze-section//tei:bibl[@sortKey = $entity/@sortKey][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])[1]) then
                    <li class="menu-toggle" style="list-style-type: none; color:initial; background:initial; box-shadow:initial; border-radius:initial; padding: initial;" onclick="highlightSpanClassInText('hi_{translate($entity/@sortKey, ':', '')}',this)">
                        <span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>&#xA0;{$display-title} ({count($analyze-section//tei:bibl[@sortKey][@sortKey = $entity/@sortKey][not($milestone) or (. >> $milestone and . << $milestone/following::tei:milestone[1])])})
                    </li>
                else ()

  (: searchTermSection
        let $searchterm :=  if ($q and $model("results")) then
                            <section id="searchTermsSection">
                                <b><i18n:text key="searchterm">Suchbegriff(e)</i18n:text></b>
                                <ul id="searchTermsList">
                                    <li style="list-style-type: none;"><a class="highlighted" onclick="highlightSpanClassInText('searchterm',this)">{$q}: ({count($model("results"))})</a></li>
                                </ul>
                            </section>
                        else ()
:)

        let $output :=
        <div>
            <h5>{   if (not($startnodeId)) then
                        "To load entities, click on a refresh button in one of the section menu popups..."
                    else if (string($analyze-section/@xml:id) = 'completeWork') then
                        "Entities in the entire work:"
                    else 
                        "Entities in " || $analyze-section-title || ":"
                }
            </h5>

            {if ($startnodeId) then
                <section id="personsSection">
                    <b><i18n:text key="persons">Personen</i18n:text> ({count($persons)})</b>
                    <ul id="personsList">
                        {$persons}
                    </ul>
                </section>
            else ()}
            {if ($startnodeId) then
                <section id="placesSection">
                    <b><i18n:text key="places">Orte</i18n:text> ({count($places)})</b>
                    <ul id="placesList">
                        {$places}
                    </ul>
                </section>
            else ()}
            {if ($startnodeId) then
                <section id="lemmataSection">
                    <b><i18n:text key="lemmata">Lemma</i18n:text> ({count($lemma)})</b>
                    <ul id="lemmataList">
                        {$lemma}
                    </ul>
                </section>
            else ()}
            {if ($startnodeId) then
                <section id="citedSection">
                    <b><i18n:text key="cited">Zitiert</i18n:text> ({count( $titles)})</b>
                    <ul id="citedList">
                        {$titles}
                    </ul>
                </section>
            else ()}
        </div>
    return i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri()))
};

(: ------- Switch for original/edited text mode ------- :)
declare
function app:WRKtextModus($node as node(), $model as map(*), $lang as xs:string) {
    let $output :=
        <div>
            <section id="switchEditsSection">
                        <span class="original unsichtbar" style="cursor: pointer;">
                            <a class="btn btn-link" onclick="applyEditMode()"> <span class="glyphicon glyphicon-eye-open" aria-hidden="true"/>&#xA0;<i18n:text key="diplomatic">Diplomatisch</i18n:text></a>
                        </span>
                        <span class="edited" style="cursor: pointer;">
                            <a class="btn btn-link" onclick="applyOrigMode()"> <span class="glyphicon glyphicon-eye-open" aria-hidden="true"/>&#xA0;<i18n:text key="constituted">Konstituiert</i18n:text></a>
                        </span>
            </section>
        </div>
    return $output
};

(: ------- ToC (loading for works) --------
 : The links that prerendered tocs have cannot know anything about current search terms.
 : This function not only loads but also transforms them correspondingly if necessary.
 :) 
declare
function app:loadWRKpagination ($node as node(), $model as map (*), $wid as xs:string, $lang as xs:string, $q as xs:string?) {
    let $pagesFile  :=  doc($config:html-root || '/' || $wid || '/' || $wid || '_pages_' || $lang || '.html')
    let $xslSheet   := <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
                            <xsl:output omit-xml-declaration="yes" indent="yes"/>
                            <xsl:param name="q"/>
                            <xsl:template match="node()|@*" priority="2">
                                <xsl:copy>
                                    <xsl:apply-templates select="node()|@*"/>
                                </xsl:copy>
                            </xsl:template>
                            <xsl:template match="a/@href" priority="80">
                                <xsl:attribute name="href">
                                    <xsl:choose>
                                        <xsl:when test="starts-with(., '#')">
                                            <xsl:value-of select="."/>
                                        </xsl:when>
                                        <xsl:when test="contains(., '#')">
                                            <xsl:value-of select="replace(., '#', concat('&amp;q=', $q, '#'))"/>
                                        </xsl:when>                                                            
                                        <xsl:otherwise>
                                            <xsl:value-of select="concat(., '&amp;q=', $q)"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:attribute>
                            </xsl:template>
                        </xsl:stylesheet>
    let $parameters :=  <parameters>
                            <param name="exist:stop-on-warn" value="yes"/>
                            <param name="exist:stop-on-error" value="yes"/>
                            <param name="q" value="{$q}"/>
                        </parameters>
    return if ($q) then
                transform:transform($pagesFile, $xslSheet, $parameters)
            else
                $pagesFile
};


(: ------- ToC (loading for works) --------
 : The links that prerendered tocs have cannot know anything about current search terms.
 : This function not only loads but also transforms them correspondingly if necessary.
 :) 
declare
function app:WRKtoc ($node as node(), $model as map(*), $wid as xs:string, $q as xs:string?, $lang as xs:string?) {
    if ($q) then
        let $tocDoc := doc($config:html-root || '/' || $wid || '/' || $wid || '_toc.html')
        let $xslSheet       := <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
                                    <xsl:output omit-xml-declaration="yes" indent="yes"/>
                                    <xsl:param name="q"/>
                                    <xsl:template match="node()|@*" priority="2">
                                        <xsl:copy>
                                            <xsl:apply-templates select="node()|@*"/>
                                        </xsl:copy>
                                    </xsl:template>
                                    <xsl:template match="a/@href" priority="80">
                                        <xsl:attribute name="href">
                                            <xsl:choose>
                                                <xsl:when test="starts-with(., '#')">
                                                    <xsl:value-of select="."/>
                                                </xsl:when>
                                                <xsl:when test="contains(., '#')">
                                                    <xsl:value-of select="replace(., '#', concat('&amp;q=', $q, '#'))"/>
                                                </xsl:when>                                                            
                                                <xsl:otherwise>
                                                    <xsl:value-of select="concat(., '&amp;q=', $q)"/>
                                                </xsl:otherwise>
                                            </xsl:choose>
                                        </xsl:attribute>
                                    </xsl:template>
                                </xsl:stylesheet>
        let $parameters :=  <parameters>
                                <param name="exist:stop-on-warn" value="yes"/>
                                <param name="exist:stop-on-error" value="yes"/>
                                <param name="q" value="{$q}"/>
                            </parameters>
        return transform:transform($tocDoc, $xslSheet, $parameters)
     else
        doc($config:html-root || '/' || $wid || '/' || $wid || '_toc.html')
};

(: ------- ToCs (on-the-fly for pages other than work pages) -------- :) 
declare
    %public
function app:AUTtoc($node as node(), $model as map(*)) {
    <div>
        { local:print-sectionsAUT($model("currentAuthor")//tei:text/*/(tei:div)) }
    </div>
};

declare
    %private
function local:print-sectionsAUT($sections as element()*) {
    if ($sections) then
        <ul class="toc tocStyle">
        {
            for $section in $sections
            let $aid:= $section/ancestor::tei:TEI/@xml:id
            let $id := 'author.html?aid='||$aid ||'#'|| $section/tei:head/parent::tei:div[1]/@xml:id
            return
                <li class="tocStyle">
                    <a href="{$id}">{ $section/tei:head/text() }</a>
                    { app:print-sectionsAUT($section/(tei:div)) }
                </li>
        }
        </ul>
    else
        ()
};

declare
    %public
function app:LEMtoc($node as node(), $model as map(*)) {
    <div>
        { local:print-sectionsLEM($model("currentLemma")//tei:text/*/(tei:div)) }
    </div>
};

declare
    %private
function local:print-sectionsLEM($sections as element()*) {
    if ($sections) then
        <ul class="toc tocStyle">
        {
            for $section in $sections
            let $lid:= $section/ancestor::tei:TEI/@xml:id
            let $id := 'lemma.html?lid='||$lid ||'#'|| $section/tei:head/parent::tei:div[1]/@xml:id
            return
                <li class="tocStyle">
                    <a href="{$id}">{ $section/tei:head/text() }</a>
                    { app:print-sectionsLEM($section/(tei:div)) }
                </li>
        }
       </ul>
    else
        ()
};

declare
function app:tocGuidelines($node as node(), $model as map(*), $lang as xs:string) {
        let $parameters :=  <parameters>
                                            <param name="exist:stop-on-warn" value="yes"/>
                                            <param name="exist:stop-on-error" value="yes"/>
                                             <param name="modus" value="toc" />
                                        </parameters>
        return  if ($lang eq 'de')  then
            transform:transform(doc($config:app-root || "/resources/files/W_Head_general.xml")/tei:TEI//tei:div[@xml:id='guidelines-de'], doc(($config:app-root || "/resources/xsl/guidelines.xsl")), $parameters)
        else if  ($lang eq 'en')  then 
            transform:transform(doc($config:app-root || "/resources/files/W_Head_general.xml")/tei:TEI//tei:div[@xml:id='guidelines-en'], doc(($config:app-root || "/resources/xsl/guidelines.xsl")), $parameters)
        else if  ($lang eq 'es')  then
            transform:transform(doc($config:app-root || "/resources/files/W_Head_general.xml")/tei:TEI//tei:div[@xml:id='guidelines-es'], doc(($config:app-root || "/resources/xsl/guidelines.xsl")), $parameters)
        else()
};
 
(: -------------- work navigation bar ------------- :)
declare
    %templates:default
function app:guiWRK($node as node(), $model as map(*), $lang as xs:string, $wid as xs:string*, $q as xs:string?) as element() {    
    let $downloadXML     :=  app:downloadXML($node, $model, $lang)
    let $downloadTXTorig :=  app:downloadTXT($node, $model, 'orig', $lang)
    let $downloadTXTedit :=  app:downloadTXT($node, $model, 'edit', $lang)
    let $downloadRDF     :=  app:downloadRDF($node, $model, $lang)
    let $downloadCorpus  :=  app:downloadCorpusXML($node, $model, $lang)
    let $name            :=  app:WRKcombined($node, $model, $wid)
    let $top             :=  'work.html?wid=' || $wid
    let $output := 
        
        <div class="container">
            <div class="navbar navbar-white navbar-fixed-top" style="z-index:1; margin-top: 10px">
                <div class="container">
                    <div class="row-fluid" style="margin-top: 0.9%;">
                        <h4 style="margin-top: 5px;" class="pull-left messengers">
                       <!--                                                       title="{$name}"> -->
                       <!-- style="margin-top: 6px; margin-left: 40px"                           > -->
                            <a href="{$top}" title="{concat('(Go to top of)&#x0A;', $name)}"><!-- &#xA0; -->
                                {substring($name, 1, 30)||' ...'}
                            </a>
                        </h4>
                    </div>
                    <div class="row-fluid">
                        <div class="btn-toolbar pull-left">
                            <!--Paginator-Dropdown-->
                            <div class="btn-group">
                                <div class="dropdown">
                                 <button class="btn btn-link dropdown-toggle" type="button" id="dropdownMenu1" data-toggle="dropdown" aria-expanded="true">
                                    <i class="fa fa-anchor"></i>&#xA0;<i18n:text key="page">Seite</i18n:text>&#xA0;
                                    <span class="caret"></span>
                                 </button>
                                  <ul id="loadMeLast" class="dropdown-menu scrollable-menu" role="menu" aria-labelledby="dropdownMenu1"></ul>
                                    {app:loadWRKpagination($node, $model, $wid, $lang, $q)}
                                </div>
                            </div>
                            <!--TOC-Button-->
                            <div class="btn-group">
                                <button type="button" class="btn btn-link" data-toggle="modal" data-target="#myModal">
                                    <i class="fa fa-list-ul"aria-hidden="true"> </i>&#xA0;<i18n:text key="toc">Inhalt</i18n:text>
                                </button> 
                            <!--Details Button-->
                               {app:WRKdetailsCurrent($node, $model, $lang)}
                            </div>

                        <!-- Textmode, register, print and export functions, in largeish views -->
                            <!--Textmode Button-->
                            <div class="btn-group hidden-md hidden-sm hidden-xs">{app:WRKtextModus($node, $model, $lang)}</div>
                            <!-- Register Button-->
                            <div class="btn-group hidden-md hidden-sm hidden-xs btn btn-link disabled">
                                <span class="glyphicon glyphicon-stats text-muted" aria-hidden="true"/>&#xA0;<span class="text-muted"><i18n:text key="register">Register</i18n:text></span>
                            </div>
                            <!--Print-Button and Export-Dropdown-->
                            <!--<div class="btn-group hidden-md hidden-sm hidden-xs btn btn-link disabled">
                                <span class="glyphicon glyphicon-print text-muted" aria-hidden="true"/>&#xA0;<span class="text-muted"><i18n:text key="print">Drucken</i18n:text></span>
                            </div>-->
                            <div class="btn-group hidden-md hidden-sm hidden-xs">
                                <button type="button" class="btn btn-link dropdown-toggle" data-toggle="dropdown" aria-expanded="false">
                                    <span class="glyphicon glyphicon-download-alt" aria-hidden="true"/>&#xA0;<i18n:text key="export">Export</i18n:text>&#xA0;
                                    <span class="caret"/>
                                </button>
                                <ul class="dropdown-menu" role="menu">
                                    {$downloadXML}
                                    {$downloadTXTorig}
                                    {$downloadTXTedit}
                                    {$downloadRDF}
                                    {$downloadCorpus}
                                    <li class="disabled">
                                        <a><span class="glyphicon glyphicon-download-alt text-muted" aria-hidden="true"></span> <span class="text-muted"> PDF</span></a>
                                    </li>
                                    <li class="disabled">
                                        <a><span class="glyphicon glyphicon-download-alt text-muted" aria-hidden="true"></span> <span class="text-muted"> ebook</span></a>
                                    </li>
                                </ul>
                            </div>
                            <div class="btn-group">
                                <a class="btn btn-link" href="legal.html"><!--<i class="fa fa-info-circle">--><i class="fa fa-lock"></i>&#32; <i18n:text key="legalShort">Datenschutz&amp;Impressum</i18n:text></a>
                            </div>

                        <!-- Hamburger Icon, used in small views only: substitutes textmode, print and export functions -->
                            <!--<div class="btn-group hidden-lg hidden-md hidden-xs">
                                <button type="button" class="btn btn-link dropdown-toggle" data-toggle="dropdown" aria-expanded="false">
                                   <i class="fa fa-bars"></i>&#xA0;<i18n:text key="moreb">Mehr</i18n:text>
                                </button>
                                <ul class="dropdown-menu" role="menu">
                                    <li>
                                        <a onclick="applyEditMode()"><span class="glyphicon glyphicon-eye-open" aria-hidden="true"/>&#xA0;<i18n:text key="constituted">Konstituiert</i18n:text></a>
                                    </li>
                                    <li>
                                        <a  onclick="applyOrigMode()"><span class="glyphicon glyphicon-eye-open" aria-hidden="true"/>&#xA0;<i18n:text key="diplomatic">Diplomatisch</i18n:text></a>
                                    </li>
                                    <li> 
                                        <a><span class="glyphicon glyphicon-print text-muted" aria-hidden="true"/>&#xA0;<span class="text-muted"><i18n:text key="print">Drucken</i18n:text></span></a>
                                    </li>
                                    {$downloadXML}
                                    <li> 
                                        <a href="#"><span class="glyphicon glyphicon-download-alt text-muted" aria-hidden="true"/> <span class="text-muted"> PDF</span></a>
                                    </li>
                                </ul>
                            </div>-->
                        <!-- Hamburger Icon, used in small and eXtra-small views only: substitutes textmode, register, print and export functions -->
                            <div class="btn-group hidden-lg">
                                <button type="button" class="btn btn-link dropdown-toggle" data-toggle="dropdown" aria-expanded="false">
                                   <i class="fa fa-bars"></i>&#xA0;<i18n:text key="moreb">Mehr</i18n:text>
                                </button>
                                <ul class="dropdown-menu" role="menu">
                                    <li class="disabled"><a><span class="glyphicon glyphicon-stats text-muted" aria-hidden="true"/>&#xA0;<span class="text-muted"><i18n:text key="register">Register</i18n:text></span></a></li>
                                    <li><a onclick="applyEditMode()" class="btn original unsichtbar" style="cursor: pointer;"><span class="glyphicon glyphicon-eye-open" aria-hidden="true"/>&#xA0;<i18n:text key="constituted">Konstituiert</i18n:text></a></li>
                                    <li><a onclick="applyOrigMode()" class="btn edited" style="cursor: pointer;"><span class="glyphicon glyphicon-eye-open" aria-hidden="true"/>&#xA0;<i18n:text key="diplomatic">Diplomatisch</i18n:text></a></li>
                                    <!--<li class="disabled"><a><span class="glyphicon glyphicon-print text-muted" aria-hidden="true"/>&#xA0;<span class="text-muted"><i18n:text key="print">Drucken</i18n:text></span></a></li>-->
                                    {$downloadXML}
                                    {$downloadTXTorig}
                                    {$downloadTXTedit}
                                    {$downloadRDF}
                                    <li class="disabled"><a><span class="glyphicon glyphicon-download-alt text-muted" aria-hidden="true"/>&#xA0;<span class="text-muted">PDF</span></a></li>   
                                    <li class="disabled"><a><span class="glyphicon glyphicon-download-alt text-muted" aria-hidden="true"/>&#xA0;<span class="text-muted">ebook</span></a></li>   
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    return
        i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", "de")
};   

(:==== Common Functions ==== :)

(:get cover image:)
declare %templates:wrap
    function app:cover ($node as node(), $model as map(*), $lang) {
             if ($model('currentWp')//tei:graphic/@url)                 then <img style="width:90%; border-style: solid; border-width:0.1px; border-color:#E7E7E7; height: auto;" src="{$model('currentWp')//tei:graphic/@url}"/>
        else if ($model('currentAuthor')//tei:graphic/@type='noImage')  then <img src="http://placehold.it/250x350/777777/ffffff?text=No+image+available." class="center-block img-rounded img-responsive" />
        else if ($model('currentAuthor'))                               then <img src="{$config:webserver}/exist/rest/apps/salamanca/{$model('currentAuthor')//tei:titlePage//tei:graphic/@url}" class="center-block img-rounded img-responsive" />
        else()
            
};

(:download XML func:)
declare function app:downloadXML($node as node(), $model as map(*), $lang as xs:string) {
    let $wid      :=  request:get-parameter('wid', '')
    let $hoverTitle := i18n:process(<i18n:text key="downloadXML">Download TEI/XML source file</i18n:text>, $lang, '/db/apps/salamanca/data/i18n', 'en')
    let $download := 
             if ($wid)                    then <li><a title="{$hoverTitle}" href="{$config:teiserver || '/' || $wid}.xml"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"/>&#xA0;TEI/XML</a></li>
        else if ($model('currentLemma'))  then <li><a title="{$hoverTitle}" href="{$config:teiserver || '/' || $model('currentLemma')/@xml:id}.xml">TEI/XML</a></li>
        else if ($model('currentAuthor')) then <li><a title="{$hoverTitle}" href="{$config:teiserver || '/' || $model('currentAuthor')/@xml:id}.xml">TEI/XML</a></li>
        else()
    return $download
};

declare function app:downloadTXT($node as node(), $model as map(*), $mode as xs:string, $lang as xs:string) {
    let $wid      :=  request:get-parameter('wid', '')
    let $hoverTitleEdit := i18n:process(<i18n:text key="downloadTXTEdit">Download as plaintext (constituted variant)</i18n:text>, $lang, '/db/apps/salamanca/data/i18n', 'en')
    let $hoverTitleOrig := i18n:process(<i18n:text key="downloadTXTOrig">Download as plaintext (diplomatic variant)</i18n:text>, $lang, '/db/apps/salamanca/data/i18n', 'en')
    
    let $download := 
             if ($wid and ($mode eq 'edit'))                    then <li><a title="{$hoverTitleEdit}" href="{$config:apiserver || '/txt/work.' || $wid ||'.edit'}"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"/>&#xA0;TXT (<i18n:text key="constituted">Constituted</i18n:text>)</a></li>
             else if ($wid and ($mode eq 'orig'))               then <li><a title="{$hoverTitleOrig}" href="{$config:apiserver || '/txt/work.' || $wid ||'.orig'}"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"/>&#xA0;TXT (<i18n:text key="diplomatic">Diplomatic</i18n:text>)</a></li>
        else()
    return i18n:process($download, $lang, '/db/apps/salamanca/data/i18n', 'en')
};

declare function app:downloadCorpusXML($node as node(), $model as map(*), $lang as xs:string) {
    let $hoverTitle := i18n:process(<i18n:text key="downloadCorpus">Download corpus of XML sources</i18n:text>, $lang, '/db/apps/salamanca/data/i18n', 'en')
    let $download   := <li><a title="{$hoverTitle}" href="{$config:teiserver ||'/sal-tei-corpus.zip'}"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"/> ZIP (XML Corpus)</a></li>
    return $download
};

declare function app:downloadRDF($node as node(), $model as map(*), $lang as xs:string) {
    let $wid      :=  request:get-parameter('wid', '')
    let $hoverTitle := i18n:process(<i18n:text key="downloadRDF">Download RDF/XML data for this work</i18n:text>, $lang, '/db/apps/salamanca/data/i18n', 'en')
    let $download := 
             if ($wid)                    then <li><a title="{$hoverTitle}" href="{$config:dataserver || '/works.' || $wid}.rdf"><span class="glyphicon glyphicon-download-alt" aria-hidden="true"/>&#xA0;RDF/XML</a></li>
        else if ($model('currentLemma'))  then <li><a title="{$hoverTitle}" href="{$config:dataserver || '/lemmata.' || $model('currentLemma')/@xml:id}.rdf">RDF/XML</a></li>
        else if ($model('currentAuthor')) then <li><a title="{$hoverTitle}" href="{$config:dataserver || '/authors.' || $model('currentAuthor')/@xml:id}.rdf">RDF/XML</a></li>
        else()
    return $download
};

       
declare function app:scaleImg($node as node(), $model as map(*), $wid as xs:string) {
             if ($wid eq 'W0001') then  'height: 3868, width:  2519'   
        else if ($wid eq 'W0002') then  'height: 2319, width:  1589'   
        else if ($wid eq 'W0003') then  'height: 3464, width:  2395' 
        else if ($wid eq 'W0004') then  'height: 4725, width:  3370' 
        else if ($wid eq 'W0005') then  'height: 3467, width:  2422' 
        else if ($wid eq 'W0006') then  'height: 5524, width:  3408' 
        else if ($wid eq 'W0007') then  'height: 2332, width:  1746' 
        else if ($wid eq 'W0008') then  'height: 3365, width:  2237' 
        else if ($wid eq 'W0010') then  'height: 3409, width:  2313' 
        else if ($wid eq 'W0011') then  'height: 4000, width:  2883' 
        else if ($wid eq 'W0012') then  'height: 3285, width:  2109' 
        else if ($wid eq 'W0013') then  'height: 1994, width:  1297' 
        else if ($wid eq 'W0014') then  'height: 1759, width:  1196' 
        else if ($wid eq 'W0015') then  'height: 1634, width:  1080'  
        else if ($wid eq 'W0039') then  'height: 2244, width:  1536' 
        else if ($wid eq 'W0078') then  'height: 1881, width:  1192' 
        else if ($wid eq 'W0092') then  'height: 4366, width:  2896' 
        else if ($wid eq 'W0114') then  'height: 2601, width:  1674' 
        else ()
};

(: legal declarations :)

declare function app:legalDisclaimer ($node as node(), $model as map(*), $lang as xs:string?) {
    let $disclaimerText := i18n:process(<i18n:text key="legalDisclaimer"/>, $lang, '/db/apps/salamanca/data/i18n', 'en')
    return if ($disclaimerText) then 
        <div style="margin-bottom:1em;border:1px solid gray;border-radius:5px;padding:0.5em;">
            <span>{$disclaimerText}</span>
        </div>
        else ()
};

declare function app:privDecl ($node as node(), $model as map(*), $lang as xs:string?) {
    let $declfile   := doc($config:data-root || "/i18n/privacy_decl.xml")
    let $decltext   := "div-privdecl-de"
    let $html       := render:dispatch($declfile//tei:div[@xml:id = $decltext], "html")
    return if (count($html)) then
        <div id="privDecl" class="help">
            {$html}
        </div>
    else ()
};

declare function app:imprint ($node as node(), $model as map(*), $lang as xs:string?) {
    let $declfile   := doc($config:data-root || "/i18n/imprint.xml")
    let $decltext   := "div-imprint-de"
    let $html       := render:dispatch($declfile//tei:div[@xml:id = $decltext], "html")
    return if (count($html)) then
        <div id="imprint" class="help">
            {$html}
        </div>
    else ()
};
