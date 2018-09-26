xquery version "3.1";

(:~ 
 : Sphinx-client XQuery executable
 : This file contains the sphinx api interface.
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
import module namespace sphinx      = "http://salamanca.school/ns/sphinx"          at "modules/sphinx.xql";

declare option output:media-type "text/html";
declare option output:method "xhtml";
declare option output:indent "no";

let $mode   := request:get-parameter('mode',    'html')
let $wid    := request:get-parameter('wid',     'W0013')
let $field  := request:get-parameter('field',   'corpus')
let $q      := request:get-parameter('q',       '')
let $sort   := request:get-parameter('sort',    '2')
let $sortby := request:get-parameter('sortby',  'sphinx_fragment_number')
let $ranker := request:get-parameter('ranker',  '2')
let $offset := request:get-parameter('offset',  '0')
let $limit  := request:get-parameter('limit',   '10')
let $lang   := request:get-parameter('lang',    'en')

let $output :=  if ($mode = "load") then
                    sphinx:loadSnippets('all')
                else if ($mode = "details") then
                    sphinx:details($wid, $field, $q, $offset, $limit, $lang)
                else ()
return $output
