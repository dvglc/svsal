xquery version "3.1";

(:~ 
 : i18n-templates XQuery-Module
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
module namespace intl="http://exist-db.org/xquery/i18n/templates";

(:~
 : i18n template functions. Integrates the i18n library module. Called from the templating framework.
 :)
import module namespace templates   = "http://exist-db.org/xquery/templates";
import module namespace i18n        = "http://exist-db.org/xquery/i18n"         at "i18n.xql";
import module namespace config      = "http://salamanca.school/ns/config"       at "config.xqm";

(:~
 : Template function: calls i18n:process on the child nodes of $node.
 : Template parameters:
 :      lang=de Language selection
 :      catalogues=relative path    Path to the i18n catalogue XML files inside database
 :)
declare function intl:translate($node as node(), $model as map(*), $lang as xs:string?, $catalogues as xs:string?) {
    let $cpath :=
        (: if path to catalogues is relative, resolve it relative to the app root :)
        if (starts-with($catalogues, "/")) then
            $catalogues
        else
            concat($config:app-root, "/", $catalogues)
    let $translated :=
        i18n:process($node/*, $lang, $cpath, ())
    return
        element { node-name($node) } {
            $node/@*,
            templates:process($translated, $model)
        }
};
