package IPC::PrettyPipe::Render::Struct;

# ABSTRACT: rendering a pipe as Perl structures

use Carp;
use Template::Tiny;
use Safe::Isa;

use Types::Standard -all;
use Type::Params qw[ validate ];

use Moo;


our $VERSION = '0.13';

use namespace::clean;


=method new

  $renderer = IPC::PrettyPipe::Render::Template::Tiny->new( %attr );

Construct a new renderer.  Typically this is done automatically by L<IPC::PrettyPipe>.

=cut

=method render

  $renderer->render( $pipe );

=cut

sub render {
    my ( $self, $pipe ) = @_;
    return _render_pipe( $pipe);
}

sub _render_pipe {
    my $pipe = shift;

    my @elements;

    for my $element ( @{ $pipe->cmds->elements } ) {
        if ( $element->isa( 'IPC::PrettyPipe' ) ) {
            push @elements, _render_pipe( $element );
        }
        else {
            push @elements, _render_cmd( $element );
        }
    }

    return {
            elements => \@elements,
             do {
                 my $streams = _render_streams( $pipe->streams );
                 @$streams ? (streams => $streams) : ();
             },
           };
}

sub _render_cmd {
    my ( $cmd ) = @_;

    return { cmd => $cmd->cmd,
             do {
                 my $args = [ map { $_->render } @{ $cmd->args->elements } ];
                 @$args ? ( args => $args) : ();
                 },

             do {
                 my $streams = _render_streams( $cmd->streams );
                 @$streams ? (streams => $streams) : ();
             },
           }
}

sub _render_streams {
    my $streams = shift;
    return [ map { _render_stream( $_ ) } @{ $streams->elements } ];
}

sub _render_stream {
    my $stream = shift;
    return [ $stream->spec, $stream->has_file ? $stream->file : () ];
}

with 'IPC::PrettyPipe::Renderer';

1;

# COPYRIGHT

__END__

=for stopwords
renderer

=head1 SYNOPSIS

  use IPC::PrettyPipe::DSL;

  my $pipe = ppipe 'ls';
  $pipe->renderer( 'Struct' );

  # or, more explicitly
  my $renderer = IPC::PrettyPipe::Render::Struct->new;
  $pipe->renderer( $renderer );

=head1 DESCRIPTION

B<IPC::PrettyPipe::Render::Struct> provides a rendering backend for
L<IPC::PrettyPipe> which returns Perl data structures representing the pipe.

=head2 Data Structure Layout

=head3 Pipes

A pipe is represented as a hash, with the following entries:

=over

=item C<elements>

An array containing commands or pipes

=item C<streams>

An array containing streams. I<Optional>

=back

=head3 Commands

A command is represented as a hash with the following entries:

=over

=item C<cmd>

The command

=item C<args>

An array containing rendered arguments (see L<IPC::PrettyPipe::Args/render>). I<Optional>

=item C<streams>

An array containing streams. I<Optional>

=back


=head3 Streams

Streams are represented as an array.  Each element of the array is itself
an array with the following elements, in order:

=over

=item 1

the stream specification

=item 2

a file name I<Optional>

=back
