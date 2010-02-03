
=head1 NAME

App::Stinki::Plugin - Base class for App::Stinki plugins.

=head1 SYNOPSIS

=for example begin

  package App::Stinki::Plugin::MyPlugin;
  use warnings;
  use strict;
  use Carp qw/ croak /;
  use App::Stinki::Plugin( name => 'MyPlugin' );

  sub retrieve_node_data {
    my ($wiki) = shift;

    my %args = scalar @_ == 1 ? ( name => $_[0] ) : @_;
    croak "No valid node name supplied"
      unless $args{name};

    # $args{name} is the node name
    # $args{version} is the node version, if no version is passed, means current
    # ... now actually retrieve the content ...
    my @results = ("Hello world",0,"");

    my %data;
    @data{ qw( content version last_modified ) } = @results;
    $data{checksum} = md5_hex($data{content});
    return wantarray ? %data : $data{content};
  };

  # Alternatively, if your plugin can handle more than one node :
  package App::Stinki::Plugin::MyMultiNodePlugin;
  use strict;
  use App::Stinki::Plugin (); # No automatic import

  sub import {
    my ($module,@nodenames) = @_;
    App::Stinki::Plugin::register_nodes(module => $module, names => [@nodenames]);
  };

=for example end

=cut

package App::Stinki::Plugin;

use strict;
use warnings;
use Wiki::Toolkit;
use App::Stinki;
use Carp qw/ croak /;
use Digest::MD5 qw/ md5_hex /;

=head1 VERSION

This document describes App::Stinki::Plugin Version 0.1

=cut

our $VERSION = 0.1;

=head1 DESCRIPTION

This is the base class for special interactive Wiki nodes where the content
is produced programmatically, like the LatestChanges page and the AllNodes
page. A plugin subclass implements
more or less the same methods as a Wiki::Toolkit::Store - a later refactoring
might convert all Plugin-subclasses to Wiki::Toolkit::Store subclasses or vice-versa.

=cut

sub import {
    my ( $class, %args ) = @_;
    my ($module) = caller;
    my %names;

    for (qw(name names)) {
        if ( exists $args{$_} ) {
            if ( ref $args{$_} ) {
                for ( @{ $args{$_} } ) {
                    $names{$_} = 1;
                }
            }
            else {
                $names{ $args{$_} } = 1;
            }
        }
    }

    register_nodes( module => $module, names => [ sort keys %names ] );

    return;
}

=head1 FUNCTIONS

=head2 register_nodes(%ARGS)

TODO

=cut

sub register_nodes {
    my (%args)   = @_;
    my ($module) = $args{module};
    my (%names);

    for (qw(name names)) {
        if ( exists $args{$_} ) {
            if ( ref $args{$_} ) {
                for ( @{ $args{$_} } ) {
                    $names{$_} = 1;
                }
            }
            else {
                $names{ $args{$_} } = 1;
            }
        }
    }
    my @names = keys %names;
    if ( !@names ) {
        croak "Need the node name as which to install $module";
    }

    # Install our callback to the plugin
    no strict 'refs';    ## no critic 'ProhibitNoStrict'
    my $handler = $args{code} || \&{"${module}::retrieve_node"};

    for (@names) {
        $App::Stinki::MAGIC_NODE{$_} = sub {
            my $wiki = shift;
            my %callargs = scalar @_ == 1 ? ( name => $_[0] ) : @_;
            $callargs{wiki} = $wiki;
            if ( !$callargs{name} ) {
                croak 'No valid node name supplied';
            }
            my @results = $handler->(%callargs);
            if ( !scalar @results ) {
                @results = ( q{}, 0, q{} );
            }
            my %data;
            @data{qw( content version last_modified )} = @results;
            $data{checksum} = md5_hex( $data{content} );
            return wantarray ? %data : $data{content};
        };
    }

    return;
}

=head1 BUGS

There are no known problems with this module.

Please report any bugs or feature requests to
C<bug-app-stinki at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Stinki>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the perldoc
command.

    perldoc App::Stinki

You can also look for information at:

    Search CPAN
        http://search.cpan.org/dist/App-Stinki

    CPAN Request Tracker:
        http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Stinki

    AnnoCPAN, annotated CPAN documentation:
        http://annocpan.org/dist/App-Stinki

    CPAN Ratings:
        http://cpanratings.perl.org/d/App-Stinki

=head1 SEE ALSO

L<App::Stinki>, L<Wiki::Toolkit>

=head1 THANKS

Originally based on L<CGI::Wiki::Simple> by Max Maischein C<< <corion@cpan.org> >>

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

1;    # End of App::Stinki::Plugin

__END__

