xquery version "3.1";

(:~ 
 : Config XQuery-Module
 : This module contains configuration values:
 :   - Running modes (debugging, staging etc.)
 :   - application name and contact email
 :   - Server-, domain- and pathnames
 :   - languages
 :   - available pages
 :   - misc. details
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
module namespace config         = "http://salamanca.school/ns/config";

declare namespace expath        = "http://expath.org/ns/pkg";
declare namespace repo          = "http://exist-db.org/xquery/repo";
declare namespace request       = "http://exist-db.org/xquery/request";
declare namespace session       = "http://exist-db.org/xquery/session";
declare namespace sm            = "http://exist-db.org/xquery/securitymanager";
declare namespace system        = "http://exist-db.org/xquery/system";
declare namespace tei           = "http://www.tei-c.org/ns/1.0";
declare namespace templates     = "http://exist-db.org/xquery/templates";
declare namespace util          = "http://exist-db.org/xquery/util";
declare namespace xhtml         = "http://www.w3.org/1999/xhtml";
import module namespace console = "http://exist-db.org/xquery/console";

(: ==================================================================================== :)
(: OOOooo... Configurable Section for the School of Salamanca Web-Application ...oooOOO :)

declare variable $config:debug        := "info";        (: possible values: trace, info, none :)
declare variable $config:instanceMode := "production";  (: possible values: staging, production :)
declare variable $config:contactEMail := "info.salamanca@adwmainz.de";
declare variable $config:appName      := "salamanca";

(: Configure Servers :)
declare variable $config:subdomains     := ("api", "blog", "data", "files", "id", "facs", "ldf", "search", "software", "tei", "www");
declare variable $config:apiserver      := $config:proto || "://api."    || $config:serverdomain;
declare variable $config:blogserver     := $config:proto || "://blog."   || $config:serverdomain;
declare variable $config:dataserver     := $config:proto || "://data."   || $config:serverdomain;
declare variable $config:idserver       := $config:proto || "://id."     || $config:serverdomain;
declare variable $config:imageserver    := $config:proto || "://facs."   || $config:serverdomain;
declare variable $config:resolveserver  := $config:proto || "://"        || $config:serverdomain;
declare variable $config:searchserver   := $config:proto || "://search." || $config:serverdomain;
declare variable $config:softwareserver := $config:proto || "://files."  || $config:serverdomain;
declare variable $config:teiserver      := $config:proto || "://tei."    || $config:serverdomain;
declare variable $config:webserver      := $config:proto || "://www."    || $config:serverdomain;

(: The opensearch-compliant data index (at the search server) :)
declare variable $config:sphinxRESTURL              := $config:searchserver || '/lemmatized';

(: The digilib image service :)
declare variable $config:digilibServerScaler        := 'https://c104-131.cloud.gwdg.de:8443/digilib/Scaler/IIIF/svsal!';
(: The digilib manifest service :)
declare variable $config:digilibServerManifester    := 'https://c104-131.cloud.gwdg.de:8443/digilib/Manifester/IIIF/svsal!';

declare variable $config:urnresolver                := 'http://nbn-resolving.de/urn/resolver.pl?';

declare variable $config:languages                  := ('en', 'de', 'es');
declare variable $config:defaultLang                := 'en';

declare variable $config:standardEntries            := ('index',
                                                        'search',
                                                        'contact',
                                                        'editorialWorkingPapers',
                                                        'guidelines',
                                                        'project',
                                                        'news',
                                                        'works',
                                                        'authors',
                                                        'dictionary',
                                                        'workingPapers'
                                                        );
declare variable $config:databaseEntries            := ('authors',
                                                        'works',
                                                        'workDetails',
                                                        'lemmata',
                                                        'workingPapers',
                                                        'news'
                                                       );

(: Configure html rendering :)
declare variable $config:chars_summary              := 75;      (: When marginal notes, section headings etc. have to be shortened, at which point? :)
declare variable $config:fragmentationDepthDefault  := 4;       (: At which level should xml to html fragmentation occur by default? :)

(: Configure search variables :)
declare variable $config:snippetLength              := 1200;    (: How long are snippets with highlighted search results on the search page? :)
declare variable $config:searchMultiModeLimit       := 5;       (: How many entries of each category are displayed when doing a search in "everything" mode? :)

(: Configure miscalleneous settings :)
declare variable $config:stats-limit    := 15;                  (: How many lemmata are evaluated on the stats page? :)
declare variable $config:lodFormat      := 'rdf';               (: What is the default data format returned by the LOD API? :)

(: OOOooo...                    End configurable section                      ...oooOOO :)
(: ==================================================================================== :)



(: Define special character entities :)
declare variable $config:nl             := "&#x0A;";            (: Newline #x0a (NL), #x0d (LF), #2029 paragraph separator :)
declare variable $config:quote          := "&#34;";
declare variable $config:zwsp           := "&#8203;";           (: A zero-width space :)
declare variable $config:nbsp           := "&#160;";            (: A non-breaking space :)
declare variable $config:tribullet      := "&#8227;";
declare variable $config:triangle       := "&#x25BA;";

declare variable $config:proto          := if (request:get-header('X-Forwarded-Proto') = "https") then "https" else request:get-scheme();
declare variable $config:serverdomain := 
    if (substring-before(request:get-header('X-Forwarded-Host'), ".") = $config:subdomains)
        then substring-after(request:get-header('X-Forwarded-Host'), ".")
    else if(request:get-header('X-Forwarded-Host'))
        then request:get-header('X-Forwarded-Host')
    else if(substring-before(request:get-server-name(), ".") = $config:subdomains)
        then substring-after(request:get-server-name(), ".")
    else
        let $alert := if ($config:debug = "trace") then console:log("Warning! Dynamic $config:serverdomain is uncertain, using servername " || request:get-server-name() || ".") else ()
        return request:get-server-name()
;

(:~ 
 : Determine the application root collection from the current module load path.
 :)
declare
variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

(:~
 : Path to the research data repository/package
 :)
declare
variable $config:salamanca-data-root := 
    let $modulePath := replace(system:get-module-load-path(), '^(xmldb:exist://)?(embedded-eXist-server)?(.+)$', '$3')
    return concat(substring-before($modulePath, "/" || $config:appName || "/"), "/" || $config:appName || "-data")
;

declare variable $config:temp           := concat($config:app-root, "/temp");
declare variable $config:toc-root       := concat($config:app-root, "/toc");

(:~
 : Paths to the TEI data repositories
 :)
declare variable $config:tei-root               := concat($config:salamanca-data-root, "/tei");
declare variable $config:tei-authors-root       := concat($config:salamanca-data-root, "/tei/authors");
declare variable $config:tei-lemmata-root       := concat($config:salamanca-data-root, "/tei/lemmata");
declare variable $config:tei-news-root          := concat($config:salamanca-data-root, "/tei/news");
declare variable $config:tei-workingpapers-root := concat($config:salamanca-data-root, "/tei/workingpapers");
declare variable $config:tei-works-root         := concat($config:salamanca-data-root, "/tei/works");
declare variable $config:tei-sub-roots          := ($config:tei-authors-root, $config:tei-lemmata-root, $config:tei-news-root, $config:tei-workingpapers-root, $config:tei-works-root);

declare variable $config:resources-root         := concat($config:app-root, "/resources");
declare variable $config:data-root              := concat($config:app-root, "/data");
declare variable $config:html-root              := concat($config:data-root, "/html");
declare variable $config:snippets-root          := concat($config:data-root, "/snippets");
declare variable $config:rdf-root               := concat($config:salamanca-data-root, "/rdf");
declare variable $config:iiif-root              := concat($config:salamanca-data-root, "/iiif");
declare variable $config:files-root             := concat($config:resources-root, "/files");

declare variable $config:repo-descriptor        := doc(concat($config:app-root, "/repo.xml"))/repo:meta;
declare variable $config:expath-descriptor      := doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package;

(:~
 : Resolve the given path using the current application context.
 : If the app resides in the file system,
 :)
declare
function config:resolve($relPath as xs:string) as element() {
    if (starts-with($config:app-root, "/db")) then
        doc(concat($config:app-root, "/", $relPath))
    else
        doc(concat("file://", $config:app-root, "/", $relPath))
};

(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare
function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare
function config:expath-descriptor() as element(expath:package) {
    $config:expath-descriptor
};
