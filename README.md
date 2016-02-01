BIBVIZ.PERL(1)        User Contributed Perl Documentation       BIBVIZ.PERL(1)



NNAAMMEE
       bibviz - Build a browsable HTML view of BibTeX files and related
       documents

SSYYNNOOPPSSIISS
       bibviz [options]

        Main options:
          -d DIR  --bibtex-src-dir=DIR   Base directory holding BibTeX source
                                         files
          -o DIR  --output-dir=DIR       Output directory, to hold generated HTML
          -f PATH  --files-dir=PATH      Path from the base directory to the
                                         directory of papers
          --path-to-papers=PATH          Path from the generated output directory
                                         to the directory of papers
          -v  --verbose                  Increase program output
          -q  --quiet                    Quash all non-error output
          -h --help                      Brief help message
          -m --man                       Full documentation

OOPPTTIIOONNSS
   BBaassiicc ccoonnffiigguurraattiioonn
       ----bbiibbtteexx--ssrrcc--ddiirr==DDIIRREECCTTOORRYY
               The base directory holding BibTeX source files.  By default,
               the current working directory.

       ----ffiilleess--ddiirr==PPAATTHH
               Directory holding files associated with (some of) the BibTeX
               entries, specified as a local path relative to the base
               directory above.  By default, the subdirectory ppaappeerrss.

       ----oouuttppuutt--ddiirr==PPAATTHH
               Directory to be created to hold generated HTML, specified as a
               local path relative to the base directory above.  By default,
               the subdirectory hhttmmll.

       ----ppaatthh--ttoo--ppaappeerrss==PPAATTHH
               Path used as a component of the URLs linking generated pages
               for papers to the files associated with a page.  By default,
               ....// followed by the files directory above.

       ----aauutthhoorr--ppaaggee--bbuulllleett--lliisstt==FFLLAAGG
               A flag controlling the layout of the all-authors page.  If this
               flag is set, the authors are arranged vertically in a bulleted
               list; otherwise, the name are placed in a single paragraph.

       ----kkeeyywwoorrddss--ffrroonntt--ppaaggee--tthhrreesshhhhoolldd==NN
               A number: keywords referenced from more pages than the
               threshhold will be listed on the top page.  If the threshhold
               is zero, then no keywords will appear on the top page.

       ----nnoonnttoopp--kkeeyywwoorrdd==SSTTRRIINNGG SSTTRRIINNGG ...... SSTTRRIINNGG
               Names keywords which should be excluded from the top page even
               if they do meet the threshhold above.

       ----ppaappeerr--mmaattcchh==PPAATTTTEERRNN PPAATTTTEERRNN ...... PPAATTTTEERRNN
               Pattern to which files in their directory are matched to be
               considered relevant, and are expected to be referenced from
               BibTeX ffiillee field.  Files which are found against these
               patterns but not mentioned in some BibTeX ffiillee field will be
               included in the "Unmatched files" list on the top generated
               page.  By default, the patterns are ""**..ppddff"", ""**..ppss"", ""**..ddoocc"",
               ""**..hhttmmll"", ""**..ttxxtt"".

       ----bbiibbffiilleess==PPAATTTTEERRNN PPAATTTTEERRNN ...... PPAATTTTEERRNN
               When applied within the base source BibTeX file directory given
               by ----bbiibbtteexx--ssrrcc--ddiirr, names the BibTeX files to be read and
               rendered as HTML.  By default, the sole pattern is **..bbiibb.

       ----lleeaadd--bbiibbffiilleess==NNAAMMEE NNAAMMEE ...... NNAAMMEE
               Names a list of BibTeX files which should be loaded first,
               ahead of any others which match the patterns given by
               ----bbiibbffiilleess above.  It is acceptable (and expected) that files
               named in this option will be duplicated under ----bbiibbffiilleess; these
               files will not be loaded twice.  Alternatively, it is also
               acceptable that files named in this option not match the
               ----bbiibbffiilleess patterns.  In the event that a file is named in both
               this list and the ----sskkiipp--bbiibbffiilleess list, this options takes
               priority and the file is loaded early.

       ----sskkiipp--bbiibbffiilleess==NNAAMMEE NNAAMMEE ...... NNAAMMEE
               Names BibTeX files which should nnoott be loaded, even if they
               match a ----bbiibbffiilleess pattern.

   NNoonn--ssttaannddaarrdd BBiibbTTeeXX ffiieellddss
       BibViz uses non-standard BibTeX fields for a number of purposes.  Users
       can change what field name is used for each purpose with the options in
       this section.

       ----kkeeyywwoorrddss--ffiieelldd==NNAAMMEE,, ----kkeeyywwoorrddss--sseepp==RREEGGEEXX
               By default the kkeeyywwoorrddss field gives the phrases used to
               associate entries with keywords.  The ----kkeeyywwoorrddss--ffiieelldd option
               allows a different field to be used; the ----kkeeyywwoorrddss--sseepp option
               changeds the Perl regular expression used to divide the field
               value into keywords (by default, a comma possibly surrounded by
               whitespace).

       ----ccoommpplleettee--cciitteess--ffiieelldd==NNAAMMEE,, ----ssoommee--cciitteess--ffiieelldd==NNAAMMEE,,
       ----cciittaattiioonnss--sseepp==RREEGGEEXX
               An entry can use these fields to note papers which it cites by
               giving their BibTeX entries' tags.  The field names by the
               first option (default cciitteess) indicates that the list of
               citations is complete; by the second option (default cciitteess**),
               is partial.  The third option sets the Perl regular expression
               used to divide the field value into citation tags (by default,
               a comma possibly surrounded by whitespace).

               This functionality is not implemented in the current version of
               BibViz.

       ----aabbssttrraacctt--ffiieelldd==NNAAMMEE
               BibViz will display an abstract on the entry page for a
               citation; this option sets the field name for abstracts
               (default aabbssttrraacctt).

       ----llooccaall--ffiilleess--ffiieelldd==NNAAMMEE,, ----llooccaall--ffiilleess--sseepp==RREEGGEEXX
               BibViz will display links to local files associated with a
               citation (the local copy of a paper, slides, etc.).  These
               options set the field name and separator regular expression, by
               default respectively ffiillee and a comma possibly surrounded by
               whitespace.

   OOuuttppuutt ssttrriinnggss
       These options name strings which are included verbatim in the
       constructed pages.

       ----mmaaiinn--ttiittllee,, ----aallll--ppaappeerrss--ttiittllee,, ----aallll--aauutthhoorrss--ttiittllee,,
       ----aallll--kkeeyywwoorrddss--ttiittllee
               The titles of respectively the top-level page and the pages of
               all papers, authors and keywords.

       ----uunnrreeffeerreenncceedd--ppaappeerrss--ttiittllee
               The title of the section listing files matching a ----ppaappeerr--mmaattcchh
               pattern but not mentioned in any BibTeX entry.

       ----aabbssttrraacctt--ttiittllee
               Text placed in boldface before the first paragraph of papers
               abstracts.

       ----ttoopp--nnaavv,, ----ppaappeerrss--nnaavv,, ----aauutthhoorrss--nnaavv,, ----kkeeyywwoorrddss--nnaavv
               Text used in the navigation lines at the top and bottom of
               pages.

   ooppttiioonnss
       ----vveerrbboossee,, --vv
               Raise the level of verbosity; may be given multiple times for
               increased diagnostic goodness.

       ----qquuiieett,, --qq
               Quash all non-error output.

       ----hheellpp,, --hh
               Print a short usage message.

       ----mmaannuuaall,, ----mmaann,, --mm
               Show this document.

DDEESSCCRRIIPPTTIIOONN
       BBiibbvviizz creates a browsable tree of HTML from a collection of BibTeX
       files and PDFs and files associated with BibTeX entries.

       A to-do list:

       ·   The citations displayd/links are not displayed.

       ·   Not all standard BibTeX fields are currently displayed.

       This is Version 0.1 of BibViz.



perl v5.18.2                      2016-02-01                    BIBVIZ.PERL(1)
