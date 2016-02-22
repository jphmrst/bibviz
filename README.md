# NAME

bibviz - Build a browsable HTML view of BibTeX files and related documents

# SYNOPSIS

bibviz \[options\]

```
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
```

# OPTIONS

## Basic configuration

- **--bibtex-src-dir=DIRECTORY**

    The base directory holding BibTeX source files.  By default, the
    current working directory.

- **--files-dir=PATH**

    Directory holding files associated with (some of) the BibTeX entries,
    specified as a local path relative to the base directory above.  By
    default, the subdirectory **papers**.

- **--output-dir=PATH**

    Directory to be created to hold generated HTML, specified as a local
    path relative to the base directory above.  By default, the
    subdirectory **html**.

- **--path-to-papers=PATH**

    Path used as a component of the URLs linking generated pages for
    papers to the files associated with a page.  By default, **../**
    followed by the files directory above.

- **--author-page-wrapped-list=FLAG**

    A flag controlling the layout of the author list pages.  If this flag
    is set, the authors are listed in a single paragraph, wrapped as
    ordinary text.  Otherwise and by default, they are arranged vertically
    in a bulleted list.

- **--keywords-front-page-threshhold=N**

    A number: keywords referenced from more pages than the threshhold will
    be listed on the top page.  If the threshhold is zero, then no
    keywords will appear on the top page.

- **--nontop-keyword=STRING STRING ... STRING**

    Names keywords which should be excluded from the top page even if they
    do meet the threshhold above.

- **--paper-match=PATTERN PATTERN ... PATTERN**

    Pattern to which files in their directory are matched to be considered
    relevant, and are expected to be referenced from BibTeX **file** field.
    Files which are found against these patterns but not mentioned in some
    BibTeX **file** field will be included in the "Unmatched files" list on
    the top generated page.  By default, the patterns are **"\*.pdf"**,
    **"\*.ps"**, **"\*.doc"**, **"\*.html"**, **"\*.txt"**.

- **--bibfiles=PATTERN PATTERN ... PATTERN**

    When applied within the base source BibTeX file directory given by
    **--bibtex-src-dir**, names the BibTeX files to be read and rendered as
    HTML.  By default, the sole pattern is **\*.bib**.

- **--lead-bibfiles=NAME NAME ... NAME**

    Names a list of BibTeX files which should be loaded first, ahead of
    any others which match the patterns given by **--bibfiles** above.  It
    is acceptable (and expected) that files named in this option will be
    duplicated under **--bibfiles**; these files will not be loaded twice.
    Alternatively, it is also acceptable that files named in this option
    not match the **--bibfiles** patterns.  In the event that a file is
    named in both this list and the **--skip-bibfiles** list, this options
    takes priority and the file is loaded early.

- **--skip-bibfiles=NAME NAME ... NAME**

    Names BibTeX files which should **not** be loaded, even if they match a
    **--bibfiles** pattern.

- **--input-encoding=NAME**, **--output-encoding=NAME**

    Names the character set encoding which Perl should expect of the
    source BibTeX, and generate into its output HTML.  By default, both
    are **iso-8859-1**.

## Non-standard BibTeX fields

BibViz uses non-standard BibTeX fields for a number of purposes.
Users can change what field name is used for each purpose with the
options in this section.

- **--keywords-field=NAME, --keywords-sep=REGEX**

    By default the **keywords** field gives the phrases used to associate
    entries with keywords.  The **--keywords-field** option allows a
    different field to be used; the **--keywords-sep** option changeds the
    Perl regular expression used to divide the field value into keywords
    (by default, a comma possibly surrounded by whitespace).

- **--complete-cites-field=NAME, --some-cites-field=NAME, --citations-sep=REGEX**

    An entry can use these fields to note papers which it cites by giving
    their BibTeX entries' tags.  The field names by the first option
    (default **cites**) indicates that the list of citations is complete;
    by the second option (default **cites\***), is partial.  The third
    option sets the Perl regular expression used to divide the field value
    into citation tags (by default, a comma possibly surrounded by
    whitespace).

    This functionality is not implemented in the current version of
    BibViz.

- **--abstract-field=NAME**

    BibViz will display an abstract on the entry page for a citation; this
    option sets the field name for abstracts (default **abstract**).

- **--local-files-field=NAME, --local-files-sep=REGEX**

    BibViz will display links to local files associated with a citation
    (the local copy of a paper, slides, etc.).  These options set the
    field name and separator regular expression, by default respectively
    **file** and a comma possibly surrounded by whitespace.

## Output strings

These options name strings which are included verbatim in the
constructed pages.

- **--main-title, --all-papers-title, --all-authors-title, --all-keywords-title**

    The titles of respectively the top-level page and the pages of all
    papers, authors and keywords.

- **--unreferenced-papers-title**

    The title of the section listing files matching a **--paper-match**
    pattern but not mentioned in any BibTeX entry.

- **--as-author-subhead, --as-editor-subhead**

    On the pages for an individual author/editor, the sections titles for
    the lists of citations where the individual is an author and is an
    editor.

- **--abstract-title**

    Text placed in boldface before the first paragraph of papers
    abstracts.

- **--top-nav, --papers-nav, --authors-nav, --keywords-nav**

    Text used in the navigation lines at the top and bottom of pages.

## Other options

- **--verbose, -v**

    Raise the level of verbosity; may be given multiple times for
    increased diagnostic goodness.

- **--quiet, -q**

    Quash all non-error output.

- **--help, -h**

    Print a short usage message.

- **--manual, --man, -m**

    Show this document.

# DESCRIPTION

**Bibviz** creates a browsable tree of HTML from a collection of BibTeX
files and PDFs and files associated with BibTeX entries.  Citations
can be listed by author or by keyword, and individual citations' pages
include the usual BibTeX fields' information as well as any abstract,
citations and local file links provided in the BibTeX source.

A to-do list:

- The citations displayd/links are not displayed.
- Not all standard BibTeX fields are currently displayed.

This is a pre-version-number version of BibViz.

## Requirements

There are a small number of Perl packages that you may need to pull
from CPAN:

```
HTML::HTML5::Builder
BibTeX::Parser
```

And if you want to rebuild the GitHub README.md, then also:

```
Pod::Markdown::Github
```

Everything else should be included with a standard Perl distribution.

# AUTHOR

John Maraist, bibviz at maraist dot O R G, http://maraist.org

# LICENSE

GPL3, see included
