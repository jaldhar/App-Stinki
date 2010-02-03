
=head1 NAME

App::Stinki - The Simple TItaNium wiKI

=head1 SYNOPSIS

=for example begin

    my $wiki = App::Stinki->new( PARAMS => {
        cfg_file => '/path/to/config',
    })->run;

=for example end

=head1 ABSTRACT

An instant wiki application that uses the Titanium framework.

=cut

package App::Stinki;

use warnings;
use strict;
use base 'Titanium';
use Carp qw/ croak /;
use English qw/ -no_match_vars /;
use URI::Escape;
use Wiki::Toolkit;

use Class::Delegator send => [
    qw/
      retrieve_node       retrieve_node_and_checksum
      verify_checksum     list_all_nodes
      list_recent_changes node_exists
      write_node          delete_node
      search_nodes        supports_phrase_searches
      format
      /
  ],
  to => 'wiki',
  ;

our %MAGIC_NODE;

=head1 VERSION

This document describes App::Stinki Version 0.1

=cut

our $VERSION = '0.1';

=head1 DESCRIPTION

Stinki lets you easily set up a wiki based on L<Wiki::Toolkit>.

=head1 METHODS

=head2 SUBCLASSED METHODS

=head3 setup

Called by the L<Titanium> framework when the application should initialize 
itself and load all necessary parameters. The wiki decides here what to do and 
loads all needed values from the configuration file, as C<setup> is not called 
directly.

The only required value in the configuration file is:

  store => $store

The store entry must be the Wiki::Toolkit::Store that this wiki resides in.

Most of the parameters to the constructor of Wiki::Toolkit can also be passed
here and will be passed on to the Wiki::Toolkit object.

=cut

sub setup {
    my ($self) = @_;

    $self->start_mode('display');
    $self->mode_param( \&decode_runmode );

    $self->run_modes(
        preview => 'render_editform',
        display => 'render_display',
        commit  => 'render_commit',
    );

    $self->tmpl_path( $self->config('tmpl_path') || undef );
    if ( !$self->tmpl_path ) {
        ( my $tp = 'App::Stinki' ) =~ s/::/\//gmsx;
        ( $tp = $INC{"$tp.pm"} ) =~ s/.pm//msx;
        $self->tmpl_path("$tp/templates");
    }

    __PACKAGE__->add_callback( 'load_tmpl', \&load_tmpl_callback );

    $self->run_modes( AUTOLOAD => 'display' );

    my $q = $self->query;

    my %default_config = (
        store          => './db',
        script_name    => $q->script_name,
        extended_links => 1,
        implicit_links => 1,
        node_prefix    => $q->script_name . '/display/',
    );

    my %args;
    for ( keys %default_config ) {
        $args{$_} =
          defined $self->config($_) ? $self->config($_) : $default_config{$_};
    }

    $self->param( 'script_name' => $args{script_name} );

    my $wiki = Wiki::Toolkit->new(%args);
    if ( !$wiki ) {
        croak "Could not load Wiki::Toolkit\n";
    }
    $self->param( wiki => $wiki );

    # Maybe later add the connection to the database here...

    return;
}

=head3 teardown

Called by L<Titanium> when the
program ends. Currently, it does nothing in App::Stinki.

=cut

sub teardown {
    my ($self) = @_;

    # Maybe later add the database disconnect here ...
    return;
}

=head2 RUN MODES

=head3 render_display

Shows a wiki page.

=cut

sub render_display {
    my ($self) = @_;

    return $self->render( 'page_display.html', ['preview'] );
}

=head3 render_editform

Shows the form for editting wiki content.

=cut

sub render_editform {
    my ($self) = @_;

    return $self->render(
        'page_edit.html',
        [ 'display', 'commit' ],
        qw( content raw )
    );
}

=head3 render_conflict

Displayed when two edits conflict.

=cut

sub render_conflict {
    my ($self) = @_;

    $self->render(
        'page_conflict.html',
        [ 'display', 'commit' ],
        qw( content raw submitted_content )
    );

    return;
}

=head3 render_commit

Renders either the display page or a page indicating that
there was a version conflict.

=cut

sub render_commit {
    my ($self)            = @_;
    my $q                 = $self->query;
    my $node              = $self->param('node_title');
    my $submitted_content = $q->param('content');

    $submitted_content =~ s/\r\n/\n/gmsx;
    my $cksum = $q->param('checksum');
    my $written;
    if ($cksum) {
        $written = $self->write_node( $node, $submitted_content, $cksum );
    }

    if ( $written || !defined $cksum ) {
        $self->header_type('redirect');
        $self->header_props(
            -url => $self->node_url( node => $node, mode => 'display' ) );
    }
    else {
        $self->param( submitted_content => $submitted_content );
        return $self->render_conflict();
    }

    return;
}

=head2 OTHER METHODS

=head3 decode_runmode

Decides what to do based upon the URL. It also initializes the following 
L<Titanium> params :

  html_node_title
  url_node_title
  node_title

  version
  checksum
  content
  raw

=cut

sub decode_runmode {
    my ($self)     = @_;
    my $q          = $self->query;
    my $node_title = $q->param('node');
    my $action     = $q->param('action');

    # Magic runmode decoding :
    my $runmodes = join q{|}, map { quotemeta } $self->run_modes;
    if ( $q->path_info =~ m{\A/($runmodes)/(.*)}msx ) {
        $action = $1;
        $node_title ||= $2;
        $q->param( 'action', q{} );
    }
    $action     ||= 'display';
    $node_title ||= 'index';
    $node_title = uri_unescape($node_title);

    $self->param(
        html_node_title => HTML::Entities::encode_entities($node_title) );
    $self->param( url_node_title => uri_escape($node_title) );
    $self->param( node_title     => $node_title );

    my ( %node, $raw );
    if ( exists $App::Stinki::MAGIC_NODE{$node_title} ) {
        my $error = eval {
            %node =
              $App::Stinki::MAGIC_NODE{$node_title}->( $self, $node_title );
        };
        croak $EVAL_ERROR if $EVAL_ERROR;
        $self->param( version  => $node{version} );
        $self->param( checksum => $node{checksum} );
        $self->param( content  => $node{content} );
    }
    else {
        %node = $self->wiki->retrieve_node($node_title);
        $raw  = $node{content};
        $self->param( raw      => $raw );
        $self->param( content  => $self->wiki->format($raw) );
        $self->param( checksum => $node{checksum} );
    }

    if ( !defined $raw ) {
        $action = 'display';
    }
    return $action;
}

=head3 inside_link(%ARGS)

A convenience function to create a link within the Wiki. The parameters are :

  title  => 'Link title'
  target => 'Node name'
  node   => 'Node name' # synonymous to target
  mode   => 'display' # or 'edit' or 'commit'

If C<title> is missing, C<target> is used as a default, if C<mode> is missing,
C<display> is assumed. Everything is escaped in the right way. This method
is mostly intended for plugins. A possible API change might be a move of
this function into L<App::Stinki::Plugin>.

=cut

sub inside_link {
    my ( $self, %args ) = @_;
    $args{node}  ||= $args{target};
    $args{title} ||= $args{node};

    return
        q{<a href='}
      . $self->node_url(%args) . q{'>}
      . HTML::Entities::encode_entities( $args{title} ) . '</a>';
}

=head3 load_tmpl_callback(\%ht_params, \%tmpl_params. $tmpl_file)

Sets some global configuration options for HTML::Template.

=cut

sub load_tmpl_callback {
    my ( $self, $ht_params, $tmpl_params, $tmpl_file ) = @_;

    $ht_params->{die_on_bad_params} = 0;
    $ht_params->{path}              = $self->tmpl_path;
    $ht_params->{filename}          = $tmpl_file;

    foreach my $param (
        qw/ node_title script_name node_prefix version content checksum/)
    {
        $tmpl_params->{$param} = $self->param($param);
    }

    $self->header_props( -title => $self->param('node_title') );

    return;
}

=head3 node_url(%ARGS)

Creates a link to a node suitable to use as the C<href> attribute.
The arguments are :

  node => 'Node title'
  mode => 'display' # or 'edit' or 'commit'

The default mode is L<display>.

=cut

sub node_url {
    my ( $self, %args ) = @_;
    if ( !exists $args{mode} ) {
        $args{mode} = 'display';
    }
    return
        $self->param('script_name')
      . "/$args{mode}/"
      . uri_escape( $args{node} );
}

=head3 render(%ARGS)

Renders a template and outputs HTML.
The arguments are :

  templatename => 'template.html',  # an HTML::Template file
  actions => [ 'display ], # or 'edit' or 'commit'. Maybe all three.
  params => [ 'content' ], # params to be passed to HTML::Template

=cut

sub render {
    my ( $self, $templatename, $actions, @params ) = @_;

    my $template = $self->load_tmpl($templatename);
    $self->_load_actions( $template, map { $_ => 1 } @{$actions} );
    for (@params) {
        $template->param( $_ => $self->param($_) );
    }

    return $template->output;
}

sub _load_actions {
    my ( $self, $template, %actions ) = @_;

    for ( keys %actions ) {
        $template->param( $_, $actions{$_} );
    }

    return;
}

=head3 wiki

This is the accessor method to the contained Wiki::Toolkit class.

=cut

sub wiki { my $self = shift; return $self->param('wiki'); }

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

L<Titanium>, L<Wiki::Toolkit>

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

1;    # End of App::Stinki

__END__

