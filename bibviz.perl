#!/usr/bin/env perl
#
# BibViz --- BibTeX-to-HTML-tree converter for easier bibliography browsing
#
# (C) 2016, John Maraist, licensed under GPL3, see file included

use Cwd;
use Encode;
use FindBin;
use lib (($FindBin::Bin));
use BibLib;
use Getopt::Long;
use IO::File;
use Pod::Usage;
use File::Path qw( make_path );
use File::Basename qw( fileparse );
use HTML::HTML5::Builder qw[:standard];
my $originalWorkingDir = getcwd;

## Variables set by command-line options.
my $keywordsField = 'keywords';
my $citesCompleteField = 'cites';
my $citesIncludeField = 'cites*';
my $abstractField = 'abstract';
my $fileField = 'file';
my $baseDir = $originalWorkingDir;
my $urlPathToPapersRoot = "../papers";
my $papersBaseDir;
my $htmlOutputDir;
my $authorPageBullets = 0;
my $keywordsSep = "\\s*,\\s*";
my $citationsSep = "\\s*,\\s*";
my $filesSep = "\\s*,\\s*";
my $keywordFrontpageThreshhold = 2;
my %keywordFrontpageSkip = ( crash => 1 );
my $allBibFiles = 1;
my @bibfileSpecs = ("*.bib");
my @ignoreBibfiles = ();
my @leadBibfiles = ();
my @paperPatterns = ("*.pdf", "*.ps", "*.doc", "*.html", "*.txt");
my @bibFiles = ();
my $mainTitle = 'BibTeX browser';
my $allPapersTitle = 'All references';
my $allAuthorsTitle = 'All authors';
my $allKeywordTitle = 'Keywords';
my $unreferencedPapersTitle = 'Unreferenced papers';
my $abstractLead = 'Abstract';
my $topNav = 'Top';
my $allPapersNav = 'all papers';
my $allAuthorsNav = 'all authors';
my $allKeywordNav = 'all keywords';
my $verbose = 1;

## Process command-line options
GetOptions("main-title=s" => \$mainTitle,
           "all-papers-title=s" => \$allPapersTitle,
           "all-authors-title=s" => \$allAuthorsTitle,
           "all-keywords-title=s" => \$allKeywordTitle,
           "unreferenced-papers-title=s" => \$unreferencedPapersTitle,
           "abstract-title=s" => \$abstractLead,
           "top-nav=s" => \$topNav,
           "papers-nav=s" => \$allPapersNav,
           "authors-nav=s" => \$allAuthorsNav,
           "keywords-nav=s" => \$allKeywordNav,

           "keywords-field=s" => \$keywordsField,
           "complete-cites-field=s" => \$citesCompleteField,
           "some-cites-field=s" => \$citesIncludeField,
           "abstract-field=s" => \$abstractField,
           "local-files-field=s" => \$fileField,

           "bibtex-src-dir|d=s" => \$baseDir,
           "files-dir|f=s" => \$papersBaseDir,
           "output-dir|o=s" => \$htmlOutputDir,
           "path-to-papers=s" => \$urlPathToPapersRoot,
           "author-page-bullet-list" => \$authorPageBullets,
           "keywords-front-page-threshhold=i" => \$keywordFrontpageThreshhold,
           "keywords-sep=s" => \$keywordsSep,
           "citations-sep=s" => \$citationsSep,
           "files-sep=s" => \$filesSep,
           "nontop-keyword=s" => sub {
             my ($opt,$val) = @_;
             $keywordFrontpageSkip{$val} = 1;
           },
           "paper-match=s{1,}" => \@paperPatterns,
           "bibfiles=s{1,}" => \@bibfileSpecs,
           "lead-bibfiles=s{1,}" => \@leadBibfiles,
           "skip-bibfiles=s{1,}" => \@ignoreBibfiles,

           "verbose|v+" => \$verbose,
           "quiet|q"    => sub { $verbose = 0; },
           "manual|man|m" => sub { pod2usage(-exitval => 0, -verbose => 2); },
           "help|h"       => sub { pod2usage(-exitval => 0, -verbose => 0); })
    or pod2usage(-exitval => 1, -verbose => 0,
                 -msg => 'Error in command line arguments');

## More defaults
$papersBaseDir = "${baseDir}/papers"  unless defined $papersBaseDir;
$htmlOutputDir = "${baseDir}/html"    unless defined $htmlOutputDir;
$BibLib::verbose = $verbose;

## Load the list of BibTeX source files.
my %noAdd = ();
foreach my $skip (@ignoreBibfiles) { $noAdd{$skip} = 1; }
foreach my $skip (@leadBibfiles)   { $noAdd{$skip} = 1; }
chdir $baseDir;
foreach my $spec (@bibfileSpecs) {
  foreach my $src (glob $spec) {
    push @bibFiles, $src  unless $noAdd{$src};
  }
}
foreach my $lead (@leadBibfiles) { unshift @bibFiles, $lead; }

## Load the BibTeX files.
print "Loading sources.\n" if $verbose>0;
chdir $baseDir;
my $lib = new BibLib(@bibFiles);

## Load the list of papers.
chdir $papersBaseDir;
my %unusedPapers = ();
foreach my $pattern (@paperPatterns) {
  foreach my $paper (glob $pattern) {
    $unusedPapers{$paper} = 1;
  }
}

## Set up the HTML output directory.
unless (-e $htmlOutputDir) {
  make_path $htmlOutputDir
      or die "Failed to create directory: $htmlOutputDir\n";
}
mkdir "$htmlOutputDir/papers";
mkdir "$htmlOutputDir/author";
mkdir "$htmlOutputDir/keyword";

my @entries = $lib->entries;
sub lastNameSorter {
  my ($cmpA, $cmpB);

  if ($a =~ /{([^{]+)}$/) {
    $cmpA = $1;
  } elsif ($a =~ /([^ ]+)$/) {
    $cmpA = $1;
  } else {
    $cmpA = $a;
  }

  if ($b =~ /{([^{]+)}$/) {
    $cmpB = $1;
  } elsif ($b =~ /([^ ]+)$/) {
    $cmpB = $1;
  } else {
    $cmpB = $b;
  }

  $cmpA =~ s/[^a-zA-Z]//g;
  $cmpB =~ s/[^a-zA-Z]//g;
  return lc($cmpA) cmp lc($cmpB);
}
sub entrySorter {
  my @authors1 = $lib->authors($a);
  my @authors2 = $lib->authors($b);
  my $key1 = $authors1[0]->last  if $#authors1>=0 && defined $authors1[0];
  my $key2 = $authors2[0]->last  if $#authors2>=0 && defined $authors2[0];
  unless (defined $key1) {
    my @editors1 = $lib->editors($a);
    $key1 = $editors1[0]->last  if $#editors1>=0 && defined $editors1[0];
    $key1 = $lib->field($a, 'title') unless defined $key1;
    $key1 = $lib->field($a, 'booktitle') unless defined $key1;
  }
  unless (defined $key2) {
    my @editors2 = $lib->editors($b);
    $key2 = $editors2[0]->last  if $#editors2>=0 && defined $editors2[0];
    $key2 = $lib->field($b, 'title') unless defined $key2;
    $key2 = $lib->field($b, 'booktitle') unless defined $key2;
  }
  return 1  unless defined $key1;
  return -1 unless defined $key2;
  return $key1 cmp $key2;
}
my @sortedEntries = sort entrySorter @entries;

## Augmenting records.
print "Cross-referencing.\n" if $verbose>0;
my %authorPapers = ();
my %keywordPapers = ();
foreach my $tag (@sortedEntries) {
  my $entry = $lib->entry($tag);
  my @authors = split / +and +/, $lib->field($tag, 'author');
  my @editors = split / +and +/, $lib->field($tag, 'editor');
  my @keywords = split /$keywordsSep/, $lib->field($tag, $keywordsField);

  ## Sort papers by keyword.
  foreach my $keyword (@keywords) {
    push @{$keywordPapers{lc($keyword)}}, $tag;
  }

  ## Sort papers by author.
  foreach my $author (@authors) {
    push @{$authorPapers{$author}}, $tag;
  }

  ## Sort papers by editor.
  foreach my $editor (@editors) {
    push @{$authorPapers{$editor}}, $tag;
  }

  ## Turn (some) LaTeX into HTML
  foreach my $field (qw(title booktitle)) {
  }
}

## Open a page of everything
print "Creating main index.\n" if $verbose>0;
open ALLPAPERS, ">$htmlOutputDir/papers/index.html";
my $allList = ul();
my $html = html(
  head(
    title($allPapersTitle)
  ),
  body(header('papers'),
       h1($allPapersTitle), $allList,
       footer('papers'))
    );

## Create/append per-entity stuff
print "Writing paper pages.\n" if $verbose>0;
foreach my $tag (@sortedEntries) {
  appendElementItem($allList, $tag);
  open HTML, ">$htmlOutputDir/papers/$tag.html";
  my $pr = entryHtml($tag);
  # die $tag if $pr =~ /[^\x00-\xFF]/;
  print HTML $pr;
  close HTML;
}

# Close the pages of everything.
print ALLPAPERS $html;
close ALLPAPERS;

## Open the all-authors page
open ALLAUTHORS, ">$htmlOutputDir/author/index.html";
my $authorList = $authorPageBullets ? ul() : [];
my $apageSep = "";

## Author/editor pages.
print "Writing author pages.\n" if $verbose>0;
foreach my $author (sort lastNameSorter (keys %authorPapers)) {

  if ($authorPageBullets) {
    $authorList->appendChild(li(a(-href=>(cleanUrl($author).".html"),$author)));
  } else {
    push @$authorList, $apageSep, a(-href=>(cleanUrl($author).".html"),$author);
    $apageSep = " - ";
  }

  open HTML, ">$htmlOutputDir/author/".cleanUrl($author).".html";
  print HTML authorHtml($author, $authorPapers{$author});
  close HTML;
}

## Close the all-authors page
print ALLAUTHORS html(head(title($allAuthorsTitle)),
                      body(header('authors'),
                           h1($allAuthorsTitle),
                           ($authorPageBullets
                            ? $authorList : p(@$authorList, ".")),
                           footer('authors')));
close ALLAUTHORS;

## Open the all-keywords page
open ALLKEYWORDS, ">$htmlOutputDir/keyword/index.html";
my $keywordList = div();
my $keywordsPage = html(head(title($allKeywordTitle)),
                        body(header('keywords'),
                             h1($allKeywordTitle), $keywordList,
                             footer('keywords')));

## Keyword pages.
print "Writing keyword pages.\n" if $verbose>0;
my @kwdTopList = (a(-href=>"keyword/index.html", $allKeywordTitle));
my $kwdTopListSep = ": ";
foreach my $keyword (sort {$a cmp $b} (keys %keywordPapers)) {
  my $papers = $keywordPapers{$keyword};
  my $showKeyword = "$keyword";
  $showKeyword =~ s/^([a-z])/uc($1)/e;
  $keywordList->appendChild(li(a(-href=>(cleanUrl($keyword).".html"),
                                 $showKeyword)));

  # Add to the front-page keyword list if there are enough papers
  # under the keyword.
  if ($#{$papers} > $keywordFrontpageThreshhold
      && !$keywordFrontpageSkip{$keyword}) {
    push @kwdTopList, $kwdTopListSep;
    push @kwdTopList, a(-href=>("keyword/".cleanUrl($keyword).".html"),
                        $keyword);
    $kwdTopListSep = ", ";
  }

  open HTML, ">$htmlOutputDir/keyword/".cleanUrl($keyword).".html";
  print HTML keywordHtml($keyword, $papers);
  close HTML;
}
push @kwdTopList, ".";

## Close the all-keywords page
print ALLKEYWORDS $keywordsPage;
close ALLKEYWORDS;

print "Writing top-level page.\n" if $verbose>0;
open TOP, ">$htmlOutputDir/index.html";
my $unlinked = 0;
my $unlinkedPapers = ul();
foreach my $paper (sort { $a cmp $b } (keys %unusedPapers)) {
  $unlinkedPapers->appendChild(li(a(-href=>"$urlPathToPapersRoot/$paper",
                                    $paper)));
  ++$unlinked;
}
my $topBody = body(h1($mainTitle),
                   ul(li(a(-href=>"papers/index.html", "$allPapersTitle.")),
                      li(a(-href=>"author/index.html", $allAuthorsTitle)),
                      li(@kwdTopList)));
if ($unlinked>0) {
  $topBody->appendChild(h2($unreferencedPapersTitle));
  $topBody->appendChild($unlinkedPapers);
}

print TOP html(head(title($mainTitle)), $topBody);
close TOP;
exit 0;

sub authorHtml {
  my $author = shift;
  my $refs = shift;

  my $paperList = ul();
  foreach my $ref (@$refs) {
    appendElementItem($paperList, $ref);
  }

  return html(
    head(title($author)),
    body(header(), h1($author), $paperList, footer()));
}

sub keywordHtml {
  my $keyword = shift;
  my $refs = shift;

  my $paperList = ul();
  foreach my $ref (sort entrySorter @$refs) {
    appendElementItem($paperList, $ref);
  }

  my $showKeyword = "$keyword";
  $showKeyword =~ s/^([a-z])/uc($1)/e;

  return html(
    head(title($showKeyword)),
    body(header(), h1($showKeyword), $paperList, footer()));
}

sub entryHtml {
  my $tag = shift;
  my @body = (header());

  my $authorList=$lib->field($tag, 'author');
  my @authors = split / and /, $authorList;
  $authorList =~ s/ and /, /g;

  my @downAuthorLinks = ();
  my @overAuthorLinks = ();
  my $sep = undef;
  foreach my $author (@authors) {
    push @downAuthorLinks, ', ' if $sep;
    push @downAuthorLinks, a(-href=>"author/".cleanUrl($author).".html",
                             cleanString($author));
    push @overAuthorLinks, ', ' if $sep;
    push @overAuthorLinks, a(-href=>"../author/".cleanUrl($author).".html",
                             cleanString($author));
    $sep = 1;
  }

  my $editorList=$lib->field($tag, 'editor');
  my @editors = split / and /, $editorList;
  $editorList =~ s/ and /, /g;
  my $title   = $lib->field($tag, 'title');

  my $title=$lib->field($tag, 'title');
  my $booktitle=$lib->field($tag, 'booktitle');
  my $journal=$lib->field($tag, 'journal');
  my $crossref=$lib->field($tag, 'crossref');
  my $volume=$lib->field($tag, 'volume');
  my $number=$lib->field($tag, 'number');
  my $year = $lib->field($tag, 'year');
  my $abstract = $lib->field($tag, 'abstract');
  my $annote = $lib->field($tag, 'annote');
  my $paperfile = $lib->field($tag, 'file');
  my $srcfile = $lib->field($tag, '_file');

  push @body, h1($title);
  push @body, @overAuthorLinks;
  if (defined $journal && $journal ne '') {
    push @body, br, i($journal);
    push @body, " " if (defined $volume && $volume ne '')
        || (defined $number && $number ne '');
    push @body, b($volume)  if defined $volume && $volume ne '';
    push @body, ":"
        if defined $volume && $volume ne '' && defined $number && $number ne '';
    push @body, $number  if defined $number && $number ne '';
  }
  push @body, br, i($booktitle)
      if defined $booktitle && $booktitle ne '' && $booktitle ne $title;
  if (defined $paperfile && $paperfile ne '') {
    my @files = split /$filesSep/, $paperfile;
    my $fsep='';
    push @body, br, "File", ($#files>0 ? "s" : ""), ": ";
    foreach my $file (@files) {
      push @body, $fsep, a(-href=>"../$urlPathToPapersRoot/$file", $file);
      delete $unusedPapers{$file};
      $fsep = ', ';
    }
  }

  if (defined $abstract && $abstract ne '') {
    my @pars = split /\n(\s*\n)+|\\par\b\s*/, $abstract;
    my $lead = b("$abstractLead. ");
    my $ab = blockquote();
    foreach my $par (@pars) {
      $ab->appendChild(p($lead, $par));
      $lead='';
    }
    push @body, i($ab);
  }
  if (defined $annote && $annote ne '') {
    my @pars = split /\n(\s*\n)+|\\par\b\s*/, $annote;
    foreach my $par (@pars) {
      push @body, p($par);
    }
  }

  # Endmatter
  push @body, hr, "Source BibTeX: ", $srcfile, footer();

  return html(
    head(title($title)),
    body(@body)
  );
}

sub appendElementItem {
  my $enclosure = shift;
  my $tag = shift;

  my $authorList=$lib->field($tag, 'author');
  my @authors = split / and /, $authorList;
  $authorList =~ s/ and /, /g;

  my @downAuthorLinks = ();
  my @overAuthorLinks = ();
  my $authorSep = undef;
  foreach my $author (@authors) {
    push @downAuthorLinks, ', ' if $authorSep;
    push @downAuthorLinks, a(-href=>"author/".cleanUrl($author).".html",
                             cleanString($author));
    push @overAuthorLinks, ', ' if $authorSep;
    push @overAuthorLinks, a(-href=>"../author/".cleanUrl($author).".html",
                             cleanString($author));
    $authorSep = 1;
  }

  my @downEditorLinks = ();
  my @overEditorLinks = ();
  my $editorList=$lib->field($tag, 'editor');
  my @editors = split / and /, $editorList;
  $editorList =~ s/ and /, /g;
  my $title   = $lib->field($tag, 'title');
  my $editorSep = undef;
  foreach my $editor (@editors) {
    push @downEditorLinks, ', ' if $editorSep;
    push @downEditorLinks, a(-href=>"editor/".cleanUrl($editor).".html",
                             cleanString($editor));
    push @overEditorLinks, ', ' if $editorSep;
    push @overEditorLinks, a(-href=>"../author/".cleanUrl($editor).".html",
                             cleanString($editor));
    $editorSep = 1;
  }

  my @contents = ();
  my $sep = '';
  my $fin = '.';

  if (defined $authorList && $authorList ne '') {
    push @contents, $sep, @overAuthorLinks;
    $sep = ', ';
    $fin = '.';
  } elsif (defined $editorList && $editorList ne '') {
    push @contents, $sep,
    @overEditorLinks, ', ed', ($#overEditorLinks>0 ? 's' : ''), '.';
    $sep = ', ';
    $fin = '.';
  }

  my $periodLast = 0;
  my $type = $lib->type($tag);
  if ($type eq 'BOOK' || $type eq 'MANUAL' || $type eq 'PROCEEDINGS') {
    push @contents, $sep, a(-href=>"../papers/$tag.html", i($title));
    $sep = ', ';
    $fin = $title =~ /\.$/ ? '' : '.';
  } else {
    push @contents, $sep, "\"", a(-href=>"../papers/$tag.html", $title);
    $periodLast = $title =~ /\.$/;
    $sep = '," ';
    $fin = $title =~ /\.$/ ? '' : '."';
  }

  my $journal=$lib->field($tag, 'journal');
  my $booktitle=$lib->field($tag, 'booktitle');
  my $crossref=$lib->field($tag, 'crossref');
  my $volume=$lib->field($tag, 'volume');
  my $number=$lib->field($tag, 'number');
  if ($type eq 'ARTICLE') {
    push @contents, $sep, i($journal);
    $sep = ', ';
    $fin = $journal =~ /\.$/ ? '' : '.';

    if (defined $volume && $volume ne '') {
      push @contents, " ", b($volume);
      push @contents, ":", $number if (defined $number && $number ne '');
      $fin = '.';
    } elsif (defined $number && $number ne '') {
      push @contents, " ", $number;
      $fin = '.';
    }

  } else {
    if (defined $booktitle && $booktitle ne $title && $booktitle ne '') {
      push @contents, $sep;
      if (defined $crossref && $crossref ne '') {
        push @contents, a(-href=>"../papers/$crossref.html", i($booktitle));
      } else {
        push @contents, i($booktitle);
      }
      $sep = ', ';
      $fin = $booktitle =~ /\.$/ ? '' : '.';

      push @contents, ", vol. ", $volume if defined $volume && $volume ne '';
      push @contents, ", no. ", $number if defined $number && $number ne '';
      $fin = '.' if (defined $volume && $volume ne '')
          || (defined $number && $number ne '');
    }
  }

  my $year = $lib->field($tag, 'year');
  my $url = $lib->field($tag, 'url');
  if (defined $year && $year ne '') {
    push @contents, $sep, $year;
    $sep = ', ';
    $fin = '.';
  } elsif (defined $url && $url ne '') {
    push @contents, $sep, a(-href=>$url, "online");
    $sep = ', ';
    $fin = '.';
  }

  push @contents, $fin;

  $enclosure->appendChild(li(@contents));
}

sub cleanString {
  my $s = shift;
  # $s =~ s/{\\'{([aeiouAEIOU])}}/\&\1acute;/g;
  # $s =~ s/{\\`{([aeiouAEIOU])}}/\&\1grave;/g;
  # $s =~ s/{\\"{([aeiouAEIOU])}}/\&\1uml;/g;
  # $s =~ s/{\\'([aeiouAEIOU])}/\&\1acute;/g;
  # $s =~ s/{\\`([aeiouAEIOU])}/\&\1grave;/g;
  # $s =~ s/{\\"([aeiouAEIOU])}/\&\1uml;/g;
  # $s =~ s/\\'{([aeiouAEIOU])}/\&\1acute;/g;
  # $s =~ s/\\`{([aeiouAEIOU])}/\&\1grave;/g;
  # $s =~ s/\\"{([aeiouAEIOU])}/\&\1uml;/g;
  # $s =~ s/\\'([aeiouAEIOU])/\&\1acute;/g;
  # $s =~ s/\\`([aeiouAEIOU])/\&\1grave;/g;
  # $s =~ s/\\"([aeiouAEIOU])/\&\1uml;/g;
  return $s;
}

sub cleanUrl {
  my $s = shift;
  $s =~ s/[{}\\'`"., ]//g;
  return $s;
}

sub header {
  my $for = shift;
  return div($mainTitle, ": ", navLineContents($for), hr);
}

sub footer {
  my $for = shift;
  return div(hr, navLineContents($for));
}

sub navLineContents {
  my $for = shift;
  return (($for eq 'top'
           ? b($topNav)
           : a(-href=>"../index.html", $topNav)),
          ", ",
          ($for eq 'papers'
           ? b($allPapersNav)
           : a(-href=>"../papers/index.html", $allPapersNav)),
          ", ",
          ($for eq 'authors'
           ? b($allAuthorsNav)
           : a(-href=>"../author/index.html", $allAuthorsNav)),
          ", ",
          ($for eq 'keywords'
           ? b($allKeywordNav)
           : a(-href=>"../keyword/index.html", $allKeywordNav)),
          ".");
}


__END__
=head1 NAME

bibviz - Build a browsable HTML view of BibTeX files and related documents

=head1 SYNOPSIS

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

=head1 OPTIONS

=head2 Basic configuration

=over 8

=item B<--bibtex-src-dir=DIRECTORY>

The base directory holding BibTeX source files.  By default, the
current working directory.

=item B<--files-dir=PATH>

Directory holding files associated with (some of) the BibTeX entries,
specified as a local path relative to the base directory above.  By
default, the subdirectory B<papers>.

=item B<--output-dir=PATH>

Directory to be created to hold generated HTML, specified as a local
path relative to the base directory above.  By default, the
subdirectory B<html>.

=item B<--path-to-papers=PATH>

Path used as a component of the URLs linking generated pages for
papers to the files associated with a page.  By default, B<../>
followed by the files directory above.

=item B<--author-page-bullet-list=FLAG>

A flag controlling the layout of the all-authors page.  If this flag
is set, the authors are arranged vertically in a bulleted list;
otherwise, the name are placed in a single paragraph.

=item B<--keywords-front-page-threshhold=N>

A number: keywords referenced from more pages than the threshhold will
be listed on the top page.  If the threshhold is zero, then no
keywords will appear on the top page.

=item B<--nontop-keyword=STRING STRING ... STRING>

Names keywords which should be excluded from the top page even if they
do meet the threshhold above.

=item B<--paper-match=PATTERN PATTERN ... PATTERN>

Pattern to which files in their directory are matched to be considered
relevant, and are expected to be referenced from BibTeX B<file> field.
Files which are found against these patterns but not mentioned in some
BibTeX B<file> field will be included in the "Unmatched files" list on
the top generated page.  By default, the patterns are B<"*.pdf">,
B<"*.ps">, B<"*.doc">, B<"*.html">, B<"*.txt">.

=item B<--bibfiles=PATTERN PATTERN ... PATTERN>

When applied within the base source BibTeX file directory given by
B<--bibtex-src-dir>, names the BibTeX files to be read and rendered as
HTML.  By default, the sole pattern is B<*.bib>.

=item B<--lead-bibfiles=NAME NAME ... NAME>

Names a list of BibTeX files which should be loaded first, ahead of
any others which match the patterns given by B<--bibfiles> above.  It
is acceptable (and expected) that files named in this option will be
duplicated under B<--bibfiles>; these files will not be loaded twice.
Alternatively, it is also acceptable that files named in this option
not match the B<--bibfiles> patterns.  In the event that a file is
named in both this list and the B<--skip-bibfiles> list, this options
takes priority and the file is loaded early.

=item B<--skip-bibfiles=NAME NAME ... NAME>

Names BibTeX files which should B<not> be loaded, even if they match a
B<--bibfiles> pattern.

=back

=head2 Non-standard BibTeX fields

BibViz uses non-standard BibTeX fields for a number of purposes.
Users can change what field name is used for each purpose with the
options in this section.

=over 8

=item B<--keywords-field=NAME, --keywords-sep=REGEX>

By default the B<keywords> field gives the phrases used to associate
entries with keywords.  The B<--keywords-field> option allows a
different field to be used; the B<--keywords-sep> option changeds the
Perl regular expression used to divide the field value into keywords
(by default, a comma possibly surrounded by whitespace).

=item B<--complete-cites-field=NAME, --some-cites-field=NAME, --citations-sep=REGEX>

An entry can use these fields to note papers which it cites by giving
their BibTeX entries' tags.  The field names by the first option
(default B<cites>) indicates that the list of citations is complete;
by the second option (default B<cites*>), is partial.  The third
option sets the Perl regular expression used to divide the field value
into citation tags (by default, a comma possibly surrounded by
whitespace).

This functionality is not implemented in the current version of
BibViz.

=item B<--abstract-field=NAME>

BibViz will display an abstract on the entry page for a citation; this
option sets the field name for abstracts (default B<abstract>).

=item B<--local-files-field=NAME, --local-files-sep=REGEX>

BibViz will display links to local files associated with a citation
(the local copy of a paper, slides, etc.).  These options set the
field name and separator regular expression, by default respectively
B<file> and a comma possibly surrounded by whitespace.

=back

=head2 Output strings

These options name strings which are included verbatim in the
constructed pages.

=over 8

=item B<--main-title, --all-papers-title, --all-authors-title, --all-keywords-title>

The titles of respectively the top-level page and the pages of all
papers, authors and keywords.

=item B<--unreferenced-papers-title>

The title of the section listing files matching a B<--paper-match>
pattern but not mentioned in any BibTeX entry.

=item B<--abstract-title>

Text placed in boldface before the first paragraph of papers
abstracts.

=item B<--top-nav, --papers-nav, --authors-nav, --keywords-nav>

Text used in the navigation lines at the top and bottom of pages.

=back

=head2 Other options

=over 8

=item B<--verbose, -v>

Raise the level of verbosity; may be given multiple times for
increased diagnostic goodness.

=item B<--quiet, -q>

Quash all non-error output.

=item B<--help, -h>

Print a short usage message.

=item B<--manual, --man, -m>

Show this document.

=back

=head1 DESCRIPTION

B<Bibviz> creates a browsable tree of HTML from a collection of BibTeX
files and PDFs and files associated with BibTeX entries.  Citations
can be listed by author or by keyword, and individual citations' pages
include the usual BibTeX fields' information as well as any abstract,
citations and local file links provided in the BibTeX source.

A to-do list:

=over

=item

The citations displayd/links are not displayed.

=item

Not all standard BibTeX fields are currently displayed.

=back

This is a pre-version-number version of BibViz.

=head1 AUTHOR

John Maraist, bibviz at maraist dot O R G, http://maraist.org

=head1 LICENSE

GPL3, see included

=cut
