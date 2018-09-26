xquery version "3.1";

(:~ 
 : Sphinx-out XQuery executable
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

declare namespace request           = "http://exist-db.org/xquery/request";
declare namespace output            = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace sal               = "http://salamanca.school/ns/sal";
declare namespace opensearch        = "http://a9.com/-/spec/opensearch/1.1/";
import module namespace httpclient  = "http://exist-db.org/xquery/httpclient";
import module namespace xmldb       = "http://exist-db.org/xquery/xmldb";
import module namespace admin       = "http://salamanca.school/ns/admin"           at "modules/admin.xql";
import module namespace config      = "http://salamanca.school/ns/config"          at "modules/config.xqm";
import module namespace i18n        = "http://exist-db.org/xquery/i18n"            at "modules/i18n.xql";
import module namespace sphinx      = "http://salamanca.school/ns/sphinx"          at "modules/sphinx.xql";

(: declare copy-namespaces no-preserve, inherit; :)

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

let $output :=  if ($mode = "load") then
                    sphinx:loadSnippets('*')
                else if ($mode = "details") then
                    sphinx:details($wid, $field, $q, $offset, $limit)
                else
                    admin:sphinx-out(<div/>, map{ 'dummy':= 'dummy'}, $wid, $mode)
return $output
