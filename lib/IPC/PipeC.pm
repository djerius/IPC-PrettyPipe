# --8<--8<--8<--8<--
#
# Copyright (C) 2010 Smithsonian Astrophysical Observatory
#
# This file is part of IPC::PipeC
#
# IPC::PipeC is free software: you can redistribute it and/or modify
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

package IPC::PipeC;

use strict;
use warnings;

use Carp;

use IPC::Run ();
use IPC::PipeC::Cmd;

our $VERSION = '1.20';

sub new
{
  my $this = shift;
  my $class = ref($this) || $this;

  my $self = {
              attr => { ArgSep => undef },
              cmd => [ ],
	      stdout => undef,
	      stderr => undef,
             };

  bless $self, $class;

  while ( @_ )
  {
    my $arg = shift;

    # hash of attributes
    if ( ref( $arg ) eq 'HASH' )
    {
      while ( my ( $key, $val ) = each ( %$arg ) )
      {
        if ( exists $self->{attr}->{$key} )
        {
          $self->{attr}->{$key} = $val;
        }
        else
        {
          $self->_error( __PACKAGE__, "::new: unknown attribute: $key\n" );
          return;
        }
      }
    }
    else
    {
      $self->_error( __PACKAGE__, "::new: unacceptable argument\n" );
      return;
    }
  }

  return $self;
}

sub add
{
  my $self = shift;

  my $cmd = IPC::PipeC::Cmd->new( @_ );

  if ( $cmd )
  {
    push @{$self->{cmd}}, $cmd;
    $cmd->argsep( $self->{attr}{ArgSep} );
  }

  $cmd;
}


sub argsep
{
  my $self = shift;

  @_ || $self->_error( __PACKAGE__, "::argsep: missing argument to argsep\n" );

  $self->{attr}->{ArgSep} = shift;

}

sub stdin
{
  my $self = shift;
  $self->{stdin} = shift;
}

sub stdout
{
  my $self = shift;
  $self->{stdout} = shift;
}

sub stderr
{
  my $self = shift;
  $self->{stderr} = shift;
}


sub dump
{
  my $self = shift;
  my $attr = shift;

  my %attr = ( CmdSep => " \\\n",
	       CmdPfx => "\t",
	       $attr ? %$attr : () );

  my $pipe = join ( $attr{CmdSep} . '|',
		    map { $_->dump( $attr) } @{$self->{cmd}} );


  if ( $self->{stderr} || $self->{stdin} || $self->{stdout} )
  {
    $pipe = '(' . $pipe . $attr{CmdSep} . ')';
  }

  $pipe .= $attr{CmdSep} . '<' . $attr{CmdPfx} . $self->{stdin}
    if $self->{stdin};

  $pipe .= $attr{CmdSep} . '>' . $attr{CmdPfx} . $self->{stdout}
    if $self->{stdout};

  if ( $self->{stderr} )
  {
    if ( $self->{stdout} && $self->{stderr} eq $self->{stdout} )
    {
      $pipe .= $attr{CmdSep} . $attr{CmdPfx} . '2>&1';
    }
    else
    {
      $pipe .= $attr{CmdSep} . '2>' . $attr{CmdPfx} . $self->{stderr};
    }
  }

  $pipe;
}


sub run
{
  my $self = shift;

  # create list of commands in form appropriate for IPC::Run
  my @cmds = map { $_->render } @{$self->{cmd}};

  # now create harness.  this will include any redirections as well
  # as the pipe directives
  my @harness;

  # start harness off with first command
  push @harness, shift @cmds;

  # insert stdin redirection if requested.
  push @harness, '<', $self->{stdin}
    if defined $self->{stdin};

  # handle redirection of stderr.  this is done on a per process basis
  # to avoid any close-on-exec problems.  i don't know of any problems,
  # but why not avoid them?

  my @stderr = defined $self->{stderr} ? ( '2>>', $self->{stderr} ) : ();

  # add rest of commands
  push @harness, map { ('|', $_, @stderr) } @cmds;

  # insert stdout redirection if requested.
  push @harness, '>', $self->{stdout}
    if defined $self->{stdout};


  return IPC::Run::run( @harness )
}

sub valrep
{
  my $self = shift;

  $self->_error( __PACKAGE__, "::valrep: missing argument(s)\n" )
    unless 2 <= @_;

  my $pattern = shift;
  my $value = shift;
  my $lastvalue = shift;
  my $firstvalue = shift;

  my $match = 0;
  my $nmatch = $self->_valmatch( $pattern );

  # if there's only one match and firstvalue isn't set,
  # need to do something special so that lastvalue
  # will get used

  $firstvalue ||= $lastvalue if $nmatch == 1;
  $lastvalue  ||= $value;
  $firstvalue ||= $value;


  foreach ( @{$self->{cmd}} )
  {
    $match ++ if $_->valrep( $pattern,
			  $match == 0             ? $firstvalue :
			  $match == ($nmatch - 1) ? $lastvalue :
			                            $value
			);
  }
}

sub _valmatch
{
  my $self = shift;
  my $pattern = shift;

  my $match = 0;
  foreach ( @{$self->{cmd}} )
  {
    $match++ if $_->_valmatch($pattern);
  }
  $match;
}

sub _error
{
  my $self = shift;

  if ( $self->{attr}->{RaiseError} )
  {
    die @_;
  }
  else
  {
    carp @_;
  }
}

__END__

=head1 NAME

IPC::PipeC - manage command pipes

=head1 SYNOPSIS

  use IPC::PipeC;

  my $pipe = new IPC::PipeC;

  $pipe->argsep( ' ' );

  $pipe->add( $command, $arg1, $arg2 );
  $pipe->add( $command, $arg1, { option => value } );
  my $cmd = $pipe->add( $command, $arg1,
                     [ option1 => value1, option2 => value2] );

  $cmd->add( $arg1, $args, { option => value },
		  [option => value, option => value ] )

  $cmd->argsep( '=' );

  warn $pipe->dump, "\n";

  $cmd_to_be_run = $pipe->dumprun;

  $pipe->run;


=head1 DESCRIPTION

B<IPC::PipeC> provides a mechanism to maintain readable execution
pipelines.  Pipelines are created by adding commands to a B<IPC::PipeC>
object.  Options to the commands are set using a readable format;
B<IPC::PipeC> takes care of quoting strings, sticking equal signs in, etc.
The pipeline may be rendered into a nicely formatted string, as well
as being executed (currently by the Bourne shell, B</bin/sh>).

B<IPC::PipeC> actually manages a list of B<IPC::PipeC::Cmd> objects.  See
L<IPC::PipeC::Cmd> for more information.


=head1 METHODS

=over 8

=item new( [\%attr] )

B<new> creates a new C<IPC::PipeC> object with the optionally specified
attributes.  The attributes are specified via a hash, which may have
the following keys:

=over 8

=item ArgSep

This specifies the default string to separate arguments from their
values.  If this is undefined (the default), the argument name and
value are passed to the command separately.  The dumped output will
use a space.

New commands inherit the current value of the B<ArgSep> string.  The
default value may also be changed with the B<argsep> method for
B<IPC::PipeC> objects.  The separator for a given command may be
changed with the B<argsep> method for the command.


=back

=item add( [\%attr,] $command, @arguments )

This creates an B<IPC::PipeC::Cmd> object, adds it to the
B<IPC::PipeC> object, and returns a handle to it.  The optional hash
may be used to set attributes for the command (see
L<IPC::PipeC::Cmd>).  The command's B<ArgSep> attribute is set to that
of the B<IPC::PipeC> object.

Arguments to the command may be specified in one of the following
ways:

=over 8

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
B<IPC::PipeC::Cmd::argsep> method.

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
for the B<IPC::PipeC::Cmd::new> method.


=item run

Execute the pipe.  Returns true if the pipe ran to completion.

=item valrep( $pattern, $value, [$lastvalue, [$firstvalue] )

Replace arguments to options whose arguments match the Perl regular
expression, I<$pattern> with I<$value>.  If I<$lastvalue> is
specified, the last matched argument will be replaced with
I<$lastvalue>.  If I<$firstvalue> is specified, the first matched
argument will be replaced with I<$firstvalue>.

For example,

  my $pipe = new IPC::PipeC;
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

  my $pipe = new IPC::PipeC;
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

  my $pipe = new IPC::PipeC;
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
