# --8<--8<--8<--8<--
#
# Copyright (C) 2012 Smithsonian Astrophysical Observatory
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

package IPC::PrettyPipe::Stream;

use strict;
use warnings;
use Carp;

use Params::Check qw[ check ];

use IPC::PrettyPipe::Check;
use String::ShellQuote qw[ shell_quote ];

use Moo;
use MooX::Types::MooseLike::Base ':all';

has N => (
    is => 'rwp',
    predicate => 1,
    init_arg => undef,
);
has M => (
    is => 'rwp',
    predicate => 1,
    init_arg => undef,
);
has Op => (
    is => 'rwp',
    init_arg => undef,
);

has op => (
    is        => 'rwp',
    isa       => Str,
    required  => 1,
);

has file => (
    is      => 'rwp',
    isa       => Str,
    predicate => 1,
);

has sep => (
    is        => 'ro',
    isa       => ArgSep,
    default => sub { undef },
    predicate => 1,
);

sub BUILDARGS {

	my $class = shift;

	return $_[0] if @_ == 1 && 'HASH' eq ref $_[0];

	return {@_} if $_[0] eq 'op' or $_[0] eq 'file';

	my %args;
	$args{op} = shift if @_;
	$args{file} = shift if @_;

	croak( __PACKAGE__, ': ', "too many arguments to new\n" )
	  if @_;

	return \%args;
}

sub BUILD {

    my $self = shift;

    my $opc = _parse_op( $self->op );

    croak( __PACKAGE__, ': ', "cannot parse stream operator: ", $self->op )
      unless keys %$opc;

    $self->${\"_set_$_"}($opc->{$_})
      for grep { exists $opc->{$_} } qw[ N M Op ];

    return;
}

sub _parse_op {

    my $op = shift;

    # parse stream operator; use IPC::Run's operator syntax

    $op =~ /^(?:
    # <, N<
    # >, N>
    # >>, N>>
    # <pty, N<pty
    # >pty, N>pty
    # <pipe, N<pipe
    # >pipe, N>pipe

      (?'first'
          (?'N' \d+ (?!<<) )?  # don't match N<<
          (?'Op'
              (?: [<>]{1,2} )
            | [<>] (?:pty|pipe)
          )
       )

    # >&, &>
    | (?:
          (?'Op' >& | &> )
      )

    # N<&M
    # N<&-
    | (?:
          (?'N'  \d+     )
          (?'Op' <&      )
          (?'M'  \d+ | - )
       )

    # M>&N
    | (?:
          (?'M'  \d+ )
          (?'Op' >&  )
          (?'N'  \d+ )
      )
      )$/x ;

    # force a copy of the hash; it's magical and a simple return
    # of the elements doesn't work.
    my $opc = { %+ };

    # fill in default value for N & M for stdin & stdout
    $opc->{N} = substr($opc->{Op},0,1) eq '<' ? 0 : 1
      if exists $opc->{first} && ! defined $opc->{N};

    return $opc;
}

sub render {

    my $self = shift;

    ## no critic (ProhibitAccessOfPrivateData)

    my $args = check( {
            sep     => { allow   => CheckArgSep },
            defsep  => { allow   => CheckArgSep },
            quote   => { default => 0,           allow   => CheckBool },
            flatten => { allow   => CheckBool,   default => 0 },
        },
        ( 'HASH' eq ref $_[0] ? $_[0] : {@_} )
    ) or croak( Params::Check::last_error );

    if ( $self->has_file ) {

        ## no critic (ProhibitAccessOfPrivateData)

	    my $file = $args->{quote} ? shell_quote( $self->file ) : $self->file;

	    my $sep = $args->{sep} // $self->sep // $args->{defsep};

	    my @retval =
	      defined $sep
		? $self->op . $sep . $file
		: ( $self->op, $file );

	    return
	        1 == @retval       ? $retval[0]
	        : $args->{flatten} ? @retval
	        :                   \@retval;

    }

    else {

	    return $self->op;
    }

    croak;
}

1;


__END__

=head1 NAME

IPC::PrettyPipe::Stream - An I/O stream for a IPC::PrettyPipe::Cmd command

=head1 SYNOPSIS

  use IPC::PrettyPipe::Stream;

  # positional arguments
  $stream  = IPC::PrettyPipe::Stream->new( $op );
  $stream = IPC::PrettyPipe::Stream->new( $op, $file );

  # named arguments; allows specifying other attributes
  # note enclosure in hash
  $stream = IPC::PrettyPipe::Stream->new( { op=> $op } );
  $stream = IPC::PrettyPipe::Stream->new( { op => $op,
                                            file => $file } );

  # return a rendered argument
  $stream->render;

=head1 DESCRIPTION

B<IPC::PrettyPipe::Stream> objects are containers for I/O streams
attached to commands in an B<IPC::PrettyPipe::Cmd> object.  They are
typically automatically created by the B<IPC::PrettyPipe::Cmd> object.

The stream specification is divided into a stream operator and an
optional file.  Stream operators have the same syntax as those in L<IPC::Run>.

The operator is parsed into three components (based upon the B<IPC::Run> syntax):

=over

=item N

The operator's primary fd

=item Op

The operator stripped of fds

=item M

The operator's secondary fd; usually the fd which is being duplicated
or C<-> if the primary fd is to be closed.

=back

These are available via the B<N>, B<Op> and B<M> methods.

=head1 METHODS

=over 8

=item B<new>

  # positional interface
  $stream = IPC::PrettyPipe::Stream->new( $op );
  $stream = IPC::PrettyPipe::Stream->new( $op, $file );

  # named interface; may provide additional attributes
  $stream = IPC::PrettyPipe::Stream->new( op => $op, file => $file );
  $stream = IPC::PrettyPipe::Stream->new( \%attr );

Objects may be created either with a simplified positional interface, or with
a named argument interface, which provides additonal attributes.

The available attributes are:

=over

=item C<op>

A stream operator.

=item C<file>

The optional file attached to the stream. If the stream is a
redirection then no file is required.

=item C<sep>

A string to insert between the operator and file when rendering.  This
defaults to C<undef>, indicating that they are treated as separate
entitites.

=back

=item B<render>

  $rendered_stream = $stream->render( %options )

Render the stream.  If the stream's C<sep> attribute is defined, B<render>
returns a string which looks like:

  $op . $sep . $file

If C<sep> is not defined, it returns an array ref which looks like

  [ $op, $file ]

unless the C<flatten> option is specified, in which case it returns a list

  $op, $file

If the stream has no file,

  $op

The available options are:

=over

=item C<sep>

Override the existing value of the C<sep> attribute.

=item C<defsep>

Override the existing value of the C<sep> attribute, but only if it
was C<undef>. Quoting is also affected; see below.

=item C<quote>

Quote the rendered stream so that it's contents will survive parsing
by a shell (currently uses L<String::ShellQuote>).  Only the file is quoted.

=item C<flatten>

Return a list rather than an arrayref if C<sep> is undefined and the
stream has a file.

=back

=item B<op>

The operator passed in to the constructor

=item B<file>

=item B<has_file>

The first returns the file passed in to the constructor (if one was).
The second returns true if a file was passed to the constructor.

=item B<N>

=item B<Op>

=item B<M>

The components of the operator.

=item B<has_N>

=item B<has_M>

These return true if the stream operator contained the associated component.

=back


=head1 COPYRIGHT & LICENSE

Copyright 2012 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
