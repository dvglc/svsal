xquery version "3.0";

module namespace sphinx            = "http://www.salamanca.school/xquery/sphinx";
declare namespace sphinxNS         = "http://sphinxsearch.com";
declare namespace tei              = "http://www.tei-c.org/ns/1.0";
declare namespace sal              = "http://salamanca.adwmainz.de";
declare namespace opensearch       = "http://a9.com/-/spec/opensearch/1.1/";
declare namespace templates        = "http://exist-db.org/xquery/templates";
import module namespace config     = "http://www.salamanca.school/xquery/config"        at "xmldb:exist:///db/apps/salamanca/modules/config.xqm";
import module namespace i18n       = "http://exist-db.org/xquery/i18n"                  at "xmldb:exist:///db/apps/salamanca/modules/i18n.xqm";
import module namespace render-app = "http://www.salamanca.school/xquery/render-app"    at "xmldb:exist:///db/apps/salamanca/modules/render-app.xqm";
import module namespace console    = "http://exist-db.org/xquery/console";
import module namespace hc         = "http://expath.org/ns/http-client";
import module namespace request    = "http://exist-db.org/xquery/request";
import module namespace session    = "http://exist-db.org/xquery/session";
import module namespace util       = "http://exist-db.org/xquery/util";
import module namespace validation = "http://exist-db.org/xquery/validation";

declare copy-namespaces no-preserve, inherit;

(:
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option    output:method "xml";
:)

(: REST endpoints for Sphinx based Salamanca index:

Perform search request [GET] - http://search.salamanca.school/lemmatized/search
Extract keywords from query [GET] - http://search.salamanca.school/lemmatized/keywords
Hightlight given snippets [POST] - http://search.salamanca.school/lemmatized/excerpts

Response format is Open Search based XML - @see http://www.opensearch.org/Home and http://search.salamanca.school/lemmatized
:)

declare variable $sphinx:schema  :=
    <sphinx:schema>
        <sphinx:attr  name="sphinx_docid"           type="int" />
        <sphinx:attr  name="sphinx_work"            type="string" />
        <sphinx:attr  name="sphinx_work_type"       type="string" />
        <sphinx:attr  name="sphinx_author"          type="string" />
        <sphinx:attr  name="sphinx_authorid"        type="string" />
        <sphinx:attr  name="sphinx_title"           type="string" />
        <sphinx:attr  name="sphinx_year"            type="string" />
        <sphinx:attr  name="sphinx_hit_type"        type="string" />
        <sphinx:attr  name="sphinx_hit_id"          type="string" />
        <sphinx:attr  name="sphinx_hit_language"    type="string" />
        <sphinx:attr  name="sphinx_html_path"       type="string" />
        <sphinx:attr  name="sphinx_fragment_path"   type="string" />
        <sphinx:attr  name="sphinx_fragment_number" type="int" />

        <sphinx:field  name="sphinx_work"            type="string" />
        <sphinx:field  name="sphinx_work_type"       type="string" />
        <sphinx:field  name="sphinx_author"          type="string" />
        <sphinx:field  name="sphinx_authorid"        type="string" />
        <sphinx:field  name="sphinx_title"           type="string" />
        <sphinx:field  name="sphinx_year"            type="string" />
        <sphinx:field  name="sphinx_hit_type"        type="string" />
        <sphinx:field  name="sphinx_hit_id"          type="string" />
        <sphinx:field  name="sphinx_hit_language"    type="string" />

        <sphinx:field   name="sphinx_description_orig"  attr="string" />
        <sphinx:field   name="sphinx_description_edit"  attr="string" />
    </sphinx:schema>;

(: ####====---- Helper Functions ----====#### :)

declare function sphinx:passLang($node as node(), $model as map(*), $lang as xs:string?) {
    <input type="hidden" name="lang" value="{request:get-parameter('lang', $lang)}"/>
};

(: ####====---- End Helper Functions ----====#### :)

declare function sphinx:buildSelect ($node as node(), $model as map(*), $lang as xs:string?) {
        (: To be included in $output once the dictionary is available:         
            <option value="dict" accesskey="8" title="i18n(dictDesc)">
                <i18n:text key="dictionary">Wörterbucheinträge</i18n:text>: <i18n:text key="fulltext">Volltext</i18n:text>
            </option>
            <option value="entries" accesskey="9" title="i18n(entriesDesc)">
                <i18n:text key="dictionary">Wörterbucheinträge</i18n:text>: <i18n:text key="headings">Überschriften</i18n:text>
            </option>                               :)
    let $output :=
        <select name="field" data-template="form-control" class="span12 form-control templates:form-control">
            <option value="everything" accesskey="1" title="i18n(everythingDesc)">
                <i18n:text key="global">Alle Datenquellen</i18n:text>
            </option>
            <option value="corpus" accesskey="2" title="i18n(corpusDesc)">
                <i18n:text key="corpus">Werke</i18n:text>: <i18n:text key="fulltext">Volltext</i18n:text>
            </option>
            <option value="headings" accesskey="3" title="i18n(headingsDesc)">
                <i18n:text key="corpus">Werke</i18n:text>: <i18n:text key="headings">Überschriften</i18n:text>
            </option>
            <option value="notes" accesskey="4" title="i18n(notesDesc)">
                <i18n:text key="corpus">Werke</i18n:text>: <i18n:text key="notes">Noten</i18n:text>
            </option>
            <option value="nonotes" accesskey="5" title="i18n(nonotesDesc)">
                <i18n:text key="corpus">Werke</i18n:text>: <i18n:text key="nonotes">ohne Noten</i18n:text>
            </option>
            <option value="wp" accesskey="a" title="i18n(wpDesc)">
                <i18n:text key="workingPapers">Working Papers</i18n:text>: <i18n:text key="WPMetadata">Abstract und Metadaten</i18n:text>
            </option>
        </select>
    return $output
};

declare %public
    %templates:wrap
    %templates:default ("field",  "everything")
    %templates:default ("offset", "0")
    %templates:default ("limit",  "10")
function sphinx:search ($context as node()*, $model as map(*), $q as xs:string?, $field as xs:string, $offset as xs:integer, $limit as xs:integer) {
    if ($q) then
        let $searchRequestHeaders   := <headers></headers>
        let $hits :=

(: **** Case 1: Search "everything" **** 
   **** We do several searches, showing the top 5 results in each category
:)
            if ($field eq 'everything') then
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on work id, as of late we also have a work_type attritute that we should start using),
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $groupingParameters         := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters           := "&amp;offset=" || $offset || "&amp;limit=" || $config:searchMultiModeLimit
                let $searchRequestWorks         := concat($config:sphinxRESTURL, "/search?q=", "%40%28sphinx_author%2Csphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), '%20%40sphinx_work%20%5EW0%2A%20', $groupingParameters, $pagingParameters)
                let $searchRequestDictEntries   := concat($config:sphinxRESTURL, "/search?q=", "%40%28sphinx_author%2Csphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), '%20%40sphinx_work%20%5EL%2A%20',  $groupingParameters, $pagingParameters)
                let $searchRequestWorkingPapers := concat($config:sphinxRESTURL, "/search?q=", "%40%28sphinx_author%2Csphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), '%20%40sphinx_work%20%5EWP%2A%20', $groupingParameters, $pagingParameters)

                let $debug1 := if ($config:debug = "trace") then console:log("Search Request for " || $q || " in Works: " || $searchRequestWorks || ".") else ()
                let $debug2 := if ($config:debug = "trace") then console:log("Search Request for " || $q || " in Dict: "  || $searchRequestDictEntries || ".") else ()
                let $debug3 := if ($config:debug = "trace") then console:log("Search Request for " || $q || " in WPs: "   || $searchRequestWorkingPapers || ".") else ()

                let $topWorks                   := <resp>{hc:send-request(<hc:request href="{$searchRequestWorks}" method="get"/>)}</resp>
                let $topDictEntries             := <resp>{hc:send-request(<hc:request href="{$searchRequestDictEntries}" method="get"/>)}</resp>
                let $topWorkingPapers           := <resp>{hc:send-request(<hc:request href="{$searchRequestWorkingPapers}" method="get"/>)}</resp>
                let $debug4 :=  
                    if ($config:debug = "trace") then
                        (console:log("Search requests returned " || count($topWorks//item) || "/" || count($topDictEntries//item) || "/" || count($topWorkingPapers//item) || " results:"),
                         console:log("Response for Works Query: " || serialize($topWorks)),
                         console:log("Response for Dict Query: "  || serialize($topDictEntries)),
                         console:log("Response for WP Query: "    || serialize($topWorkingPapers))
                        )
                    else ()
                return 
                    <sal:results>
                        <sal:works>{$topWorks//rss}</sal:works>
                        <sal:dictEntries>{$topDictEntries//rss}</sal:dictEntries>
                        <sal:workingPapers>{$topWorkingPapers//rss}</sal:workingPapers>
                    </sal:results>

(: **** Case 2: Search "corpus" **** 
   **** We do a full corpus search, grouping results by work id.
:)
            else if ($field eq 'corpus') then                                                           (:   Work-Type      +   hit-type               +        Fulltext fields                   have         query term :)
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EW0%2A"
                let $addConditionParameters  := ""
                let $alsoSearchAuthorField   := "sphinx_author%2C"
                let $groupingParameters      := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp                    := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss

(: **** Case 2a: Search "corpus-nogroup" **** 
   **** We do a full corpus search, without grouping results.
:)
            else if ($field eq 'corpus-nogroup') then                                                           (:   Work-Type      +   hit-type               +        Fulltext fields                   have         query term :)
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EW0%2A"
                let $addConditionParameters  := ""
                let $alsoSearchAuthorField   := "sphinx_author%2C"
                let $groupingParameters      := ""
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss

(:  **** Case 3: Search "headings" **** 
    **** We do a full corpus search, with the additional condition that "@sphinx_hit_type head titlePart", grouping results by work id.
:)
            else if ($field eq 'headings') then
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                filter also by hit type,
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EW0%2A%20"
                let $addConditionParameters  := "%20%40sphinx_hit_type%20%3Dhead%20%7C%20%3DtitlePage"
                let $alsoSearchAuthorField   := ""
                let $groupingParameters      := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss
(:  **** Case 4: Search "notes" **** 
    **** We do a full corpus search, with the additional condition that "@sphinx_hit_type note", grouping results by work id.
:)
            else if ($field eq 'notes') then
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                filter also by hit type,
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EW0%2A%20"
                let $addConditionParameters  := "%20%40sphinx_hit_type%20%3Dnote"
                let $alsoSearchAuthorField   := ""
                let $groupingParameters      := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss

(:  **** Case 5: Search "nonotes" **** 
    **** We do a full corpus search, with the additional condition that "@sphinx_hit_type != note", grouping results by work id.
:)
            else if ($field eq 'nonotes') then
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                filter also by hit type,
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EW0%2A%20"
                let $addConditionParameters  := "%20%40sphinx_hit_type%20%3D%21note"
                let $alsoSearchAuthorField   := ""
                let $groupingParameters      := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss

(:  **** Cases that we don't even have yet **** 
            else if ($field eq 'persons') then
                let $pagingParameters       := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest  := concat($config:sphinxRESTURL, "/search?q=", concat('%40%28sphinx_author%2Csphinx_description_edit%2Csphinx_description_orig%29%20', encode-for-uri($q), '%20%40sphinx_hit_type%20persName%20%40sphinx_work%20%5EW0%2A%20'), $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss
            else if ($field eq 'places') then
                let $pagingParameters       := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest  := concat($config:sphinxRESTURL, "/search?q=", concat('%40%28sphinx_author%2Csphinx_description_edit%2Csphinx_description_orig%29%20', encode-for-uri($q), '%20%40sphinx_hit_type%20placeName%20%40sphinx_work%20%5EW0%2A%20'), $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss
            else if ($field eq 'lemmata') then
                let $pagingParameters       := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest  := concat($config:sphinxRESTURL, "/search?q=", concat('%40%28sphinx_author%2Csphinx_description_edit%2Csphinx_description_orig%29%20', encode-for-uri($q), '%20%40sphinx_hit_type%20term%20%40sphinx_work%20%5EW0%2A%20'), $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss
:)

(:  **** Case 8: Search "dict" (in dictionary) ****
    **** We do a full search on all @sphinx_work ^L* 
:)
            else if ($field eq 'dict') then                                                     (: Lemmata-Articles :)
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EL%2A%20"
                let $addConditionParameters  := ""
                let $alsoSearchAuthorField   := "sphinx_author%2C"
                let $groupingParameters      := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss

(:  **** Case 9: Search "entries" (i.e. in dictionary headings) ****
    **** We do a full search on all @sphinx_work ^L* with the additional condition that @sphinx_hit_type be 'head'
:)
            else if ($field eq 'entries') then
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                filter also by hit type,
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EL%2A%20"
                let $addConditionParameters  := "%20%40sphinx_hit_type%20%3Dhead"
                let $alsoSearchAuthorField   := ""
                let $groupingParameters      := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss

(:  **** Case A: Search "wp" ****
    **** We do a full search on all @sphinx_work ^WP* 
:)
            else if ($field eq 'wp') then                                                     (: Working Papers :)
            (: search for queryterm in sphinx_description_edit and ..._orig fields,
                filter by work type (for now, based on  work id, as of late we also have a work_type attritute that we should start using),
                filter also by hit type,
                group by work (so we don't the same document repeatedly),
                paginate results if necessary
            :)
                let $modeConditionParameters := "%20%40sphinx_work%20%5EWP%2A%20"
                let $addConditionParameters  := ""
                let $alsoSearchAuthorField   := "sphinx_author%2C"
                let $groupingParameters      := "&amp;groupby=sphinx_work&amp;groupfunc=4"
                let $pagingParameters        := "&amp;offset=" || $offset || "&amp;limit=" || $limit
                let $searchRequest           := concat($config:sphinxRESTURL, "/search?q=", "%40%28", $alsoSearchAuthorField, "sphinx_description_edit%2Csphinx_description_orig%29%20", encode-for-uri($q), $addConditionParameters, $modeConditionParameters, $groupingParameters, $pagingParameters)
                let $resp := <resp>{hc:send-request(<hc:request href="{$searchRequest}" method="get"/>)}</resp>
                return $resp//rss

            else()
        return map { "results": $hits }
    else ()
};

declare 
    %templates:default ("offset", "0")
    %templates:default ("limit", "10")
function sphinx:resultsLandingPage ($node as node(), $model as map(*), $q as xs:string?,  $field as xs:string?, 
                                        $offset as xs:integer?, $limit as xs:integer?, $sort as xs:integer?, $sortby as xs:string?, 
                                        $lang as xs:string) {
    
    let $results  := $model("results")
(:  **** CASE 1: Search was for "everything". ****
    **** We show the top 5 results in each category,
    **** along with an "all..." button that switches to a dedicated corpus search.
:)
    let $output := 
        if ($field eq "everything") then
            let $searchInfo := 
                <p id="searchInfo"><i18n:text key="searchFor">Search for</i18n:text>: {string-join($results/sal:works//word, ', ')}</p>
            (: Get Works ... :)
            let $worksLink :=           
                if (xs:integer($results/sal:works//opensearch:totalResults/text()) > $config:searchMultiModeLimit ) then
                    <span style="margin-left:7px;">
                        <a href="search.html?field=corpus&amp;q={encode-for-uri($q)}&amp;offset=0&amp;limit={$limit}"><i18n:text key="allResults">All</i18n:text>...</a>
                    </span>
                else ()
            let $worksList := 
                <div class="resultsSection">
                    <h4><i18n:text key="works">Works</i18n:text> ({$results/sal:works//opensearch:totalResults/text()})</h4>
                    <ol class="resultsList">{
                        for $item at $index in $results/sal:works//item
                            let $author := $item/author/text()
                            let $title := $item/title/text()
                            let $wid := $item/work/text()
                            let $numberOfHits := $item/sphinxNS:groupcount/text()
                            let $link :=  
                                if (contains($item/fragment_path/text(), "#")) then
                                    if ($item/fragment_path/text() eq '#No fragment discoverable!') then
                                        'work.html?wid=' || $wid || '&amp;q=' || encode-for-uri($q) (: workaround for avoiding hard http errors (TODO) :)
                                    else replace($item/fragment_path/text(), '#', '&amp;q=' || encode-for-uri($q) || '#')
                                else if (contains($item/fragment_path/text(), "?")) then
                                    $item/fragment_path/text() || '&amp;q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                                else
                                    $item/fragment_path/text() || '?q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                            let $detailsLink := 
                                <a class="toggleDetails" href="#details_{$wid}" data-target="#details_{$wid}" data-toggle="collapse">
                                    {$numberOfHits}&#xA0;<i18n:text key="hits">Fundstellen</i18n:text>&#xA0;<i class="fa fa-chevron-down"aria-hidden="true"></i>
                                </a>
                            let $detailHTML := sphinx:details($wid, $field, $q, 0, 10, $lang)
    
                            return 
                                <li class="lead">
                                    <a href="{$link}">{$author}: {$title}</a><br/>
                                    {$detailsLink}
                                    <div id="details_{$wid}" class="collapse resultsDetails">{$detailHTML}</div>
                                </li>
                      }</ol>
                      {$worksLink}
                  </div>
    
            (: Get Dictionary Entries ... :)
    (:        let $dictEntriesLink :=     if (xs:integer($results/sal:dictEntries//opensearch:totalResults/text()) > $config:searchMultiModeLimit ) then
                                            <span style="margin-left:7px;"><a href="search.html?field=dict&amp;q={encode-for-uri($q)}&amp;offset=0&amp;limit={$limit}"><i18n:text key="allResults">all</i18n:text>...</a></span>
                                        else ()
            let $dictEntriesList :=     <div class="resultsSection">
                                            <h4><i18n:text key="dictionaryEntries">Wörterbucheinträge</i18n:text> ({$results/sal:dictEntries//opensearch:totalResults/text()})</h4>
                                            <ol class="resultsList">{
                                                for $item at $index in $results/sal:dictEntries//item
                                                    let $author         := $item/author/text()
                                                    let $title          := $item/title/text()
                                                    let $wid            := $item/work/text()
                                                    let $numberOfHits   := $item/sphinxNS:groupcount/text()
                                                    let $link           :=  if (contains($item/fragment_path/text(), "#")) then
                                                                                replace($item/fragment_path/text(), '#', '&amp;q=' || encode-for-uri($q) || '#')
                                                                            else
                                                                                $item/fragment_path/text() || '&amp;q=' || encode-for-uri($q)    (\: this is the url to call the frg. in the webapp :\)
                                                    let $detailsLink    := <a class="toggleDetails" href="#details_{$wid}" data-target="#details_{$wid}" data-toggle="collapse">{$numberOfHits}&#xA0;<i18n:text key="hits">Fundstellen</i18n:text>&#xA0;<i class="fa fa-chevron-down"aria-hidden="true"></i></a>
                                                    let $detailHTML     := sphinx:details($wid, $field, $q, 0, 10, $lang)
    
                                                    return 
                                                                <li class="lead">
                                                                    <a href="{$link}">{$author}: {$title}</a><br/>
                                                                    {$detailsLink}
                                                                    <div id="details_{$wid}" class="collapse resultsDetails">{$detailHTML}</div>
                                                                </li>
                                            }</ol>
                                            {$dictEntriesLink}
                                        </div>:)
    
            (: Get Working Papers ... :)
            let $workingPapersLink :=   
                if (xs:integer($results/sal:workingPapers//opensearch:totalResults/text()) > $config:searchMultiModeLimit ) then
                    <span style="margin-left:7px;"><a href="search.html?field=wp&amp;q={encode-for-uri($q)}&amp;offset=0&amp;limit={$limit}"><i18n:text key="allResults">all</i18n:text>...</a></span>
                else ()
            let $workingPapersList :=   
                <div class="resultsSection">
                   <h4><i18n:text key="workingPapers">Working Papers</i18n:text> ({$results/sal:workingPapers//opensearch:totalResults/text()})</h4>
                   <ol class="resultsList">{
                        for $item at $index in $results/sal:workingPapers//item
                            let $author         := $item/author/text()
                            let $title          := $item/title/text()
                            let $wid            := $item/work/text()
                            let $numberOfHits   := $item/sphinxNS:groupcount/text()
                            let $link :=  
                                if (contains($item/fragment_path/text(), "#")) then
                                    replace($item/fragment_path/text(), '#', '&amp;q=' || encode-for-uri($q) || '#')
                                else if (contains($item/fragment_path/text(), "?")) then
                                    $item/fragment_path/text() || '&amp;q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                                else
                                    $item/fragment_path/text() || '?q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                            let $detailsLink    := 
                                <a class="toggleDetails" href="#details_{$wid}" data-target="#details_{$wid}" data-toggle="collapse">
                                    {$numberOfHits}&#xA0;<i18n:text key="hits">Fundstellen</i18n:text>&#xA0;<i class="fa fa-chevron-down"aria-hidden="true"></i>
                                </a>
                            let $detailHTML     := sphinx:details($wid, $field, $q, 0, 10, $lang)
    
                            return 
                                <li class="lead">
                                    <a href="{$link}">{$author}: {$title}</a><br/>
                                    {$detailsLink}
                                    <div id="details_{$wid}" class="collapse resultsDetails">{$detailHTML}</div>
                                </li>
                   }</ol>
                   {$workingPapersLink}
               </div>
            
            (: include {$dictEntriesList} once the dictionary is available :)
            return
                <div class="searchResults">
                    {$searchInfo}
                    {$worksList}
                    {$workingPapersList}
                </div>


(:  **** CASE 2: Search was after "corpus", "headings", "notes" or "nonotes" etc., i.e. in works. ****
    **** We show the paged results, grouped after work_id
    **** along with an "details" buttons that expand the tree structure of a single work
:)
    else if ($field = ("corpus", "headings", "notes", "nonotes")) then
        let $searchInfo :=  
            <p id="searchInfo"><i18n:text key="searchFor">Suche nach</i18n:text>: {string-join($results//word[not(. = ('notar', 'head', 'titlepage'))], ', ')}<br/>
              <i18n:text key="found">Gefunden</i18n:text>:{$config:nbsp}<strong>{$results//opensearch:totalResults/text()}{$config:nbsp}<i18n:text key="works">Werke</i18n:text>.</strong>{$config:nbsp}
              <i18n:text key="display">Anzeige</i18n:text>:{$config:nbsp}{xs:integer($offset) + 1}-{xs:integer($offset) + count($results//item)}
            </p>
        let $prevPageLink := 
            if (xs:integer($results//opensearch:startIndex/text()) > 1 ) then
                <span>
                    <a href="search.html?field={$field}&amp;q={$q}&amp;offset={$offset - $limit}&amp;limit={$limit}"  class="prevnext_majorList">
                        <i18n:text key="prevWorks">Vorige Werke</i18n:text>
                    </a>{$config:nbsp || $config:nbsp}
                </span>
            else ()
        let $nextPageLink := 
             if (xs:integer($results//opensearch:startIndex/text())+xs:integer($results//opensearch:itemsPerPage/text())-1 lt xs:integer($results//opensearch:totalResults/text())) then
                 <a href="search.html?field={$field}&amp;q={$q}&amp;offset={$offset + $limit}&amp;limit={$limit}" class="prevnext_majorList">
                     <i18n:text key="nextWorks">Nächste Werke</i18n:text>
                 </a>
             else ()
        let $worksList :=   
            <ul class="resultsList">{
                for $item at $index in $results//item
                    let $author         := $item/author/text()
                    let $title          := $item/title/text()
                    let $wid            := $item/work/text()
                    let $numberOfHits   := $item/sphinxNS:groupcount/text()
                    let $link :=  
                        if (contains($item/fragment_path/text(), "#")) then
                            replace($item/fragment_path/text(), '#', '&amp;q=' || encode-for-uri($q) || '#')
                        else if (contains($item/fragment_path/text(), "?")) then
                            $item/fragment_path/text() || '&amp;q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                        else
                            $item/fragment_path/text() || '?q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                    let $detailsLink    := 
                        <a class="toggleDetails" href="#details_{$wid}" data-target="#details_{$wid}" data-toggle="collapse">
                            {$numberOfHits}&#xA0;<i18n:text key="hits">Fundstellen</i18n:text>&#xA0;<i class="fa fa-chevron-down"aria-hidden="true"></i>
                        </a>
                    let $detailHTML := sphinx:details($wid, $field, $q, 0, 10, $lang)
                    return
                        <li>
                            <a href="{$link}">{$author}: {$title}</a><br/>
                            {$detailsLink}
                            <div id="details_{$wid}" class="collapse resultsDetails">{$detailHTML}</div>
                        </li>
            }</ul>
        return
            <div class="searchResults">
                {$searchInfo}
                <div>
                    {$prevPageLink, $nextPageLink}
                </div>
                <div class="resultsSection">
                    {$worksList}
                </div>
            </div>

(:  **** CASE 3: Search was after "dict" or "entries" etc., i.e. in dictionaries. ****
    **** We show the paged results, grouped after work_id
    **** along with an "details" buttons that expand the tree structure of a single work
:)
    else if ($field = ("dict", "entries")) then
        let $searchInfo :=  
            <p id="searchInfo"><i18n:text key="searchFor">Suche nach</i18n:text>: {string-join($results//word[not(string(.) eq 'head')], ', ')}<br/>
              <i18n:text key="found">Gefunden</i18n:text>:{$config:nbsp}<strong>{$results//opensearch:totalResults/text()}{$config:nbsp}<i18n:text key="dictionaryEntries">Wörterbucheinträge</i18n:text>.</strong>{$config:nbsp}
              <i18n:text key="display">Anzeige</i18n:text>:{$config:nbsp}{xs:integer($offset) + 1}-{xs:integer($offset) + count($results//item)}
            </p>
        let $prevPageLink := 
             if (xs:integer($results//opensearch:startIndex/text()) > 1 ) then
                <span><a href="search.html?field={$field}&amp;q={$q}&amp;offset={$offset - $limit}&amp;limit={$limit}"  class="prevnext_majorList"><i18n:text key="prevWorks">Vorige Werke</i18n:text></a>{$config:nbsp || $config:nbsp}</span>
             else ()
        let $nextPageLink := 
             if (xs:integer($results//opensearch:startIndex/text()) + xs:integer($results//opensearch:itemsPerPage/text()) - 1 
                 lt xs:integer($results//opensearch:totalResults/text())) then
                    <a href="search.html?field={$field}&amp;q={$q}&amp;offset={$offset + $limit}&amp;limit={$limit}" class="prevnext_majorList">
                        <i18n:text key="nextWorks">Nächste Werke</i18n:text>
                    </a>
             else ()
        let $entriesList :=  
            <ul class="resultsList">{
                for $item at $index in $results//item
                    let $author         := $item/author/text()
                    let $title          := $item/title/text()
                    let $wid            := $item/work/text()
                    let $numberOfHits   := $item/sphinxNS:groupcount/text()
                    let $link :=  
                        if (contains($item/fragment_path/text(), "#")) then
                            replace($item/fragment_path/text(), '#', '&amp;q=' || encode-for-uri($q) || '#')
                        else if (contains($item/fragment_path/text(), "?")) then
                            $item/fragment_path/text() || '&amp;q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                        else
                            $item/fragment_path/text() || '?q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                    let $detailsLink    := 
                        <a class="toggleDetails" href="#details_{$wid}" data-target="#details_{$wid}" data-toggle="collapse">
                            {$numberOfHits}&#xA0;<i18n:text key="hits">Fundstellen</i18n:text>&#xA0;<i class="fa fa-chevron-down"aria-hidden="true"></i>
                        </a>
                    let $detailHTML := sphinx:details($wid, $field, $q, 0, 10, $lang)
                    return
                        <li>
                            <a href="{$link}">{$title} ({$author})</a>
                            <br/>
                            {$detailsLink}
                            <div id="details_{$wid}" class="collapse resultsDetails">{$detailHTML}</div>
                        </li>
            }</ul>
        return
            <div class="searchResults">
                {$searchInfo}
                <div>
                    {$prevPageLink, $nextPageLink}
                </div>
                <div class="resultsSection">
                    {$entriesList}
                </div>
            </div>


(:  **** CASE 4: Search was after "wp", i.e. after meta-information of working papers. ****
    **** We show the paged results, grouped after work_id
    **** along with an "details" buttons that expand the tree structure of a single work
:)
    else if ($field eq "wp") then
        let $searchInfo :=  
            <p id="searchInfo"><i18n:text key="searchFor">Suche nach</i18n:text>: {string-join($results//word, ', ')}<br/>
              <i18n:text key="found">Gefunden</i18n:text>:{$config:nbsp}<strong>{$results//opensearch:totalResults/text()}{$config:nbsp}<i18n:text key="workingPapers">Working Papers</i18n:text>.</strong>{$config:nbsp}
              <i18n:text key="display">Anzeige</i18n:text>:{$config:nbsp}{xs:integer($offset) + 1}-{xs:integer($offset) + count($results//item)}
            </p>
        let $prevPageLink := 
            if (xs:integer($results//opensearch:startIndex/text()) > 1 ) then
                <span>
                    <a href="search.html?field={$field}&amp;q={$q}&amp;offset={$offset - $limit}&amp;limit={$limit}"  class="prevnext_majorList">
                        <i18n:text key="prevWorks">Vorige Werke</i18n:text>
                    </a>{$config:nbsp || $config:nbsp}
                </span>
            else ()
        let $nextPageLink := 
            if (xs:integer($results//opensearch:startIndex/text())+xs:integer($results//opensearch:itemsPerPage/text())-1 lt xs:integer($results//opensearch:totalResults/text())) then
                <a href="search.html?field={$field}&amp;q={$q}&amp;offset={$offset + $limit}&amp;limit={$limit}" class="prevnext_majorList">
                    <i18n:text key="nextWorks">Nächste Werke</i18n:text>
                </a>
            else ()
        let $workingPapersList :=   
            <ul class="resultsList">{
                for $item at $index in $results//item
                    let $author         := $item/author/text()
                    let $title          := $item/title/text()
                    let $wid            := $item/work/text()
                    let $numberOfHits   := $item/sphinxNS:groupcount/text()
                    let $link           :=  
                        if (contains($item/fragment_path/text(), "#")) then
                            replace($item/fragment_path/text(), '#', '&amp;q=' || encode-for-uri($q) || '#')
                        else if (contains($item/fragment_path/text(), "?")) then
                            $item/fragment_path/text() || '&amp;q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                        else
                            $item/fragment_path/text() || '?q=' || encode-for-uri($q)    (: this is the url to call the frg. in the webapp :)
                    let $detailsLink    := 
                        <a class="toggleDetails" href="#details_{$wid}" data-target="#details_{$wid}" data-toggle="collapse">
                            {$numberOfHits}&#xA0;<i18n:text key="hits">Fundstellen</i18n:text>&#xA0;<i class="fa fa-chevron-down"aria-hidden="true"></i>
                        </a>
                    let $detailHTML := sphinx:details($wid, $field, $q, 0, 10, $lang)
                    return
                        <li>
                            <a href="{$link}">{$author}: {$title}</a><br/>
                            {$detailsLink}
                            <div id="details_{$wid}" class="collapse resultsDetails">{$detailHTML}</div>
                        </li>
            }</ul>
        return
            <div class="searchResults">
                {$searchInfo}
                <div>
                    {$prevPageLink, $nextPageLink}
                </div>
                <div class="resultsSection">
                    {$workingPapersList}
                </div>
            </div>

    else()

    return $output (: i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri())) :)
};


declare function sphinx:keywords ($q as xs:string?) as xs:string {
    let $keywordsRequestHeaders := <headers></headers>
    let $keywordsRequest        := concat($config:sphinxRESTURL, "/keywords", "?q=", encode-for-uri($q))
    let $resp               := <resp>{hc:send-request(<hc:request href="{$keywordsRequest}" method="get"/>)}</resp>
    return string-join($resp//rss/channel//item/*:tokenized/text(), ' ')
};

(:
~ Requests highlighted snippet excerpts (to be shown in the search result landing page) from Sphinx.
:)
declare function sphinx:excerpts ($documents as node()*, $words as xs:string) as node()* {
    let $endpoint       := concat($config:sphinxRESTURL, "/excerpts")
(:    let $debug          := if ($config:debug = ("info", "trace")) then util:log("warn", "[SPHINX EXCERPTS] Excerpts needed for doc[0]: " || substring(normalize-space($documents/description_orig), 0, 150)) else ():)
    let $normalizedOrig := $documents/description_orig
    let $normalizedEdit := $documents/description_edit
    let $request    := 
        <hc:request method="post" http-version="1.0">
            <hc:multipart media-type="multipart/form-data" boundary="xyzBouNDarYxyz">
                <hc:header name="content-disposition" value='form-data; name="opts[limit]"'/>
                <hc:body media-type="text/plain">150</hc:body>
                <hc:header name="content-disposition" value='form-data; name="opts[html_strip_mode]"'/>
                <hc:body media-type="text/plain">strip</hc:body>
                <hc:header name="content-disposition" value='form-data; name="opts[query_mode]"'/>
                <hc:body media-type="text/plain">true</hc:body>
                <hc:header name="content-disposition" value='form-data; name="opts[around]"'/>
                <hc:body media-type="text/plain">7</hc:body>
                <hc:header name="content-disposition" value='form-data; name="words"'/>
                <hc:body media-type="text/plain">{$words}</hc:body>
                <hc:header name="content-disposition" value='form-data; name="docs[0]"'/>
                <hc:body media-type="text/xml">{$normalizedOrig}</hc:body>
                <hc:header name="content-disposition" value='form-data; name="docs[1]"'/>
                <hc:body media-type="text/xml">{$normalizedEdit}</hc:body>
            </hc:multipart>
        </hc:request>
(:    let $log        := if ($config:debug = ("info", "trace")) then util:log("warn", "[SPHINX EXCERPTS] POST request element: " || serialize($request)) else ():)
    let $debug      := if ($config:debug = "trace") then console:log("[SPHINX EXCERPTS] POST request element: " || serialize($request)) else ()
    let $resp       := <resp>{hc:send-request($request, $endpoint)}</resp>
(:    let $log        := if ($config:debug = ("info", "trace")) then util:log('warn', '[SPHINX EXCERPTS] POST response: ' || serialize($resp)) else ():)
    let $debug      := if ($config:debug = "trace") then console:log('[SPHINX EXCERPTS] POST response: ' || serialize($resp)) else ()
(:  TODO:   check encoding (and other stuff, too?) before parsing and returning $resp//rss.
            But the following (old) way of checking is wrong: 
    let $rspBody    :=  
        if ($resp//hc:body/@encoding = "Base64Encoded") then 
            if (validation:jaxp(util:base64-decode($resp/node()[not(self::hc:response)]), false())) then
                let $debug := 
                    if ($config:debug = "trace") then 
                        util:log('warn', '[SPHINX] INFO: Received wellformed Base64Encoded HTML from (Open)Sphinxsearch,' || 
                                         ' parsing HTML for output...') else ()
                return
                    parse-xml(util:base64-decode($resp/node()[not(self::hc:response)])) 
            else ()
        else $resp/node()[not(self::hc:response)]
:)
    let $rspBody   := $resp//rss
(:    let $log   :=  if ($config:debug = ("info", "trace")) then util:log("warn", "[SPHINX EXCERPTS] $rspBody: " || serialize($rspBody)) else ():)
    let $debug :=  if ($config:debug = "trace") then console:log("[SPHINX EXCERPTS] POST response body decodes to: " || (serialize($rspBody))) else ()
    return $rspBody
};

(:
~ Requests a highlighted document (e.g., an HTML fragment) from Sphinx.
:)
(: TODO DEBUG: for certain fragments, query words, ..., (Open)Sphinxsearch returns malformed HTML after highlighting; in these cases, we return nothing, 
    and app:displaySingleWork makes sure that a non-highlighted version of the (beginning of the) fragment 
    - this is certainly not ideal, but better than a server error shown to the user...
    example:
            ...
            <div class="section-title-body">
                <span class="section-title-text">COMMENTARIVS.</span>
            </div>
            ...
        is returned as:
            ...
            <div class="section-title-body">
                <span class="section-title-text">
                    <span class="hi" id="hi_3">COMMENTARIVS.</span>
            </div>
            ...
    :)
declare function sphinx:highlight($document as node()?, $words as xs:string) as node()* {
    let $endpoint   := concat($config:sphinxRESTURL, "/excerpts")
    let $request    := 
        <hc:request method="post" http-version="1.0">
            <hc:multipart media-type="multipart/form-data" boundary="xyzBouNDarYxyz">
                <hc:header name="content-disposition" value='form-data; name="opts[limit]"'/>
                <hc:body media-type="text/plain">0</hc:body>
                <hc:header name="content-disposition" value='form-data; name="opts[html_strip_mode]"'/>
                <hc:body media-type="text/plain">retain</hc:body>
                <hc:header name="content-disposition" value='form-data; name="opts[query_mode]"'/>
                <hc:body media-type="text/plain">true</hc:body>
                <hc:header name="content-disposition" value='form-data; name="words"'/>
                <hc:body media-type="text/plain">{$words}</hc:body>
                <hc:header name="content-disposition" value='form-data; name="docs[0]"'/>
                <hc:body media-type="text/xml">{$document}</hc:body>
            </hc:multipart>
        </hc:request>

    let $resp   := <resp>{hc:send-request($request, $endpoint)}</resp>
    let $rspBody   := $resp//rss
(:    let $log   :=  if ($config:debug = ("info", "trace")) then util:log("warn", "[SPHINX HIGHLIGHTING] $rspBody: " || serialize($rspBody)) else ():)
(:    let $debug :=  if ($config:debug = ("info", "trace")) then console:log("[SPHINX HIGHLIGHTING] POST response body decodes to: " || (serialize($rspBody))) else ():)
    return $rspBody
};

(: not available as parameters:
let $sort   := request:get-parameter('sort',    '2')
let $sortby := request:get-parameter('sortby',  'sphinx_fragment_number')
let $ranker := request:get-parameter('ranker',  '2')
:)
declare
     %templates:default ("field", "everything")
     %templates:default ("limit", 10)
     %templates:default ("offset", 0)
     %templates:default ("lang", "en")
function sphinx:details ($wid as xs:string, $field as xs:string, $q as xs:string, $offset as xs:integer, 
                             $limit as xs:integer, $lang as xs:string?) {
    let $detailsRequestHeaders  := <headers></headers>
    let $conditionParameters    := "@sphinx_work ^" || $wid
    let $alsoSearchAuthorField  := if ($field eq "corpus") then "sphinx_author," else ()
    let $addConditionParameters :=  
        if ($field = ("headings", "entries")) then
            $conditionParameters || " @sphinx_hit_type =head | =titlePage"
        else if ($field eq "notes") then
            $conditionParameters || " @sphinx_hit_type =note"
        else if ($field eq "nonotes") then
            $conditionParameters || " @sphinx_hit_type !note"
        else
            $conditionParameters
    let $groupingParameters := ""
    let $sortingParameters := "&amp;sort=2&amp;sortby=sphinx_fragment_number&amp;ranker=2"      (: sort=2 - SPH_SORT_ATTR_ASC rank=2 - SPH_RANK_NONE :)
    let $pagingParameters := "&amp;limit=" || $limit || "&amp;offset=" || $offset

    let $detailsRequest := 
        concat($config:sphinxRESTURL, "/search?q=",
                encode-for-uri("@(" || $alsoSearchAuthorField ||
                                "sphinx_description_edit,sphinx_description_orig) " || $q || $addConditionParameters),
                $sortingParameters,
                $pagingParameters)
(:    let $debug := util:log('warn', '[SPHINX] sphinx:details $detailsRequest=' || $detailsRequest):)
    let $resp := <resp>{hc:send-request(<hc:request href="{$detailsRequest}" method="get"/>)}</resp>
    let $details:= $resp//rss
    
    let $searchInfo :=  
        <p id="details_searchInfo">
            <span id="details_searchTerms">
                <i18n:text key="searchFor">Suche nach</i18n:text>: {string-join($details//word[not(lower-case(./text()) eq lower-case($wid))], ', ')}<br/>
            </span>
            <span id="details_totalHits">
                <i18n:text key="found">Gefunden</i18n:text>:{$config:nbsp}<strong>{$details//opensearch:totalResults/text()}{$config:nbsp}<i18n:text key="hits">Fundstellen</i18n:text>.</strong><br/>
            </span>
            <span id="details_displayRange">
                <h3><i18n:text key="display">Anzeige</i18n:text>:{$config:nbsp}{xs:integer($offset) + 1 || '-' || xs:integer($offset) + count($details//item)}</h3>
            </span>
        </p>
    let $prevDetailsPara        := "&amp;limit=" || $limit || "&amp;offset=" || xs:string(xs:integer($offset) - xs:integer($details//opensearch:itemsPerPage))
    let $nextDetailsPara        := "&amp;limit=" || $limit || "&amp;offset=" || xs:string(xs:integer($offset) + xs:integer($details//opensearch:itemsPerPage))
    (: offer sphinx:details() (via sphinx-client.xql) for the next/previous page of snippets: :)
    let $prevDetailsURL         := concat('sphinx-client.xql?mode=details&amp;q=',encode-for-uri($q), '&amp;wid=' || $wid || '&amp;sort=2&amp;sortby=sphinx_fragment_number&amp;ranker=2' , $prevDetailsPara)
    let $nextDetailsURL         := concat('sphinx-client.xql?mode=details&amp;q=',encode-for-uri($q), '&amp;wid=' || $wid || '&amp;sort=2&amp;sortby=sphinx_fragment_number&amp;ranker=2' , $nextDetailsPara)
    let $prevDetailsLink := 
        if (xs:integer($offset) > 1 ) then
            <a href="{$prevDetailsURL}" class="loadPrev"><i class="fa fa-chevron-left"></i>&#xA0;&#xA0;<i18n:text key="prev">Zurück</i18n:text>{$config:nbsp}|{$config:nbsp}</a>
        else ()
    let $nextDetailsLink := 
        if (xs:integer($offset) + xs:integer($details//opensearch:itemsPerPage) lt xs:integer($details//opensearch:totalResults)) then
            <a href="{$nextDetailsURL}" class="loadNext">{$config:nbsp}|{$config:nbsp}<i18n:text key="next">Weiter</i18n:text>&#xA0;&#xA0;<i class="fa fa-chevron-right"></i></a>
        else ()

    let $output :=
        <div id="detailsDiv"> <!-- id="details_{$wid}" class="collapse resultsDetails" -->
            <h3 class="text-center" id="details_displayRange">
               {$prevDetailsLink}{$config:nbsp}{xs:integer($offset) + 1 || '-' || xs:integer($offset) + count($details//item)}{$config:nbsp}{$nextDetailsLink}</h3>
               <div style="display:none;" class="spin100 text-center"> <i class="fa fa-spinner fa-spin"/></div>
            
            <table class="table table-hover borderless">
                {
                for $item at $detailindex in $details//item
                    let $hit_id         := $item/hit_id/text()
(:                    let $crumbtrail     := sphinx:addLangToCrumbtrail(<sal:crumbtrail>{sphinx:addQToCrumbtrail(doc($config:index-root || '/' || $wid || '_nodeIndex.xml')//sal:node[@n eq $hit_id]/sal:crumbtrail, $q)}</sal:crumbtrail>, $lang):)
                    let $crumbtrailRaw := doc($config:index-root || '/' || $wid || '_nodeIndex.xml')//sal:node[@n eq $hit_id]/sal:crumbtrail
                    let $crumbtrailI18n := i18n:addLabelsToCrumbtrail($crumbtrailRaw) (: this adds <i18n:text> labels, but does no processing :)
                    let $crumbtrail := sphinx:addQToCrumbtrail($crumbtrailI18n, $q)
(:    VERY old version:    let $bombtrail      := sphinx:addLangToCrumbtrail(                 sphinx:addQToCrumbtrail(doc($config:index-root || '/' || $wid || '_nodeIndex.xml')//sal:node[@n eq $hit_id]/sal:crumbtrail/a[last()], $q), $lang):)
(:                    let $bombtrail      := sphinx:addQToCrumbtrail(doc($config:index-root || '/' || $wid || '_nodeIndex.xml')//sal:node[@n eq $hit_id]/sal:crumbtrail/a[last()], $q):)
                    let $bombtrail := $crumbtrail/a[last()]

                    let $snippets :=  
                        <documents>
                            <!-- <description_orig> heute geändert -->
                                {$item/description_orig}
                            <!-- </description_orig> heute geändert -->
                            <!-- <description_edit> heute geändert -->
                                {$item/description_edit}
                            <!-- </description_edit> heute geändert -->
                        </documents>
                    let $excerpts       := sphinx:excerpts($snippets, $q)
                    let $description_orig    := $excerpts//item[1]/description 
                    let $description_edit    := $excerpts//item[2]/description
                    let $resultTextRaw :=
                        (: if there is a <span class="hi" id="..."> within the description, terms have been highlighted by sphinx:excerpts(): :)
                        if ($description_edit//span) then 
(:                            let $debug := util:log('warn', $wid || ' : ' || '1') return:)
                            $description_edit
                        else if ($description_orig//span) then 
(:                            let $debug := util:log('warn', $wid || ' : ' || '2') return:)
                            $description_orig
                        else if (string-length($item/description_edit) gt $config:snippetLength) then 
(:                            let $debug := util:log('warn', $wid || ' : ' || '3') return:)
                            substring($item/description_edit, 0, $config:snippetLength) || '...'
                        else 
(:                            let $debug := util:log('warn', $wid || ' : ' || '4') return:)
                            $item/description_edit/text()
                    let $resultText := replace($resultTextRaw, '\[.*?\]', '') (: do not show name IDs etc. in search results (although they *are* searchable) :)
                    let $statusInfo := $bombtrail/i18n:text/@key/string()

                    return
                        <tr>
                            <td>
                                <span class="lead" style="padding-bottom: 7px; font-family: 'Junicode', 'Cardo', 'Andron', 'Cabin', sans-serif;" title="{$statusInfo}">
                                    {$bombtrail}
                                </span>
                                <div class="crumbtrail">{$crumbtrail/node()}</div>
                                <div class="result__snippet" title="i18n({$statusInfo})">{ 
                                    sphinx:normalizeExcerpt($resultTextRaw)
                                }</div>
                            </td>
                        </tr>
            }</table>
            <div class="text-center">
                {$prevDetailsLink, xs:integer($offset) + 1 || '-' || xs:integer($offset) + count($details//item), $nextDetailsLink}<br/>
               <div style="display:none;" class="spin100"> <i class="fa fa-spinner fa-spin"/></div>
            </div>
        </div>

    return $output (: i18n:process($output, $lang, "/db/apps/salamanca/data/i18n", session:encode-url(request:get-uri())) :)
};

(: Remove name IDs etc. from search excerpts as displayed in the results overview :)
declare function sphinx:normalizeExcerpt($node as item()) {
    if ($node instance of xs:string) then replace($node, '\[.*?\]', '')
    else if ($node/self::text()) then replace($node, '\[.*?\]', '') 
    else if ($node/self::element()) then element {local-name($node)} {$node/@*, for $child in $node/node() return sphinx:normalizeExcerpt($child)}
    else ()
};


declare function sphinx:help ($node as node(), $model as map(*), $lang as xs:string?) {
    let $helpfile   := doc($config:data-root || "/i18n/search_help.xml")
    let $helptext   :=   
        if ($lang = "de") then "div_Suchhilfe_de"
        else if ($lang = "es") then "div_searchHelp_es"
        else "div_searchHelp_en"
    let $html       := render-app:dispatch($helpfile//tei:div[@xml:id eq $helptext], "html", ())
    return if (count($html)) then
        <div id="help" class="help">
            {sphinx:print-sectionsHelp($helpfile//tei:div[@xml:id eq $helptext]/tei:div, true())}
            {$html}
        </div>
    else ()
};


declare %private function sphinx:print-sectionsHelp($sections as element()*, $hide as xs:boolean?) {
    let $collapseClass := if ($hide) then "collapse" else ()
    return 
        if ($sections) then
            <div id="collapseTOC" class="{$collapseClass}"> <!-- class="collapse"  -->
                <div>   <!-- class="panel panel-default" -->
                    <ul class="toc tocStyle">
                    {
                        for $section in $sections
                            let $id := '#' || $section/@xml:id
                            return
                                <li class="tocStyle">
                                    <a href="{$id}">{ $section/tei:head/text() }</a>
                                    { sphinx:print-sectionsHelp($section/tei:div, false()) }
                                </li>
                    }
                    </ul>
                </div>
            </div>
        else
            ()
};


declare function sphinx:loadSnippets($wid as xs:string*) {
    let $todo             := collection($config:tei-root)//tei:TEI[tei:text/@type = ("work_multivolume", "work_monograph", "author_article", "lemma_article", "working_paper")]/@xml:id

(:    let $dbg := console:log('Todo: ' || string-join($todo, ', ')):)
    let $hits := for $work_id in $todo
                    for $hit in collection($config:snippets-root || '/' || $work_id)
                        return $hit

    return
                <sphinx:docset>
                    {$sphinx:schema}
                    {$hits}
                </sphinx:docset>
};



(: ####====---- New Approach: Render in xQuery instead of XSLT ----====#### :)

declare function sphinx:addQToCrumbtrail($node as node()*, $q as xs:string*) as item()* {
    typeswitch($node)
        case element(a) return
            let $qUri :=
                if (contains(string($node/@href), "#") and contains(string($node/@href), "?")) then
                    replace(string($node/@href), '#', '&amp;q=' || encode-for-uri($q) || '#')
                else if (contains(string($node/@href), "?")) then
                    string($node/@href) || '&amp;q=' || encode-for-uri($q)
                else
                    string($node/@href) || '?q=' || encode-for-uri($q)
            return element {'a'} {
                attribute {'href'} {$qUri},
                if ($node/@class) then $node/@class else (),
                $node/node()
            }
(:            <a href="{$qUri}">{$node/text()}</a>:)
        case element(sal:crumbtrail) return 
            <sal:crumbtrail>{local:passthruCrumbtrailQ($node, $q)}</sal:crumbtrail>
        case text() return $node
        default return local:passthruCrumbtrailQ($node, $q)
};

(: test-wise disabled since we are handling lang now with path components and it seems the following functions
   have not been called from anywhere anyway.
declare function sphinx:addLangToCrumbtrail($node as node()*, $lang as xs:string*) as item()* {
    typeswitch($node)
        case element(a) return
                <a href="{
                            if (contains(string($node/@href), "#")) then
                                replace(string($node/@href), '#', '&amp;lang=' || encode-for-uri($lang) || '#')
                            else
                                string($node/@href) || '&amp;lang=' || encode-for-uri($lang)
                        }">{$node/text()}</a>
        case text() return $node
        default return local:passthruCrumbtrailLang($node, $lang)
};

declare function local:passthruCrumbtrailLang($nodes as node()*, $lang as xs:string*) as item()* {
    for $node in $nodes/node() return sphinx:addLangToCrumbtrail($node, $lang)
};
:)

declare function local:passthruCrumbtrailQ($nodes as node()*, $q as xs:string*) as item()* {
    for $node in $nodes/node() return sphinx:addQToCrumbtrail($node, $q)
};
