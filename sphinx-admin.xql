xquery version "3.1";

(:~ 
 : Sphinx-admin XQuery executable
 : This file calls sphinx api interface with admin/write privileges.
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
import module namespace admin       = "http://salamanca.school/ns/admin"           at "modules/admin.xql";

declare option output:media-type "text/html";
declare option output:method "xhtml";
declare option output:indent "no";

let $mode   := request:get-parameter('mode',    'html')
let $wid    := request:get-parameter('wid',     'W0013')

let $output :=  admin:sphinx-out(<div/>, map{ 'dummy':= 'dummy'}, $wid, $mode)
return $output
