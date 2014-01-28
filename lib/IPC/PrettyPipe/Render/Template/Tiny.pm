#!perl

package IPC::PrettyPipe::Render::Template::Tiny;

use Carp;
use Template::Tiny;
use Params::Check qw[ check ];
use IPC::PrettyPipe::Check qw[ CheckIsa ];
use Safe::Isa;

use Moo;
use MooX::Types::MooseLike::Base ':all';

BEGIN {
    if ( $^O =~ /Win32/i ) {
        require Win32::Console::ANSI;
    }
}
use Term::ANSIColor ();


has pipe => (
    is       => 'rw',
    isa      => InstanceOf ['IPC::PrettyPipe'],
    required => 1,
);

has colors => (
    is      => 'rw',
    isa     => HashRef,
    default => sub {
        {
            cmd => {
                cmd    => 'blue',
                stream => {
                    spec => 'red',
                    file => 'green',
                },
                arg => {
                    name  => 'red',
                    sep   => 'yellow',
                    value => 'green',
                },
            },
            pipe => {
                stream => {
                    spec => 'red',
                    file => 'green',
                },
            },
        };
    },
);


has template => (

    is => 'rw',

    default => sub {
        return <<"EOT"
[% IF pipe.streams.empty %][% ELSE %](\t\\
[% END -%]
[%- FOREACH cmd IN pipe.cmds.elements %]
[%- IF cmd.first %]  [% ELSE %]\t\\
| [% END %][% color.cmd.cmd %][% cmd.cmd %][% color.reset %]
[%- FOREACH arg IN cmd.args.elements %]\t\\
    [% color.cmd.arg.pfx %][% arg.pfx %]
[%- color.cmd.arg.name %][% arg.name %]
[%- IF arg.has_value %][%- IF arg.sep %][% color.cmd.arg.sep %][% arg.sep %][% ELSE %] [% END %]
[%- color.cmd.arg.value %][% IF arg.has_blank_value%]''[% ELSE %][% arg.value %][% END %][% END %][% color.reset %]
[%- END %]
[%- FOREACH stream IN cmd.streams.elements %]\t\\
[% color.cmd.stream.spec %][% stream.spec %]
[%- IF stream.file %] [% END %][% color.cmd.stream.file %][% stream.file %][% color.reset %]
[%- END %]
[%- END %]
[%- IF pipe.streams.empty %][% ELSE %]\t\\
)[% FOREACH stream IN pipe.streams.elements %]\t\\
[% color.pipe.stream.spec %][% stream.spec -%]
[%- IF stream.file %] [% END %][% color.pipe.stream.file %][% stream.file %][% color.reset %]
[%- END %]
[%- END %]
EOT
    },


);

sub _colorize {

    my ( $tmpl, $colors ) = @_;

    ## no critic (ProhibitAccessOfPrivateData)

    while ( my ( $node, $value ) = each %$tmpl ) {

        if ( ref $value ) {

            $colors->{$node} = {};
            _colorize( $value, $colors->{$node} );

        }

        else {
            $colors->{$node} = Term::ANSIColor::color( $value );
        }

    }

}

sub render {

    my $self = shift;

    my $args = check( { colorize => { default => 1 },
		      },
		      {@_} )
      or croak( ref $self, "::pp ", Params::Check::last_error() );

    my $output;

    my $colors = $self->colors;

    my %color;
    _colorize( $self->colors, \%color );

    $color{reset} = Term::ANSIColor::color( 'reset' )
      if keys %color;


    Template::Tiny->new->process(
        \$self->template,
        {
	 ## no critic (ProhibitAccessOfPrivateData)
            pipe => $self->pipe,
            $args->{colorize} ? ( color => \%color ) : (),
        },
        \$output,
    );

    return $output;
}

with 'IPC::PrettyPipe::Renderer';

1;

__END__

=head1 NAME

IPC::PrettyPipe::Render::Template::Tiny - rendering backend using Template::Tiny

=head1 SYNOPSIS

  use IPC::PrettyPipe::DSL;

  my $pipe = ppipe 'ls';
  $pipe->renderer( 'Template::Tiny' );

  # or, more explicitly
  my $renderer = IPC::PrettyPipe::Render::Template::Tiny->new;
  $pipe->renderer( $renderer );

=head1 DESCRIPTION

B<IPC::PrettyPipe::Render::Template::Tiny> implements the
B<IPC::PrettyPipe::Renderer> role, providing a renderer backend for
B<IPC::PrettyPipe> using the B<Template::Tiny> module.

=head1 METHODS

=over

=item new

  $renderer = IPC::PrettyPipe::Render::Template::Tiny->new( %attr );

Construct a new renderer.  Typically this is done automatically by B<IPC::PrettyPipe>.
The following attributes are available:

=over

=item pipe

The B<IPC::PrettyPipe> object to render.

=item colors

A color specification; see L</Rendered Colors>.

=item template

A B<Template::Tiny> template to generate the output.  See L</Rendering
Template>.

=back


=item run

  $renderer->run( %options );

The following options are available:

=over

=item *

colorize

If true (the default) the output is colorized using B<Term::AnsiColor>.

=back

=item pipe

  $pipe = $renderer->pipe;
  $renderer->pipe( $pipe );

Retrieve or set the B<IPC::PrettyPipe> object to render.

=item colors

  $colors = $renderer->colors;
  $renderer->colors( $colors );

Retrieve or set the colors to be output; see L</Rendered Colors>.

=item template

  $template = $renderer->template;
  $renderer->template( $template );

Retrieve or set the B<Template::Tiny> template used to generate the
output.  See L</Rendering Template>.

=back

=head1 CONFIGURATION

=head2 Rendering Template

The C<template> attribute and method may be used to change the
template used to render the pipeline.  The template is passed the
following parameters:

=over

=item C<pipe>

C<pipe> is the B<IPC::PrettyPipe> object. B<Template::Tiny> doesn't
support loop constructs, so the B<IPC::PrettyPipe> B<streams()> and
B<cmds()> methods return B<IPC::PrettyPipe::Queue> objects, which
provide methods for determining if the lists are empty.


  [% IF pipe.streams.empty %][% ELSE %](\t\\
  [% END -%]

Note that B<Template::Tiny> resolves object methods with the same syntax as it
resolves hash entries.

Iteration looks like this:

  [%- FOREACH cmd IN pipe.cmds.elements %]
  [% END %]

An B<IPC::PrettyPipe::Queue::Element> has additional methods which
indicates whether it is the first or last in its queue.

  [%- IF cmd.first %]  [% ELSE %]\t\\
  | [% END %]

=item C<color>

This is the hashref specified by the C<colors> attribute or method.
It contains an additional element C<reset> which can be used to reset
all colors at once.  Here's an example bit of template to output
and colorize a command:

  [% color.cmd.cmd %][% cmd.cmd %][% color.reset %]


=back

The default template (encoded into the source file for
B<IPC::PrettyPipe::Render::Template::Tiny>) provides a good example
of how to construct one.

=head2 Rendered Colors

The C<colors> attribute and method may be used to change
the colors used to render the pipeline.  Colors are
stored as a hashref with the following default contents:

  cmd => {
      cmd    => 'blue',
      stream => {
          spec => 'red',
          file => 'green',
      },
      arg => {
          name  => 'red',
          sep   => 'yellow',
          value => 'green',
      },
  },
  pipe => {
      stream => {
          spec => 'red',
          file => 'green',
      },
  },


=head1 COPYRIGHT & LICENSE

Copyright 2013 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>

=cut

