package App::Stinki::Plugin::Static;
use strict;
use warnings;
use App::Stinki::Plugin();

our $VERSION = 0.1;

my %static_content;

=head1 NAME

App::Stinki::Plugin::Static - Supply static text as node content

=head1 DESCRIPTION

This node supplies static text for a node. This text can't be changed. You 
could use a simple HTML file instead. No provisions are made against users 
wanting to edit the page. They can't save the data though.

=head1 SYNOPSIS

=for example begin

  use App::Stinki;
  use App::Stinki::Plugin::Static( Welcome  => "There is an <a href='entrance'>entrance</a>. Speak <a href='Friend'>Friend</a> and <a href='Enter'>Enter</a>.",
                                   Enter    => "The <a href='entrance'>entrance</a> stays closed.",
                                   entrance => "It's a big and strong door.",
                                   Friend   => "You enter the deep dungeons of <a href='Moria'>Moria</a>.",
                                 );
  # nothing else is needed

=for example end

=cut

sub import {
    my ( $module, %args ) = @_;

    for my $node ( keys %args ) {
        $static_content{$node} = $args{$node};
        App::Stinki::Plugin::register_nodes( module => $module, name => $node );
    }

    return;
}

=head1 FUNCTIONS

=head2 retrieve_node(%ARGS)

TODO

=cut

sub retrieve_node {
    my (%args) = @_;

    return ( $static_content{ $args{name} }, '0', q{} );
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
