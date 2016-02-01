package BibLib;
{
  $BibLib::VERSION = '0.01';
}
# ABSTRACT: Another pure perl BibTeX parser
use warnings;
use strict;

use BibTeX::Parser;
use IO::File;

our $verbose=0;

sub new {
  my $class = shift;
  my $this = bless {
    strings => {
      jan => "January",
      feb => "February",
      mar => "March",
      apr => "April",
      may => "May",
      jun => "June",
      jul => "July",
      aug => "August",
      sep => "September",
      oct => "October",
      nov => "November",
      dec => "December",
    },
    entries   => {},
  }, $class;
  $this->load(@_);
  return $this;
}

sub load {
  my $this = shift;
  while (my $file = shift) {
    print "- Parsing $file\n" if $verbose>1;
    my $fh     = IO::File->new($file);
    my $parser = BibTeX::Parser->new($fh);
    $parser->{strings} = $this->{strings};
    while (my $entry = $parser->next) {
      $entry->{_file} = $file;
      if ($entry->parse_ok) {
        if (defined $this->{entries}{$entry->key}) {
          warn "Skipping duplicate entry ", $entry->key, " in $file\n";
        } else {
          $this->{entries}{$entry->key} = $entry;
        }
      } else {
        warn "Error parsing file: " . $entry->error;
      }
    }
  }
}

sub entry {
  my ($self, $tag) = @_;
  return $self->{entries}{$tag} if exists $self->{entries}{$tag};
}

sub field {
  my ($self, $tag, $field) = @_;
  if (exists $self->{entries}{$tag}) {
    if (exists $self->{entries}{$tag}{$field}) {
      return $self->{entries}{$tag}{$field};
    } elsif (exists $self->{entries}{$tag}{crossref}) {
      return $self->field($self->{entries}{$tag}{crossref}, $field);
    }
  }
}

sub authors {
  my ($self, $tag) = @_;
  if (exists $self->{entries}{$tag}) {
    return $self->{entries}{$tag}->author;
  }
}

sub editors {
  my ($self, $tag) = @_;
  if (exists $self->{entries}{$tag}) {
    return $self->{entries}{$tag}->editor;
  }
}

sub type {
  my ($self, $tag) = @_;
  if (exists $self->{entries}{$tag}) {
    return $self->{entries}{$tag}->type;
  }
}

sub entries {
  my $self = shift;
  return keys %{$self->{entries}};
}

1;
