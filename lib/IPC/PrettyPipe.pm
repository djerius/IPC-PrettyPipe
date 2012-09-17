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

package IPC::PrettyPipe;

use strict;
use warnings;

use Carp;

use String::ShellQuote qw[ shell_quote ];
use List::Util qw[ sum ];
use Safe::Isa;

use Params::Check qw[ check ];

use Moo;
use MooX::Types::MooseLike::Base ':all';

use IPC::PrettyPipe::Cmd;
use IPC::PrettyPipe::Check;

our $VERSION = '1.21';

has argpfx => (
    is      => 'rw',
    predicate => 1,
    default => sub { '' },
);

has argsep => (
    is      => 'rw',
    isa     => ArgSep,
    predicate => 1,
    default => sub { undef },
);

has cmdsep => (
    is      => 'rw',
    isa     => Str,
    default => sub { " \\\n" },
);


has cmdpfx => (
    is      => 'rw',
    isa     => Str,
    default => sub { "\t" },
);

has cmdoptsep => (
    is      => 'rw',
    isa     => Str,
    default => sub { " \\\n" },
);

has optsep => (
    is      => 'rw',
    isa     => Str,
    default => sub { " \\\n" },
);

has optpfx => (
    is      => 'rw',
    isa     => Str,
    default => sub { "\t  " },
);


has stream => (
    is => 'rw',
    isa => ArrayRef[InstanceOf['IPC::PrettyPipe::Stream']],
    default => sub { [] }
);


has _cmds => (
    is       => 'ro',
    init_arg => 'cmds',
    coerce   => sub { 'ARRAY' ne ref $_[0] ? [ $_[0] ] : $_[0] },
    isa      => sub {
        die( "args must be a scalar or list\n" )
          unless 'ARRAY' eq ref( $_[0] );
    },
    default => sub { [] },
    clearer => 1,
);

# must delay building cmds until all attributes have been specified
has cmds => (
    is       => 'lazy',
    init_arg => undef
);

sub BUILDARGS {

	my $class = shift;

    return $_[0] if 1 == @_ && 'HASH' eq ref $_[0];

	my @cmds;

	while( @_ ) {

		last
		  unless $_[0]->$_isa( 'IPC::PrettyPipe::Cmd' )
		    || 'ARRAY' eq ref $_[0];

		push @cmds, shift;

	}


	my %args = @_;

	$args{cmds} = \@cmds
	  if @cmds;

	return \%args;
}

sub _build_cmds {

    my $self = shift;

    my $cmds = [];

    $self->_add( $cmds, $_ ) foreach @{ $self->_cmds };

    $self->_clear_cmds;

    return $cmds;
}

sub add {

    my $self = shift;

    croak( __PACKAGE__, ": must specify at least the command name\n" )
      unless @_;

	return $self->_add( $self->cmds, \@_ );

}


sub _add {

	my ( $self, $cmds ) = ( shift, shift );

	my ( $cmd, @args ) = 'ARRAY' eq ref $_[0]
	                   ? @{ $_[0] }
	                   : @_;

	if ( $cmd->$_isa( 'IPC::PrettyPipe::Cmd' ) ) {

		croak( "cannot specify additional arguments when passing a Cmd object\n" )
		  if @args;

		push @$cmds, $cmd;

	}

	else {

		my %args = ( cmd => $cmd,
		             args => \@args );

		$args{argsep} = $self->argsep if $self->has_argsep;
		$args{argpfx} = $self->argpfx if $self->has_argpfx;

		push @$cmds, IPC::PrettyPipe::Cmd->new( \%args );
	}

	return $cmd;
}

sub render {

	my $self = shift;

    my $args = check( {
            argsep  => { allow => CheckArgSep },
            argdefsep  => { allow => CheckArgSep },
            flatten => { allow => CheckBool, default => 0 },
            quote   => { allow => CheckBool, default => 0 },
        },
        ( 'HASH' eq ref $_[0] ? $_[0] : {@_} )
    ) or croak( __PACKAGE__, ': ', Params::Check::last_error );

	$args->{sep} = delete $args->{argsep} if exists $args->{argsep};
	$args->{defsep} = delete $args->{argdefsep} if exists $args->{argdefsep};

	my @cmds = map { [ $_->render( $args  ) ] } @{ $self->cmds };

	return @cmds;
}

sub _pp_cmd {

    my ( $self, $pcmd ) = @_;

    # render the command so that each name/value pair is rendered
    # as a single string
    my @args = $pcmd->render( quote => 1, defsep => ' ' );

    return
      join( $self->cmdoptsep . $self->optpfx,
            $self->cmdpfx . shift( @args),
            join( $self->optsep . $self->optpfx, @args ),
          );
}

sub pp {

    my $self = shift;

    my $pipe = join( $self->cmdsep . '|',
                     map { $self->_pp_cmd( $_ ) } @{ $self->cmds } );



    if ( $self->has_stderr || $self->has_stdin || $self->has_stdout ) {

	    my @pipe = ( '(', $pipe , $self->cmdsep, ')' );

	    push @pipe, $self->cmdsep, '<', $self->cmdpfx, $self->stdin
	      if $self->has_stdin;

	    push @pipe, $self->cmdsep, '>', $self->cmdpfx, $self->stdout
	      if $self->has_stdout;

	    if ( $self->has_stderr ) {

		    if ( $self->has_stdout && $self->stderr eq $self->stdout ) {

			    push @pipe, $self->cmdsep, $self->cmdpfx, '2>&1';

		    }
		    else {

			    push @pipe, $self->cmdsep, '2>', $self->cmdpfx, shell_quote( $self->stderr );

		    }
	    }

	    $pipe = join('', @pipe);

    }


    return $pipe;

}

sub valmatch {

    my $self    = shift;
    my $pattern = shift;

    return sum 0, map { $_->valmatch( $pattern ) && 1 || 0 } @{ $self->cmds };
}


sub valsubst {

    my ( $self, $pattern, $value ) = ( shift, shift, shift );

    my %args = ( ref $_[0] ? %{ $_[0] } : @_ );
    $args{pattern} = $pattern;
    $args{value}   = $value;

    ## no critic (ProhibitAccessOfPrivateData)

    my $args = check( {
            pattern    => { required => 1, allow => CheckRegexp },
            value      => { required => 1, allow => CheckStr },
            lastvalue  => { allow    => CheckStr },
            firstvalue => { allow    => CheckStr },
        },
        \%args
    ) or croak( __PACKAGE__, ': ', Params::Check::last_error );

    my $nmatch = $self->valmatch( $pattern );

    if ( $nmatch == 1 ) {

        $args->{lastvalue} //= $args->{firstvalue} // $args->{value};
        $args->{firstvalue} //= $args->{lastvalue};

    }
    else {
        $args->{lastvalue}  ||= $args->{value};
        $args->{firstvalue} ||= $args->{value};
    }

    my $match = 0;
    foreach ( @{ $self->cmds } ) {
        $match++
          if $_->valsubst( $pattern,
              $match == 0               ? $args->{firstvalue}
            : $match == ( $nmatch - 1 ) ? $args->{lastvalue}
            :                             $args->{value} );
    }

    return $match;
}


1;


__END__

=head1 NAME

IPC::PrettyPipe - manage human readable external command execution pipelines

=head1 SYNOPSIS

  use IPC::PrettyPipe;

  my $pipe = new IPC::PrettyPipe;

  $pipe->add( $command, @args );
  $pipe->add( $command, $arg1, { option => value } );

  $cmd = $pipe->add( $command );
  $cmd->add( $args );

  $cmd->argsep( '=' );

=head1 DESCRIPTION

Connecting a series of programs via pipes is a time honored tradition.
When it comes to displaying them for debug or informational purposes,
simple dumps may suffice for simple pipelines, but when the number of
programs and arguments grows large, it can become difficult to understand
the overall structure of the pipeline.

B<IPC::PrettyPipe> provides a mechanism to construct and output
readable external command execution pipelines.  It does this by
treating commands, their options, and the options' values as separate
entitites so that it can produce nicely formatted output.

There is sufficient DWIMmery to make it easy to produce pipelines.

=head2 How it works

B<IPC::PrettyPipe> manages a list of B<IPC::PrettyPipe::Cmd> objects,
each of which also manages a list of B<IPC::PrettyPipe::Arg> objects.

It is rare that one needs worry about anything but the top-level
B<IPC::PrettyPipe> object, but access to the sub-level objects is easy
to get.

=head1 METHODS

=over

=item new

  # create an empty pipeline
  $pipe = IPC::PrettyPipe->new( %options );

  # positional argument interface; pass in some commands and options
  $pipe = IPC::PrettyPipe->new( $cmd1, $cmd2, %options );

  # named argument interface
  $pipe = IPC::PrettyPipe->new( cmds => [ $cmd1, $cmd2 ], %options );


B<new> creates a new C<IPC::PrettyPipe> object.  It can create an empty
pipe, or can be preloaded with commands.


=over

=item argsep

This specifies the default string to separate arguments from their
values.  If this is undefined (the default), the argument name and
value are passed to the command separately.  The dumped output will
use a space.

New commands inherit the current value of B<argsep> string.  The
default value may also be changed with the B<argsep> method for
B<IPC::PrettyPipe> objects.  The separator for a given command may be
changed with the B<argsep> method for the command.


=back

=item add( [\%attr,] $command, @arguments )

This creates an B<IPC::PrettyPipe::Cmd> object, adds it to the
B<IPC::PrettyPipe> object, and returns a handle to it.  The optional hash
may be used to set attributes for the command (see
L<IPC::PrettyPipe::Cmd>).  The command's B<ArgSep> attribute is set to that
of the B<IPC::PrettyPipe> object.

Arguments to the command may be specified in one of the following
ways:

=over

=item *

As a simple string, e.g.,

	$pipe->add( 'ls', '-l' );

This option is useful for command options which do not take an argument.

=item *

As a reference to a hash, e.g.,

	$pipe->add( 'tar', { -f => 'foo.tar' } );

This method obviously is only useful for options which take an
argument.  Multiple options may be specified in the hash.  Because it
is a hash, the ordering of the options will not be kept as specified.

=item *

As a reference to an array, e.g.,

	$pipe->add( 'tar', [ -f => 'foo.tar' ] );

This method obviously is only useful for options which take an
argument.  Multiple options may be specified in the array.  The ordering
of options is retained.


=back

The different methods of option specification may be mixed, e.g.,

	$pipe->add( 'tar',
		    '-v',
		    [ -f => 'foo.tar' ],
		    { -b => 100 }
		  );



=item argsep( $argsep )

This changes the value of the B<ArgSep> attribute for commands
subsequently added to the pipe. Existing commands should use the
B<IPC::PrettyPipe::Cmd::argsep> method.

=item stdin( $stdin )

This specifies a file to which the standard input stream of the
pipeline will be connected. if I<$stdout> is C<undef> or unspecified,
it cancels any value previously set.


=item stdout( $stdout )

This specifies a file to which the standard output stream of the
pipeline will be written. if I<$stdout> is C<undef> or unspecified, it
cancels any value previously set.


=item stderr( $stderr )

This specifies a file to which the standard output stream of the
pipeline will be written. if I<$stderr> is C<undef> or unspecified, it
cancels any value previously set.

=item dump( \%attr )

This method returns a string containing the sequence of commands in
the pipe. By default, this is a "pretty" representation.  The
I<\%attr> hash may contain any of the attributes documented
for the B<IPC::PrettyPipe::Cmd::new> method.


=item run

Execute the pipe.  Returns true if the pipe ran to completion.

=item valrep( $pattern, $value, [$lastvalue, [$firstvalue] )

Replace arguments to options whose arguments match the Perl regular
expression, I<$pattern> with I<$value>.  If I<$lastvalue> is
specified, the last matched argument will be replaced with
I<$lastvalue>.  If I<$firstvalue> is specified, the first matched
argument will be replaced with I<$firstvalue>.

For example,

  my $pipe = new IPC::PrettyPipe;
  $pipe->add( 'cmd1', [ input => 'INPUT', output => 'OUTPUT' ] );
  $pipe->add( 'cmd2', [ input => 'INPUT', output => 'OUTPUT' ] );
  $pipe->add( 'cmd3', [ input => 'INPUT', output => 'OUTPUT' ] );
  $pipe->valrep( 'OUTPUT', 'stdout', 'output_file' );
  $pipe->valrep( 'INPUT', 'stdin', undef, 'input_file' );
  print $pipe->dump, "\n"

results in

          cmd1 \
  	  input=input_file \
            output=stdout \
  |       cmd2 \
            input=stdin \
            output=stdout \
  |       cmd3 \
            input=stdin \
            output=output_file

=back

=head1 EXAMPLES


Sometimes it's not possible to determine beforehand which command in a
pipeline will be the final one in the pipe; thus, it's not possible to
specify which command actually writes the output file until the very
end. In the following example the programs recognize the token
C<stdout> to refer to the standard output stream; this is specific to
their implementation.

  my $pipe = new IPC::PrettyPipe;
  $pipe->add( 'genphot',
  	    { output	=> 'OUTPUT',
  	      photdens  => 0.001 }
  	  );

  $pipe->add( 'bp2rdb',
  	    { input     => 'stdin',
  	      output    => 'OUTPUT' }
  	    )
  	if $convert_to_rdb;

  $pipe->valrep( 'OUTPUT', 'stdout', 'rays.out' );

  print $pipe->dump, "\n"

This results in:

          genphot \
            output=stdout \
            photdens=0.001 \
  |       bp2rdb \
            input=stdin \
            output=rays.out


If programs can write to C<stdout> directly, one can use the B<stdout()>
(and likewise B<stderr()> method), if need be:

  my $pipe = new IPC::PrettyPipe;
  $pipe->add( 'ls' );
  $pipe->add( 'wc' );
  $pipe->stdout( 'line_count' );
  print $pipe->dump, "\n";

This results in:

          ls \
  |       wc \
  >       line_count

To redirect stderr, add the following line,

  $pipe->stderr( 'error' );

which results in a dump (equivalent shell command) of :

  (       ls \
  |       wc \
  >       line_count \
  ) \
  2>      error

=head1 COPYRIGHT & LICENSE

Copyright 2006 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
