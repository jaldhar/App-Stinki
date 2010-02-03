package App::Stinki::Setup;

use warnings;
use strict;

use App::Stinki;
use Carp qw/ carp croak /;
use Digest::MD5 qw/ md5_hex /;
use English qw/ -no_match_vars /;
use Module::Load;
use Wiki::Toolkit;

our $VERSION = '0.1';

=head1 NAME

App::Stinki::Setup - Set up the wiki and fill content into some basic pages.

=head1 DESCRIPTION

This is a simple utility module that given a database sets up a complete wiki within it.

=head1 SYNOPSIS

=for example begin

  setup( dbtype => 'sqlite', dbname => "mywiki.db" );
  # This sets up a SQLite wiki within the file mywiki.db

  setup( dbtype => 'mysql', dbname => "wiki", dbuser => "wiki", dbpass => "secret", file => 'nodeball.txt' );
  # This sets up a MySQL wiki and loads the nodes from the file nodeball.txt

=for example end

=cut

my %stores = (
    sqlite => 'SQLite',
    mysql  => 'MySQL',
    pg     => 'Pg',
);

=head1 FUNCTIONS

=head2 get_store(%ARGS)

C<get_store> creates a store from a hash of parameters. There
are two mandatory parameters  :

  dbtype => 'mysql'

This is the type of the database. Recognized values are C<mysql>,
C<sqlite> and C<pg>.

  dbname => 'wiki'

This is the name of the database.

The remaining parameters are optional :

  dbuser => 'wikiuser'

The database user

  dbpass => 'secret'

The password for the database

  setup => 1

Create the database unless it exists already

  clear => 1

Wipe all nodes from the database before reinitializing
it. Only valid if C<setup> is also true.

  check => 1

Check that a node called C<index> exists. This raises
an error if the database exists but is empty.

=cut

sub get_store {
    my %args = @_;

    my @setup_args;
    my $dbtype;

    push @setup_args, $args{dbname};
    for (qw(dbuser dbpass)) {
        if ( exists $args{$_} ) {
            push @setup_args, $args{$_};
        }
    }

    $dbtype = $args{dbtype};

    if ( !exists $stores{ lc $dbtype } ) {
        croak "Unknown database type $dbtype";
    }
    $dbtype = $stores{ lc $dbtype };

    my $error = eval {
        load "Wiki::Toolkit::Store::$dbtype";
        load "Wiki::Toolkit::Setup::$dbtype";
    };
    if ($EVAL_ERROR) {
        croak "$EVAL_ERROR\n";
    }

    if ( $args{setup} ) {
        no strict 'refs';    ## no critic 'ProhibitNoStrict'
        if ( $args{clear} ) {
            &{"Wiki::Toolkit::Setup::${dbtype}::cleardb"}(@setup_args);
        }
        &{"Wiki::Toolkit::Setup::${dbtype}::setup"}(@setup_args);
    }

    # get the wiki store :
    my $store = "Wiki::Toolkit::Store::$dbtype"->new(%args);
    if ( !$store ) {
        carp "Couldn't get store for $args{dbname}";
    }

    if ( $args{check} ) {
        $store->retrieve_node('index');
    }

    return $store;
}

=head2 setup(%ARGS)

Creates a new database and initializes it. Takes the
same parameters as C<get_store> and two additional
optional parameters :

  nocontent => 1

Prevents loading the three default nodes from the module
into the wiki.

  force => 1

Overwrites nodes with the loaded content even if they
already exists.

=cut

sub setup {
    my (%args) = @_;

    if ( !$args{dbtype} ) {
        croak 'No dbtype given';
    }

    my $store = get_store( %args, setup => 1 );

    if ( !$args{nocontent} ) {
        if ( !$args{silent} ) {
            print "Loading content\n" or croak "$OS_ERROR\n";
        }
        load_nodeball( store => $store, );
    }

    $store->dbh->disconnect;

    return;
}

=head2 setup_if_needed(%ARGS)

Creates a new database and initializes it if no
current database is found. Takes the same arguments
as C<setup>

=cut

sub setup_if_needed {
    my (%args) = @_;

    my $store;
    my $error = eval { $store = get_store( %args, check => 1 ); };
    if ( $EVAL_ERROR || !$store ) {
        setup(%args);
    }
    return;
}

=head2 load_nodeball

Loads a nodeball into the wiki. A nodeball is a set of nodes
in a text file like this :

  __NODE__
  Title: TestNode

  This is a test node. It
  consists of content that will be formatted through the
  wiki formatter.

  __NODE__
  Title: AnotherTestNode

  You know it.

The routine takes the following parameters additional
to the usual database parameters :

  fh => \*FILE

Loads the nodeball from the filehandle FILE.

  file => 'nodeball.txt'

Loads the nodeball from the specified file.

=cut

sub load_nodeball {
    my (%args) = @_;

    my $F;
    if ( $args{file} ) {
        open $F, '<', $args{file}    ## no critic 'RequireBriefOpen'
          or croak "Couldn't read nodeball from '$args{file}' : $OS_ERROR\n";
    }
    elsif ( $args{fh} ) {
        $F = *{ $args{fh} };
    }
    else {
        $F = *DATA;
    }

    my $store = $args{store} || get_store(%args);

    if ( !$args{nocontent} ) {
        my $wiki = Wiki::Toolkit->new(
            store  => $store,
            search => undef
        );

        my $offset = tell $F;
        my @NODES  = map {
            /^Title:\s+(.*?)\r?\n(.*)/msx
              ? { title => $1, content => $2 }
              : ()
        } do { undef $RS; split /__NODE__/msx, <$F> };
        seek $F, $offset, 0;

        commit_content( %args, wiki => $wiki, nodes => \@NODES, );

        undef $wiki;
    }
    close $F or croak "$OS_ERROR\n";

    return;
}

=head2 commit_content(%ARGS)

Loads a set of nodes into the wiki database. Takes the following
parameters :

  wiki => $wiki

An initialized Wiki::Toolkit.

  force => 1

Force overwriting existing nodes

  silent => 1

Do not print out normal messages. Warnings still get raised.

  nodes => \@NODES

A reference to an array of hash references. Each element should
have the following structure :

  { title => 'A node title', content => 'Some content' }


=cut

sub commit_content {
    my %args = @_;
    my $wiki = $args{wiki};

    if ( !$wiki ) {
        croak q{No wiki passed in the 'wiki' parameter};
    }

    my @nodes = @{ $args{nodes} };
    foreach my $node (@nodes) {
        my $title = $node->{title};

        my %old_node = $wiki->retrieve_node($title);
        if ( not $old_node{content} or $args{force} ) {
            my $content = $node->{content};
            $content =~ s/\r\n/\n/gmsx;
            my $cksum = $old_node{checksum};
            my $written = $wiki->write_node( $title, $content, $cksum );
            if ($written) {
                if ( !$args{silent} ) {
                    print "(Re)initialized node '$title'\n"
                      or croak "$OS_ERROR\n";
                }
            }
            else {
                carp "Node '$title' not written\n";
            }
        }
        else {
            carp "Node '$title' already contains data. Not overwritten.";
        }
    }

    return;
}

1;

=head1 SEE ALSO

L<App::Stinki>, L<Wiki::Toolkit>

=head1 AUTHOR

Jaldhar H. Vyas, C<< <jaldhar at braincells.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2010 Consolidated Braincells Inc., all rights reserved.

This distribution is free software; you can redistribute it and/or modify it
under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 2, or (at your option) any later version, or

b) the Artistic License version 2.0.

The full text of the license can be found in the LICENSE file included
with this distribution.

=cut

__DATA__
__NODE__
Title: index
This is the main page of your new wiki. It was preset
by the automatic content setup.

If your wiki will be accessible to the general public, you might want
to make this node read only by loading the [App::Stinki::Plugin::Static]
plugin for this node :

     use App::Stinki::Plugin::Static index => 'Text for the index node';

This node was loaded initially by the setup program among other nodes :

    * [Wiki Howto]
    * [App::Stinki]
__NODE__
Title: Wiki Howto

This is a wiki, things are simple :

    1. Everybody can edit any node.
    2. Linking between nodes is done by putting the text in square brackets.
    3. Lists are created by indenting stuff 4 spaces.
    4. Paragraphs are delimited by an empty line
    5. Dividers are "----"

Some examples :

    * An unordered list

    1. First item
    2. Second item
    3. third item

    a. Another
    b. List

Some normal text. Note that
line
breaks
happen where you type them and where
they seem necessary.

    Some(code);
      in some programming language

[A Link]. [With a different target node|Another link]

Have fun.


__NODE__
Title: App::Stinki

This wiki is powered by App::Stinki (at http://search.cpan.org/search?mode=module&query=App::Stinki ).
App::Stinki was written by Max Maischein (cgi-wiki-simple@corion.net). Please report bugs
through the CPAN RT at http://rt.cpan.org/NoAuth/Bugs.html?Dist=CGI-Wiki-Simple .

App::Stinki again is based on Wiki::Toolkit (at http://search.cpan.org/search?mode=module&query=Wiki::Toolkit )
by Kate Pugh.

