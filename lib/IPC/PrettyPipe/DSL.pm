# --8<--8<--8<--8<--
#
# Copyright (C) 2013 Smithsonian Astrophysical Observatory
#
# This file is part of IPC::PrettyPipe
#
# IPC::PrettyPipe is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# -->8-->8-->8-->8--

package IPC::PrettyPipe::DSL;

use strict;
use warnings;

use Carp;
our @CARP_NOT;

use List::MoreUtils qw[ zip ];
use Safe::Isa;

use IPC::PrettyPipe;
use IPC::PrettyPipe::Cmd;
use IPC::PrettyPipe::Arg;
use IPC::PrettyPipe::Stream;

our $VERSION = '1.21';


use parent 'Exporter';

our %EXPORT_TAGS = (
    construct  => [ qw( ppipe ppcmd pparg ppstream ) ],
    attributes => [ qw( argpfx argsep ) ],
);

## no critic (ProhibitSubroutinePrototypes)
sub argsep($)    { IPC::PrettyPipe::Arg::Format->new( sep => @_ )    };
sub argpfx($)    { IPC::PrettyPipe::Arg::Format->new( pfx => @_ )    };


our @EXPORT_OK = map { @{$_} } values %EXPORT_TAGS;
$EXPORT_TAGS{all} = \@EXPORT_OK;

sub pparg {

    my $fmt = IPC::PrettyPipe::Arg::Format->new;

    while ( @_ && $_[0]->$_isa( 'IPC::PrettyPipe::Arg::Format' ) ) {

        shift()->copy_into( $fmt );
    }

    my @arg = @_;

    if ( @arg == 1 ) {

        unless ( 'HASH' eq ref $arg[0] ) {

            unshift @arg, 'name';

        }
    }

    elsif ( @arg == 2 ) {

        @arg = zip @{ [ 'name', 'value' ] }, @arg;

    }

    return IPC::PrettyPipe::Arg->new( @arg, ( @arg == 1 ? () : ( fmt => $fmt->clone ) ) );

}

sub ppstream {

    my @stream = @_;

    if ( @stream == 1 ) {

        unless ( 'HASH' eq ref $stream[0] ) {

            unshift @stream, 'op';

        }
    }

    elsif ( @stream == 2 ) {

        @stream = zip @{ [ 'op', 'file' ] }, @stream;

    }

    return IPC::PrettyPipe::Stream->new( @stream );
}

sub ppcmd {

    my $argfmt = IPC::PrettyPipe::Arg::Format->new;

    while ( @_ && $_[0]->$_isa( 'IPC::PrettyPipe::Arg::Format' ) ) {

        shift->copy_into( $argfmt );
    }

    my $cmd = IPC::PrettyPipe::Cmd->new( cmd => shift, argfmt => $argfmt );

    $cmd->ffadd( @_ );

    return $cmd;
}


sub ppipe {

    my $argfmt = IPC::PrettyPipe::Arg::Format->new;

    while ( @_ && $_[0]->$_isa( 'IPC::PrettyPipe::Arg::Format' ) ) {

        shift->copy_into( $argfmt );
    }

    my $pipe = IPC::PrettyPipe->new( argfmt => $argfmt );

    $pipe->ffadd( @_ );

    return $pipe;
}


1;


__END__

=head1 NAME

IPC::PrettyPipe::DSL - shortcuts to building an IPC::PrettyPipe object

=head1 SYNOPSIS

  use IPC::PrettyPipe::DSL qw[ :all ];

  $pipe =
	ppipe
        # one command per array
        [ 'mycmd',
              argsep $sep,        # set default formatting attributes
              argpfx '-',
              $arg, $arg,         # boolean/switch arguments
              argpfx '--',        # switch argument prefix
              \@args_with_values  # ordered arguments with values
              \%args_with_values, # unordered arguments with values
              '2>', 'stderr_file' # automatic recognition of streams
        ],
        # another command
        [ 'myothercmd' => ... ],
        # manage pipeline streams
        '>', 'stdout_file';
  ;

  # or, create a command

  $cmd = ppcmd 'mycmd',
          argpfx '-',     # default for object
          $arg, $arg,
          argpfx '--',    # change for next arguments
          $long_arg, $long_arg;

  # and add it to a pipeline
  $pipe = ppipe $cmd;

  # and for completeness (but rarely used )
  $arg = pparg '-f';
  $arg = pparg [ -f => 'Makefile' ];
  $arg = pparg, argpfx '-', [ f => 'Makefile' ];

=head1 DESCRIPTION

B<IPC::PrettyPipe::DSL> provides some shortcut functions to make
building pipelines easier.


=head1 FUNCTIONS

=head2 Pipeline component construction

=over

=item B<ppipe>

  $pipe = ppipe @attribute_modifiers,
                @args;

  $pipe = ppipe argpfx( '--'),
                [ 'cmd0', 'arg0' ],
                [ 'cmd1', 'arg0',
                          argpfx( '' ), argsep( '=' ),
                          [ arg1 => $arg1_value, arg2 => $arg2_value ],
                ],
                [ 'cmd2', 'arg0' ];


B<ppipe> creates an B<IPC::PrettyPipe> object.  It is passed an array
of arguments which may be one or more of the following:

=over

=item *

attribute modifiers

These will affect all of the commands and arguments which follow.
Attribute modifiers which I<precede> all other arguments are stored in
the returned B<IPC::PrettyPipe> object and are used as its defaults.
All other modifiers override these for the remainder of the arguments.

See L</Attribute Modifiers> for more information.

=item *

Commands (and their arguments) which may be specified as either

=over

=item *

strings

These may specify I<either>

=over

=item *

The name of a command without any arguments; or

=item *

a stream specification for the pipeline. If the specification requires
an additional parameter, the next element in the argument list will be
used for that parameter.

=back

=item *

an arrayref

The first array element is the command name. The succeeding elements are
arguments and input and output stream specifications, which may take
the following forms:

=over

=item *

strings

These may specify I<either>

=over

=item *

the name of an argument which takes no value; or

=item *

a stream specification. If the specification requires an additional
parameter, the next element in the argument list will be used for that
parameter.

=back

=item *

references to arrays

The arrays must contain I<pairs> of argument names and values.  The
arguments will be supplied to the command in the order they appear in
the array.

=item *

hashrefs

These specify one or more pairs of argument names and values.
The arguments will be supplied to the command in a random order.

=item *

attribute modifiers

These affect all of the arguments which follow. See L</Attribute
Modifiers> for more details.


=back


=item *

an B<IPC::PrettyPipe::Cmd> object

=back

=back

=item B<ppcmd>

  $cmd = ppcmd @attribute_modifiers,
               $cmd,
               @cmd_args;

  $cmd = ppcmd 'cmd0', 'arg0', [ arg1 => $arg1_value ];
  $cmd = ppcmd argpfx '--',
             'cmd0', 'arg0', [ arg1 => $arg1_value ];

B<ppcmd> creates an B<IPC::PrettyPipe::Cmd> object.  It is passed (in order)

=over

=item 1

An optional list of attribute modifiers. These are stored in the
returned B<IPC::PrettyPipe::Cmd> object and are used as its defaults.

=item 2

The command name

=item 3

A list of command arguments, attribute modifiers, and stream specifications.
This list may contain

=over

=item *

strings

These may specify I<either>

=over

=item *

The name of an argument which takes no value; or

=item *

a stream specification for the command. If the specification requires
an additional parameter, the next element in the argument list will be
used for that parameter.

=back

=item *

an arrayref

This must contain I<pairs> of argument names and values.  The
arguments will be supplied to the command in the order they appear in
the array.

=item *

a hashref

This specifies one or more pairs of argument names and values.  The
arguments will be supplied to the command in a random order.

=item *

an attribute modifier.

This changes the attributes for the arguments which follow.  It does
not change the attributes stored in the returned
B<IPC::PrettyPipe::Cmd> object.

=item *

an B<IPC::PrettyPipe::Arg> object

=back

=back

=item B<pparg>

  $arg = pparg @attribute_modifiers,
               $name,
               $value;

B<ppcmd> creates an B<IPC::PrettyPipe::Arg> object.   It is passed
(in order)

=over

=item 1

An optional list of attribute modifiers. These are stored in the
returned B<IPC::PrettyPipe::Arg> object.

=item 2

The argument name.

=item 3

An optional value.

=back


=item B<ppstream>

  $stream = ppstream $spec;
  $stream = ppstream $spec, $file;

B<ppcmd> creates an B<IPC::PrettyPipe::Stream> object.
It is passed (in order):

=over

=item 1

A stream specification

=item 2

An optional file name (if required by the stream specification).

=back

=back

=head2 Attribute Modifiers

Attribute modifiers can be used to specify the default values of the
following attributes:

=over

=item I<argpfx>

=item I<argsep>

Strings which prefix and separate command arguments and values (for
more information see L<IPC::PrettyPipe::Arg>).

=back

Modifiers take a single value (the new value of the attribute) which
may be enclosed in parenthesis:

  $p = ppipe argpfx '-',
             [ 'cmd0', 'arg0' ],
             argpfx '--',
             [ 'cmd1', argpfx('-'), 'arg1' ],
             [ 'cmd2', 'arg0' ];

and affect the default value of the attribute for the remainder of the
context in which they are specified.

For example, after the above code is run, the following holds:

  $p->argpfx eq '-'

  $p->cmds->[0]->argpfx eq '-'

  $p->cmds->[1]->argpfx eq '--'
  $p->cmds->[1]->args->[0]->argpfx eq '-'

  $p->cmds->[2]->argpfx eq '--'
  $p->cmds->[2]->args->[0]->argpfx eq '--'


=head2 Stream Specifications

A stream specification may be either an B<IPC::PrettyPipe::Stream>
object or a string.

As a string, the specification may take one of the following forms:
(any resemblance to stream operators used by B<IPC::Run> is purely
non-coincidental):

  Spec    Op    Mode    File    Function
  ----    ---  ----    ----    -----------------------
  <       <     I       y       read from file via fd 0
  <N      <     I       y       read from file via fd N
  >       >     O       y       write to file via fd 1
  >N      >     O       y       write to file via fd N

  >&      >&    O       n       redirect fd 2 to fd 1
  &>      &>    O       n       redirect fd 2 to fd 1

  N<&-    <&-   ?       n       close fd N

  M<&N    <&    I       n       dup fd M as fd N
  N>&M    >&    O       n       dup fd M as fd N

 where

=over

=item *

I<M> and I<N> are integers indicating file descriptors

=item *

C<Mode> indicates input (I<I>), output (I<O>), or not applicable (I<?>)

=item *

C<File> indicates whether an additional parameter (file name) is
required.  If so, the parameter must follow the stream specification, e.g.:

  '>3', $output_file

indicates that fd 3 should be configured for output to C<$output_file>.

=back


=head1 COPYRIGHT & LICENSE

Copyright 2013 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
