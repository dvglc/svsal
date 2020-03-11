xquery version "3.0" encoding "UTF-8";

declare namespace xhtml="http://www.w3.org/1999/xhtml";

import module namespace app       = "http://www.salamanca.school/xquery/app"                       at "xmldb:exist:///db/apps/salamanca/modules/app.xqm";
import module namespace config    = "http://www.salamanca.school/xquery/config"                    at "xmldb:exist:///db/apps/salamanca/modules/config.xqm";
import module namespace gui    = "http://www.salamanca.school/xquery/gui"                    at "xmldb:exist:///db/apps/salamanca/modules/gui.xqm";
import module namespace i18n      = "http://exist-db.org/xquery/i18n/templates"  at "xmldb:exist:///db/apps/salamanca/modules/i18n-templates.xqm";
import module namespace iiif      = "http://www.salamanca.school/xquery/iiif"                      at "xmldb:exist:///db/apps/salamanca/modules/iiif.xqm";
import module namespace net       = "http://www.salamanca.school/xquery/net"                       at "xmldb:exist:///db/apps/salamanca/modules/net.xqm";
import module namespace sphinx    = "http://www.salamanca.school/xquery/sphinx"                    at "xmldb:exist:///db/apps/salamanca/modules/sphinx.xqm";
import module namespace templates = "http://exist-db.org/xquery/templates" ;
import module namespace request   = "http://exist-db.org/xquery/request";
import module namespace console   = "http://exist-db.org/xquery/console";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option exist:timeout "1800000"; (: 30 min :)

declare option output:method "html5";
declare option output:media-type "text/html";

(:~
~ Resolves (copies or transforms) an html (doc/element/..., but not attribute) node.
~:)
declare function local:resolve($node as node()) as node()? {
    typeswitch ($node)
        case document-node() return
            for $child in $node/node() return local:resolve($child)
        case element() return
            element {node-name($node)} {
                for $attr in $node/@* return local:resolve-attr($attr),
                for $child in $node/node() return local:resolve($child)
            }
        case comment() return ()
        default return 
            $node
};

(:~
~ Resolves (copies or transforms) an html attribute node.
~:)
declare function local:resolve-attr($node as node()) as node()? {
    if(starts-with($node, 'resources/')) then 
        attribute { node-name($node) } {
          $config:webserver || '/' || $node
        }
    else $node
};

let $config := map {
    $templates:CONFIG_APP_ROOT: $config:app-root
}

let $lookup := function($functionName as xs:string, $arity as xs:int) {
    try {
        function-lookup(xs:QName($functionName), $arity)
    } catch * {
        ()
    }
}

let $content := request:get-data()

let $processed := templates:apply($content, $lookup, (), $config)

let $debug:= console:log('Application-side error handler (view-error.xql): Request URI: ' || request:get-uri() 
                            || '. Effective URI: ' || request:get-effective-uri() || ' . Context path: ' || request:get-context-path() 
                            || ' . Language: ' || request:get-attribute('lang') || '. Error message: ' || request:get-attribute('error-message') || '.')

return local:resolve($processed)
    