package App::Stinki::Plugin::NodeList;
use warnings;
use strict;
use App::Stinki::Plugin();
use HTML::Entities;

our $VERSION = 0.1;

=head1 NAME

App::Stinki::Plugin::NodeList - Node that lists all existing nodes on a wiki

=head1 DESCRIPTION

This node lists all nodes in your wiki. Think of it as the master index to your wiki.

=head1 SYNOPSIS

=for example begin

  use App::Stinki;
  use App::Stinki::Plugin::NodeList( name => 'AllNodes' );
  # nothing else is needed

  use App::Stinki::Plugin::NodeList( name => 'AllCategories', re => qr/^Category:(.*)$/ );

=for example end

=cut

our %RE;

sub import {
    my ( $module, %args ) = @_;
    my $node = $args{name};
    $RE{$node} = $args{re} || '\A(.*)\z';
    App::Stinki::Plugin::register_nodes( module => $module, name => $node );

    return;
}

=head1 FUNCTIONS

=head2 retrieve_node(%ARGS)

TODO

=cut

sub retrieve_node {
    my (%args) = @_;

    my $node = $args{name};
    my $re   = $RE{$node};
    my %nodes =
      map { /$re/msx ? ( $_ => $1 ) : () }
      ( $args{wiki}->list_all_nodes, keys %App::Stinki::MAGIC_NODE );

    return (
        '<ul>' . join(
            "\n",
            map {
                    '<li>'
                  . $args{wiki}->inside_link( node => $_, title => $nodes{$_} )
                  . '</li>'
              }
              sort { uc $nodes{$a} cmp uc $nodes{$b} }
              keys %nodes
          )
          . '</ul>',
        0,
        q{}
    );
}

=head1 SEE ALSO

L<App::Stinki>

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

1;
