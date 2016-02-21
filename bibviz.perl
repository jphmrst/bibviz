#!/usr/bin/env perl
#
# BibViz --- BibTeX-to-HTML-tree converter for easier bibliography browsing
#
# (C) 2016, John Maraist, licensed under GPL3, see file included

use strict;
use warnings;
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
my $authorPageNoBullets = 0;
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
my $asAuthorSubhead = 'As author';
my $asEditorSubhead = 'As editor';
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
           "as-author-subhead=s" => \$asAuthorSubhead,
           "as-editor-subhead=s" => \$asEditorSubhead,

           "keywords-field=s" => \$keywordsField,
           "complete-cites-field=s" => \$citesCompleteField,
           "some-cites-field=s" => \$citesIncludeField,
           "abstract-field=s" => \$abstractField,
           "local-files-field=s" => \$fileField,

           "bibtex-src-dir|d=s" => \$baseDir,
           "files-dir|f=s" => \$papersBaseDir,
           "output-dir|o=s" => \$htmlOutputDir,
           "path-to-papers=s" => \$urlPathToPapersRoot,
           "author-page-wrapped-list" => \$authorPageNoBullets,
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
mkdir "$htmlOutputDir/author/alpha";
mkdir "$htmlOutputDir/keyword";

my @entries = $lib->entries;
sub pullLastName {
  my $from = shift;
  if ($from =~ /{([^{]+)}$/) {
    return $1;
  } elsif ($from =~ /([^ ]+)$/) {
    return $1;
  } else {
    return $from;
  }
}
sub lastNameSorter {
  my $cmpA = pullLastName($a);
  my $cmpB = pullLastName($b);
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
my %editorPapers = ();
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
    $author = cleanLaTeX($author);
    push @{$authorPapers{$author}}, $tag;
  }

  ## Sort papers by editor.
  foreach my $editor (@editors) {
    $editor = cleanLaTeX($editor);
    push @{$editorPapers{$editor}}, $tag;
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
  body(pageHeader('papers'),
       h1($allPapersTitle), $allList,
       pageFooter('papers'))
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
my $authorList = $authorPageNoBullets ? [] : ul();
my $apageSep = "";

## Author/editor pages.
print "Writing author pages.\n" if $verbose>0;
my %authorsByAlpha = ();
foreach my $author (sort lastNameSorter (keys %authorPapers)) {

  if ($authorPageNoBullets) {
    push @$authorList, $apageSep, a(-href=>(cleanUrl($author).".html"),$author);
    $apageSep = " - ";
  } else {
    $authorList->appendChild(li(a(-href=>(cleanUrl($author).".html"),$author)));
  }

  my $lastName = pullLastName($author);
  $lastName =~ s/^\\[^a-zA-Z]//; # Remove an accent-adding command
                                 # from the start of the string.
  if ($lastName =~ /^([a-zA-Z])/) {
    my $idx = lc($1);
    push @{$authorsByAlpha{$idx}}, $author;
  } else {
    push @{$authorsByAlpha{'other'}}, $author;
  }

  open HTML, ">$htmlOutputDir/author/".cleanUrl($author).".html";
  print HTML authorHtml($author,
                        $authorPapers{$author}, $editorPapers{$author});
  close HTML;
}

## Close the all-authors page
print ALLAUTHORS html(head(title($allAuthorsTitle)),
                      body(pageHeader('authors'),
                           h1($allAuthorsTitle),
                           ($authorPageNoBullets
                            ? p(@$authorList, ".") : $authorList),
                           pageFooter('authors')));
close ALLAUTHORS;

## Make the authors-by-alpha pages
foreach my $idx (keys %authorsByAlpha) {
  my $alphaList = $authorPageNoBullets ? [] : ul();
  my $alphaSep = "";
  foreach my $author (@{$authorsByAlpha{$idx}}) {
    if ($authorPageNoBullets) {
      push @$alphaList, $alphaSep, a(-href=>('../'.cleanUrl($author).".html"),
                                     $author);
      $alphaSep = " - ";
    } else {
      $alphaList->appendChild(li(a(-href=>('../'.cleanUrl($author).".html"),
                                   $author)));
    }
  }

  open BYALPHA, ">$htmlOutputDir/author/alpha/$idx.html";
  print BYALPHA html(head(title($allAuthorsTitle . " - " . uc($idx))),
                     body(pageHeader(),
                          h1($allAuthorsTitle . " - " . uc($idx)),
                          ($authorPageNoBullets
                           ? p(@$alphaList, ".") : $alphaList),
                          pageFooter()));
  close BYALPHA;
}

## Open the all-keywords page
open ALLKEYWORDS, ">$htmlOutputDir/keyword/index.html";
my $keywordList = div();
my $keywordsPage = html(head(title($allKeywordTitle)),
                        body(pageHeader('keywords'),
                             h1($allKeywordTitle), $keywordList,
                             pageFooter('keywords')));

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

my @authorsLineItems = (a(-href=>"author/index.html", $allAuthorsTitle));
my $alSep = ": ";
my @alKeys = keys %authorsByAlpha;
foreach my $idx (sort { $a cmp $b } @alKeys) {
  unless ($idx eq 'other') {
    push @authorsLineItems, $alSep, a(-href=>"author/alpha/$idx.html",
                                      uc($idx));
    $alSep = " - ";
  }
}
if (defined $authorsByAlpha{other}) {
    push @authorsLineItems, $alSep, a(-href=>"author/alpha/other.html",
                                      'other');
}

my $topBody = body(h1($mainTitle),
                   ul(li(a(-href=>"papers/index.html", "$allPapersTitle.")),
                      li(@authorsLineItems),
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
  my $editorRefs = shift;
  my @body = (pageHeader(), h1($author));

  if ($#{$refs} > -1) {
    my $paperList = ul();
    foreach my $ref (@$refs) {
      appendElementItem($paperList, $ref);
    }
    push @body, h2($asAuthorSubhead), $paperList;
  }

  if ($#{$editorRefs} > -1) {
    my $editorList = ul();
    foreach my $ref (@$editorRefs) {
      appendElementItem($editorList, $ref);
    }
    push @body, h2($asEditorSubhead), $editorList;
  }

  return html(
    head(title($author)),
    body(@body, pageFooter()));
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
    body(pageHeader(), h1($showKeyword), $paperList, pageFooter()));
}

sub entryDetailItems {
  my $tag = shift;
  my $bibtexType = $lib->type($tag);

  my @body = ();
  my @sep = ();
  my $commenced = 0;

  my $uncommenced = sub {
    $commenced = 0;
  };

  my $setSeparator = sub {
    @sep = @_;
  };

  my $separated = sub {
    my $item = shift;
    my $actuals = shift;
    my $nextSep = shift;

    if (defined $item && $item ne '') {
      push @body, @sep, @$actuals;
      $setSeparator->(@$nextSep) if defined $nextSep;
      $commenced = 1;
    }
  };

  my $sepByCommenced = sub {
    my $item = shift;
    my $freshActuals = shift;
    my $continuedActuals = shift;
    my $nextSep = shift;

    if ($commenced) {
      $separated->($item, $continuedActuals, $nextSep);
    } else {
      $separated->($item, $freshActuals, $nextSep);
    }
  };

  my $simpleSeparated = sub {
    my $item = shift;
    my $nextSep = shift;
    $separated->($item, [$item], $nextSep);
  };

  my $editorList=$lib->field($tag, 'editor');
  my @editors = split / and /, $editorList;
  $editorList =~ s/ and /, /g;

  my $title=$lib->field($tag, 'title');
  my $booktitle=$lib->field($tag, 'booktitle');
  my $journal=$lib->field($tag, 'journal');
  my $crossref=$lib->field($tag, 'crossref');
  my $volume=$lib->field($tag, 'volume');
  my $number=$lib->field($tag, 'number');
  my $year = $lib->field($tag, 'year');
  my $institution = $lib->field($tag, 'institution');
  my $pages = $lib->field($tag, 'pages');
  $pages =~ s/--+/-/g if defined $pages;
  my $month = $lib->field($tag, 'month');
  my $note = $lib->field($tag, 'note');
  my $publisher = $lib->field($tag, 'publisher');
  my $address = $lib->field($tag, 'address');
  my $edition = $lib->field($tag, 'edition');
  my $howpublished = $lib->field($tag, 'howpublished');
  my $chapter = $lib->field($tag, 'chapter');
  my $series = $lib->field($tag, 'series');
  my $organization = $lib->field($tag, 'organization');
  my $school = $lib->field($tag, 'school');
  my $type = $lib->field($tag, 'type');

  my $separatedDate = sub {
    my $nextSep = shift;
    my $dateSep = (defined $month && $month ne '') ? "$month " : '';
    if (defined $year && $year ne '') {
      push @body, @sep, $dateSep, $year;
      $setSeparator->(@$nextSep) if defined $nextSep;
      $commenced = 1;
    }
  };

  my $separatedEdition = sub {
    my $nextSep = shift;
    if (defined $edition && $edition ne '') {
      if ($edition =~ /^[0-9]+$/) {
        push @body, @sep, makeCardinal($edition), " edition";
      } else {
        push @body, @sep, "edition ", $edition;
      }
      $setSeparator->(@$nextSep) if defined $nextSep;
      $commenced = 1;
    }
  };

  if ($bibtexType eq 'ARTICLE') {
    $setSeparator->(br);
    $separated->($journal, [i($journal)], [' ']);
    $separated->($volume, [b($volume)], [':']);
    $simpleSeparated->($number, [', ']);

    $setSeparator->(', ') if $commenced;
    $separatedDate->();
    $separated->($pages, ['p.', $pages]);

    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'BOOK') {
    push @body, $editorList, ' (', ($#editors>0 ? "eds." : "ed."), ')'
        if defined $editorList && $editorList ne '';

    $setSeparator->(br);
    $simpleSeparated->($publisher, [', ']);
    $simpleSeparated->($address, [', ']);
    $separatedDate->();

    $setSeparator->(br);
    $uncommenced->();
    $simpleSeparated->($series, [', ']);
    $sepByCommenced->($volume, ["Volume ",$volume],["volume ",$volume], [', ']);
    $sepByCommenced->($number, ["Number ",$number],["number ",$number], [', ']);
    $separatedEdition->();

    $setSeparator->(br);
    push @body, br, 'AKA ', i($booktitle)
        if defined $booktitle && $booktitle ne '' && $booktitle ne $title;
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'BOOKLET') {
    $setSeparator->(br);
    $separated->($howpublished, [uc1($howpublished)]);
    $simpleSeparated->($address);
    $separatedDate->();
    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'INBOOK') {
    push @body, br, 'In ';
    push @body, $editorList, ' (ed', ($#editors>0 ? 's' : ''), '.), '
        if defined $editorList && $editorList ne '';
    push @body, $type, " " if defined $type && $type ne '';
    push @body, ((defined $booktitle && $booktitle ne '')
                 ? i($booktitle) : 'book title not given ');

    $setSeparator->(', ');
    $separated->($chapter, ["Chapter ", $chapter]);
    $separated->($pages, ["p.", $pages]);
    $simpleSeparated->($type);

    $setSeparator->(br);
    $simpleSeparated->($publisher);
    $simpleSeparated->($address);
    $separatedDate->();

    $setSeparator->(br);
    $uncommenced->();
    $simpleSeparated->($series, [', ']);
    $sepByCommenced->($volume, ["Volume ",$volume],["volume ",$volume], [', ']);
    $sepByCommenced->($number, ["Number ",$number],["number ",$number], [', ']);
    $separatedEdition->();

    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'INCOLLECTION') {
    push @body, br, 'In ';
    push @body, $editorList, ' (ed', ($#editors>0 ? 's' : ''), '.), '
        if defined $editorList && $editorList ne '';
    push @body, ((defined $booktitle && $booktitle ne '')
                 ? i($booktitle) : 'collection title not given ');

    $setSeparator->(', ');
    $separated->($chapter, ["Chapter ", $chapter]);
    $separated->($pages, ["p.", $pages]);
    $simpleSeparated->($type);

    $setSeparator->(br);
    $simpleSeparated->($publisher);
    $simpleSeparated->($address);
    $separatedDate->();

    $setSeparator->(br);
    $uncommenced->();
    $simpleSeparated->($series, [', ']);
    $sepByCommenced->($volume, ["Volume ",$volume],["volume ",$volume], [', ']);
    $sepByCommenced->($number, ["Number ",$number],["number ",$number], [', ']);
    $separatedEdition->();

    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'INPROCEEDINGS' || $bibtexType eq 'CONFERENCE') {
    push @body, br, 'In ';
    push @body, $editorList, ' (ed', ($#editors>0 ? 's' : ''), '.), '
        if defined $editorList && $editorList ne '';
    push @body, ((defined $booktitle && $booktitle ne '')
                 ? i($booktitle) : 'proceedings title not given ');

    $setSeparator->(', ');
    $separated->($chapter, ["Chapter ", $chapter]);
    $separated->($pages, ["p.", $pages]);
    $simpleSeparated->($type);

    $setSeparator->(br);
    $uncommenced->();
    $simpleSeparated->($series, [', ']);
    $sepByCommenced->($volume, ["Volume ",$volume],["volume ",$volume], [', ']);
    $sepByCommenced->($number, ["Number ",$number],["number ",$number], [', ']);
    $separatedEdition->();

    $setSeparator->(br);
    $simpleSeparated->($publisher, [', ']);
    $simpleSeparated->($organization, [', ']);
    $simpleSeparated->($address, [', ']);
    $separatedDate->();

    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'MANUAL') {
    $setSeparator->(br);
    $separatedEdition->([', ']);
    $simpleSeparated->($organization, [', ']);
    $simpleSeparated->($address, [', ']);
    $separatedDate->();

    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'MASTERSTHESIS') {
    push @body, br, (defined $type && $type ne '' ? $type : "Masters thesis");
    $setSeparator->(', ');
    $simpleSeparated->($school);
    $simpleSeparated->($address);
    $separatedDate->();
    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'MISC') {
    $setSeparator->(br);
    push @body, @sep, $howpublished
        if defined $howpublished && $howpublished ne '';
    $separatedDate->();
    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'PHDTHESIS') {
    push @body, br, (defined $type && $type ne '' ? $type : "Ph.D. thesis");
    $setSeparator->(', ');
    $simpleSeparated->($school);
    $simpleSeparated->($address);
    $separatedDate->();
    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'PROCEEDINGS') {
    push @body, $editorList, ' (ed', ($#editors>0 ? 's' : ''), '.), '
        if defined $editorList && $editorList ne '';

    $setSeparator->(br);
    $simpleSeparated->($publisher, [', ']);
    $simpleSeparated->($organization, [', ']);
    $simpleSeparated->($address, [', ']);
    $separatedDate->();

    $setSeparator->(br);
    $uncommenced->();
    $simpleSeparated->($series, [', ']);
    $sepByCommenced->($volume, ["Volume ",$volume],["volume ",$volume], [', ']);
    $sepByCommenced->($number, ["Number ",$number],["number ",$number], [', ']);
    $separatedEdition->([', ']);

    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'TECHREPORT') {
    push @body, br, (defined $type && $type ne '' ? $type : "Technical report");
    push @body, " ", $number if defined $number && $number ne '';
    $setSeparator->(', ');
    $simpleSeparated->($institution);
    $simpleSeparated->($address);
    $separatedDate->();
    $setSeparator->(br);
    $simpleSeparated->($note);

  } elsif ($bibtexType eq 'UNPUBLISHED') {
    push @body, br, "Unpublished";
    $separatedDate->();
    $setSeparator->(br);
    $simpleSeparated->($note);

  } else {
    push @body, br, "Unknown BibTeX type, $bibtexType";
    $setSeparator->(br);
    $separated->($editorList, ["Editors: ", $editorList]);
    $separated->($booktitle, ["Book title: ", $booktitle]);
    $separated->($journal, ["Journal: ", $journal]);
    $separated->($crossref, ["Crossref: ", $crossref]);

    $uncommenced->();
    $simpleSeparated->($series, [', ']);
    $sepByCommenced->($volume, ["Volume ",$volume],["volume ",$volume], [', ']);
    $sepByCommenced->($number, ["Number ",$number],["number ",$number], [', ']);
    $separatedEdition->([', ']);

    $setSeparator->(br);
    $separated->($pages, ["Pages: ", $pages]);
    $separated->($month, ["Month: ", $month]);
    $separated->($year, ["Year: ", $year]);
    $separated->($institution, ["Institution: ", $institution]);
    $separated->($publisher, ["Publisher: ", $publisher]);
    $separated->($address, ["Address: ", $address]);
    $separated->($howpublished, ["Howpublished: ", $howpublished]);
    $separated->($chapter, ["Chapter: ", $chapter]);
    $separated->($organization, ["Organization: ", $organization]);
    $separated->($school, ["School: ", $school]);
    $separated->($type, ["Type: ", $type]);
    $simpleSeparated->($note);
  }

  my $paperfile = $lib->field($tag, 'file');
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

  return @body;
}

sub makeCardinal {
  my $i = shift;
  return $i."th" if $i =~ /1[123]$/;
  return $i."st" if $i =~ /1$/;
  return $i."nd" if $i =~ /2$/;
  return $i."rd" if $i =~ /3$/;
  return $i."th";
}

sub entryHtml {
  my $tag = shift;
  my $title=$lib->field($tag, 'title');

  my $authorList=$lib->field($tag, 'author');
  my @authors = split / and /, $authorList;
  $authorList =~ s/ and /, /g;

  my @overAuthorLinks = ();
  my $sep = undef;
  foreach my $author (@authors) {
    push @overAuthorLinks, ', ' if $sep;
    push @overAuthorLinks, a(-href=>"../author/".cleanUrl($author).".html",
                             cleanString($author));
    $sep = 1;
  }

  my @starts = (pageHeader(), h1($title), @overAuthorLinks);
  my @details = entryDetailItems($tag);
  my @ends = ();

  # Abstract and annotation paragraphs
  my $abstract = $lib->field($tag, 'abstract');
  my $annote = $lib->field($tag, 'annote');
  if (defined $abstract && $abstract ne '') {
    my @pars = split /\n(\s*\n)+|\\par\b\s*/, $abstract;
    my $lead = b("$abstractLead. ");
    my $ab = blockquote();
    foreach my $par (@pars) {
      $ab->appendChild(p($lead, $par));
      $lead='';
    }
    push @ends, i($ab);
  }
  if (defined $annote && $annote ne '') {
    my @pars = split /\n(\s*\n)+|\\par\b\s*/, $annote;
    foreach my $par (@pars) {
      push @ends, p($par);
    }
  }

  # Endmatter
  my $srcfile = $lib->field($tag, '_file');
  push @ends, hr, "Source BibTeX: ", $srcfile, pageFooter();

  return html(
    head(title($title)),
    body(@starts, @details, @ends)
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
    push @downEditorLinks, a(-href=>"author/".cleanUrl($editor).".html",
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

  my $files = $lib->field($tag, 'file');
  if (defined $files && $files ne '') {
    my @files = split /$filesSep/, $files;
    my $fsep='';
    push @contents, " [";
    foreach my $file (@files) {
      my $slug = 'file';
      $slug = 'PDF' if $file =~ /\.pdf$/i;
      $slug = 'PS' if $file =~ /\.ps$/i;
      $slug = 'word' if $file =~ /\.doc$/i;
      $slug = 'text' if $file =~ /\.txt$/i;
      $slug = 'HTML' if $file =~ /\.html?$/i;
      push @contents, $fsep, a(-href=>"../$urlPathToPapersRoot/$file", $slug);
      $fsep = ', ';
    }
    push @contents, "]";
    $fin = '.';
  }

  push @contents, $fin;

  $enclosure->appendChild(li(@contents));
}

sub cleanLaTeX {
  my $s = shift;
  $s =~ s/(\\[^a-zA-Z0-9]){([a-zA-Z])}/$1$2/g;
  $s =~ s/{(\\[^a-zA-Z0-9][a-zA-Z])}/$1/g;
  return $s;
}

sub cleanString {
  my $s = shift;
  $s = cleanLaTeX($s);
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

sub pageHeader {
  my $for = shift;
  return div($mainTitle, ": ", navLineContents($for), hr);
}

sub pageFooter {
  my $for = shift;
  return div(hr, navLineContents($for));
}

sub navLineContents {
  my $for = shift;
  $for = '' unless defined $for;
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

=item B<--author-page-wrapped-list=FLAG>

A flag controlling the layout of the author list pages.  If this flag
is set, the authors are listed in a single paragraph, wrapped as
ordinary text.  Otherwise and by default, they are arranged vertically
in a bulleted list.

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

=item B<--as-author-subhead, --as-editor-subhead>

On the pages for an individual author/editor, the sections titles for
the lists of citations where the individual is an author and is an
editor.

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

=head2 Requirements

There are a small number of Perl packages that you may need to pull
from CPAN:

  HTML::HTML5::Builder
  BibTeX::Parser

And if you want to rebuild the GitHub README.md, then also:

  Pod::Markdown::Github

Everything else should be included with a standard Perl distribution.

=head1 AUTHOR

John Maraist, bibviz at maraist dot O R G, http://maraist.org

=head1 LICENSE

GPL3, see included

=cut
