package App::Stinki::Plugin::RecentChanges;
use warnings;
use strict;
use App::Stinki::Plugin();
use HTML::Entities;

our $VERSION = '0.1';

=head1 NAME

App::Stinki::Plugin::RecentChanges - Node that lists the recent changes

=head1 DESCRIPTION

This node lists the nodes that were changed in your wiki. This only works for 
nodes that are stored within a Wiki::Tookit::Store::Database, at least until I 
implement more of the store properties for the plugins as well.

=head1 SYNOPSIS

=for example begin

  use App::Stinki;
  use App::Stinki::Plugin::RecentChanges( name => 'LastWeekChanges', days => 7 );
  # also
  use App::Stinki::Plugin::RecentChanges( name => 'Recent20Changes', last_n_changes => 20 );
  # also
  use App::Stinki::Plugin::RecentChanges( name => 'RecentFileChanges', days => 14, re => qr/^File:(.*)$/ );
  # This will display all changed nodes that match ^File:

=for example end

=cut

our %ARGS;

sub import {
    my ( $module, %node_args ) = @_;
    my $node = delete $node_args{name};
    $ARGS{$node} = {%node_args};
    $ARGS{$node}->{re} ||= '^(.*)$';
    App::Stinki::Plugin::register_nodes( module => $module, name => $node );

    return;
}

=head1 FUNCTIONS

=head2 retrieve_node(%ARGS)

TODO

=cut

sub retrieve_node {
    my (%node_args) = @_;

    my $node   = $node_args{name};
    my %params = %{ $ARGS{$node} };

    my $re = delete $params{re} || '^(.*)$';
    my %nodes = map {
        $_->{name} =~ /$re/msx
          ? ( $_->{name} => [ $1, $_->{last_modified} ] )
          : ()
    } $node_args{wiki}->list_recent_changes(%params);

    return (
        '<table class="RecentChanges">' . join(
            "\n",
            map {
                '<tr><td>'
                  . $node_args{wiki}
                  ->inside_link( node => $_, title => $nodes{$_}->[0] )
                  . '</td><td>'
                  . $nodes{$_}->[1]
                  . '</td></tr>'
              }
              reverse sort { $nodes{$a}->[1] cmp $nodes{$b}->[1] }
              keys %nodes
          )
          . '</table>',
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
