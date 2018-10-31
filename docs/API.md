# The School of Salamanca - The Web Application, API Documentation

This is the technical documentation for the API of the web application "The School of Salamanca",
available at <https://github.com/digicademy/svsal> and online at <https://www.salamanca.school/>.
The general API is accessible at <https://api.salamanca.school/>.

<div style="font-style: italic; text-align: right">(Last edited: Andreas Wagner, 2018-10-31)</div>

## Services and formats

Under <https://api.salamanca.school>, we provide the following endpoints^[In the context of RESTful APIs, these endpoints respond to GET requests only, in other words, the resources are read-only.]:

* **/tei/** for [TEI P5](http://www.tei-c.org/release/doc/tei-p5-doc/en/html/index.html) xml (this is also being redirected to from <https://tei.salamanca.school/>)
* **/txt/** for plaintext
* **/rdf/** for linked data (in [rdf/xml](https://www.w3.org/TR/rdf11-primer/); this is also being redirected to from <https://data.salamanca.school/>)
* **/html/** for web views (this is also being redirected to from <https://www.salamanca.school/>)
* **/iiif/** for iiif [manifests](https://iiif.io/api/presentation/2.1/) and [images](https://iiif.io/api/image/2.1/)
* (in the future: pdf and ebook for ebook views)
* (also in the future, (some of) the endpoints will be enhanced with versioning/[memento](http://mementoweb.org/guide/howto/) negotiation)

These services are also accessible directly at <https://id.salamanca.school/>, where the actual service delivered is determined via [content negotiation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Content_negotiation) if the client signals to expect (via the [HTTP request's accept header](https://www.w3.org/Protocols/HTTP/HTRQ_Headers.html#z3)) the following mime types, or by requesting the respective file extension explicitly (file extensions having a higher priority than accept headers):

* `application/tei+xml` (recommended), `application/xml` or `text/xml` or the file ending `.xml` for TEI P5 xml
* `text/plain` or the file ending `.txt` for plaintext
* `application/rdf+xml` or the file ending `.rdf` for rdf/xml
* `application/xhtml+xml` (recommended) or `text/html` or the file ending `.html` for web views
* `image/jpeg` or the file ending `.jpg` for images
* `application/ld+json; profile=http://iiif.io/presentation/3/context.json` or the file ending `.mf.json` for iiif manifests

Taken without file extension and outside of a http exchange, urls at <https://id.salamanca.school/> are also used to represent the abstract entities that scholarly works or discourse concepts are.

## Parts of texts

All the endpoints follow a common scheme for identification of what part of the work will be exposed in the requested format:

In general the identificator is `{work}\[:{location}\]`, where the work must, and the location can be specified in more detail:

`work` is `{collection}.{id}[.{version}]`, e.g. `works.w0015`, `works.w0002.orig` or `lemma.l0020`. (Note that we yet have to use or accept lowercase ids, for the time being, it's "W0015" with a capital "W".) "version" refers to the distinction between the original/diplomatic text (requested with `orig`) and the edited/constituted variant (requested with `edit`) that is available in some formats (such as plaintext).

`location` can be either a page number, preceded by a 'p' (e.g. "p23", "pFOL3R"), or a section identifier in a hierarchical manner, e.g. "frontmatter.1", "5.1", "vol2.3.11" etc. In this scheme, volumes are prefixed with "vol", footnotes or marginal notes are prefixed with "n", and all other sections such as chapters, subchapters, paragraphs etc. are rendered with plain numbers. Pages are outside of the chapter hierarchy, but below the volume and front- and backmatter identifier, giving locations as "p53" (for a page in the body of a single-volume work) and "vol2.frontmatter.p1" (for a page in the frontmatter of a multi-volume work).

Here are some example identificators:

* <https://id.salamanca.school/works.W0013:vol1.1.1.n1>
* <https://id.salamanca.school/works.W0004:pFOL7V>
* <https://id.salamanca.school/works.W0013:vol2.frontmatter.p1>

(This way of identifying sections is inspired by the [Canonical Text Services](http://cite-architecture.github.io/ctsurn/overview/) specification, but diverges in some points, such as http instead of urn scheme and the eschewal of ranges and subreferences. Depending on user feedback, we may implement this later.)

## Endpoint-specific information

### TEI endpoint

The TEI endpoint provides access to the sources that form the basis of all our information offers. Whereas the works are sometimes split into several parts to reflect the structure of multi-volume works or for technical reasons, and while some information in the header is maintained in an external file, this endpoint resolves all of this and delivers one complete and integral TEI file. Since the extraction of parts of a work can result in invalid TEI or even malformed xml, this endpoint at the moment does not use the location identifier and offers access only to whole works.

### Plaintext endpoint

The plaintext endpoint offers access to an on-the-fly plaintext rendering of our texts. Generally, this rendering works in two modes: original and constituted (default), which can be requested explicitly by appending an `.orig` or an `.edit` to the work identifier.

In both modes, whitespace is normalized (linebreaks are suppressed), paragraphs are separated by blank lines, marginal notes are wrapped in braces (and preceded by some whitespace: "`   {}`"). List items are prefixed with hashes or dashes (`#`/`-`), depending on the list type being numbered or unnumbered.

Obviously, in cases where an original and an edited text exists, which of those two is being rendered depends on the mode as well. This applies to editorial corrections, expansions of abbreviations and normalizations.

In "constituted" mode, sections that have editorial labels get these wrapped in square brackets and asterisks ("`[ *` ... `* ]`"). Milestones such as article boundaries are represented by either daggers, asterisks or asterisks in brackets (`†`, `*`, `[*]`), depending on the way they appear in the sources, in "diplomatic" mode whereas in "constituted" mode, they are wrapped in brackets and eventually represented by their editorial label (e.g. "`[article 12]`").

In "constituted" mode, terms or names of persons that are treated in the dictionary get their dictionary lemma appended in brackets and arrow (e.g. "`Los mandamientos de la ley diuina [→lex divina]: son diez ...`"). The same also holds for citations where this does not refer to dictionary entries but may serve to find and consolidate references to specific works.

### RDF endpoint

### HTML endpoint

### iiif endpoint
