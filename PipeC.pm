# define the PipeC::Cmd class first, as it's used by PipeC


package PipeC::Cmd;
use strict;
use Carp;
use vars qw( $VERSION );
use Data::Dumper;

$VERSION = '1.03';

sub new
{
  my $this = shift;
  my $class = ref($this) || $this;
  
  my $self = {
              attr => { 
		       ArgSep => '=',
		       CmdPfx => "\t",
		       CmdOptSep => " \\\n",
		       OptSep => " \\\n",
		       OptPfx => "\t  ",
		       RaiseError => 0
		      },
	      cmd => undef,
              args => [ ],
             };
  
  bless $self, $class;

  if ( 'HASH' eq ref( $_[0] ) )
  {
    my $arg = shift;

    while ( my ( $key, $val ) = each ( %$arg ) )
    {
      if ( exists $self->{attr}->{$key} )
      {
	$self->{attr}->{$key} = $val;
      }
      else
      {
	$self->_error( "PipeC::Cmd::new unknown attribute: $key\n" );
	return undef;
      }
    }
  }

  $self->_error("missing or unacceptable type for command" )
    if ! defined( $self->{cmd} = shift) || ref( $self->{cmd} );

  $self->add( @_ ) or return undef;
  
  return $self;
}

sub add
{
  my $self = shift;

  while ( @_ )
  {
    my $arg = shift;
    
    # reference to hash?
    if    ( 'HASH' eq ref( $arg ) )
    {
      while ( my ( $key, $val ) = each  %$arg )
      {
	push @{$self->{args}}, [ $key, $val ];
      }
    }

    # reference to an array?
    elsif ( 'ARRAY' eq ref( $arg ) )
    {
      if ( @{$arg} % 2 )
      {
	$self->_error( "odd number of elements in array: '@$arg'" );
	return undef;
      }
      for ( my $i = 0 ; $i < @{$arg} ; $i += 2 )
      {
	push @{$self->{args}}, [ $arg->[$i], $arg->[$i+1] ];
      }
    }

    # not a reference?
    elsif ( ! ref ( $arg ) )
    {
      push @{$self->{args}}, $arg;
    }

    # everything else
    else
    {
      $self->_error( "unacceptable argument to PipeC::Cmd::add\n" );
      return undef;
    }
  }

  1;  
}

sub dump
{
  my $self = shift;
  my $attr = shift;

  $self->_error( "illegal attribute argument to dump\n" )
    if defined $attr && 'HASH' ne ref($attr);

  my %attr = ( %{$self->{attr}}, $attr ? %$attr : ());

  my $cmd = $attr{CmdPfx} . $self->{cmd} . 
    ( @{$self->{args}} ? $attr{CmdOptSep} . $attr{OptPfx} : '')
        .
    join( $attr{OptSep} . $attr{OptPfx},
	map { 
	   unless ( ref( $_ ) ) 
	   {
	     _shell_escape($_) 
	   }
	   else 
	   {
	     _shell_escape($_->[0]) . $attr{ArgSep} . 
	       _shell_escape($_->[1] eq '' ? '""' : $_->[1]) ;
	   }
	} @{$self->{args}}
	);
}

sub argsep
{
  my $self = shift;

  $self->_error( "missing argument to argsep\n" )
    unless defined ( $self->{attr}->{ArgSep} = shift );
}

sub valrep
{
  my $self = shift;

  $self->_error( "missing argument(s) to valrep\n" )
    unless 2 <= @_;

  my $pattern = shift;
  my $value = shift;
  my $lastvalue = shift;
  my $firstvalue = shift;

  $lastvalue  ||= $value;
  $firstvalue ||= $value;

  # first value may be special
  my $curvalue = $firstvalue;

  my $match = 0;
  my $nmatch = $self->_valmatch( $pattern );

  foreach ( @{$self->{args}} )
  {
    next unless ref( $_ );
    
    # last value may be special
    $curvalue = $lastvalue 
      if ($match + 1) == $nmatch;

    if ( $_->[1] =~ s/$pattern/$curvalue/ )
    {
      $match++;
      $curvalue = $value;
    }
  }

  $match;
}

sub _valmatch
{
  my $self = shift;
  my $pattern = shift;

  my $match = 0;
  foreach ( @{$self->{args}} )
  {
    next unless ref( $_ );
    $match++ if $_->[1] =~ /$pattern/;
  }
  $match;
}



sub _shell_escape
{
  my $str = shift;

  my $magic_chars = q{\\\$"'!*{};}; #"

  # if there's white space, single quote the entire word.  however,
  # since single quotes can't be escaped inside single quotes,
  # isolate them from the single quoted part and escape them.
  # i.e., the string a 'b turns into 'a '\''b' 
  if ( $str =~ /\s/ )
  {
    # isolate the lone single quotes
    $str =~ s/'/'\\''/g;

    # quote the whole string
    $str = "'$str'";

    # remove obvious duplicate quotes.
    $str =~ s/(^|[^\\])''/$1/g;
  }
  elsif ( $str =~ /[$magic_chars]/ )
  {
    $str =~  s/([$magic_chars])/\\$1/g;
  }

  # empty string
  elsif ( $str eq '' )
  {
    $str = "''";
  }
  $str;
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

=head1 NAME

PipeC - manage command pipes

=head1 SYNOPSIS

  use lib '/proj/axaf/simul/lib/perl';
  use PipeC;

  my $pipe = new PipeC;

  $pipe->argsep( ' ' );

  $pipe->add( $command, $arg1, $arg2 );
  $pipe->add( $command, $arg1, { option => value } );
  my $cmd = $pipe->add( $command, $arg1, 
                     [ option1 => value1, option2 => value2] );

  $cmd->add( $arg1, $args, { option => value }, 
		  [option => value, option => value ] )

  $cmd->argsep( '=' );

  warn $pipe->dump, "\n";

  $pipe->run;


=head1 DESCRIPTION

B<PipeC> provides a mechanism to maintain readable execution
pipelines.  Pipelines are created by adding commands to a B<PipeC>
object.  Options to the commands are set using a readable format;
B<PipeC> takes care of quoting strings, sticking equal signs in, etc.
The pipeline may be rendered into a nicely formatted string, as well
as being executed (currently by the Bourne shell, B</bin/sh>).

B<PipeC> actually manages a list of B<PipeC::Cmd> objects.  These
objects also have methods; descriptions are available in L<"PipeC::Cmd
Methods">

=cut

package PipeC;

use Carp;
use strict;
use vars qw( $VERSION );

$VERSION = '1.0';

=head2 PipeC Methods

=over 8

=item new [\%attr]

B<new> creates a new C<PipeC> object with the optionally specified
attributes.  The attributes are specified via a hash, which may have
the following keys:

=over 8

=item ArgSep

This specifies the default string to separate arguments from their
values.  It defaults to the C<=> character.  New commands inherit the
current value of the B<ArgSep> string.  The default value may also be
changed with the B<argsep> method for B<PipeC> objects.  The separator
for a given command may be changed with the B<argsep> method for the
command.


=back

=cut

sub new
{
  my $this = shift;
  my $class = ref($this) || $this;
  
  my $self = {
              attr => { ArgSep => '=' },
              cmd => [ ],
	      stdout => undef,
	      stderr => undef
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
          $self->_error( "PipeC::new unknown attribute: $key\n" );
          return undef;
        }
      }
    }
    else
    {
      $self->_error( "unacceptable argument to PipeC::new\n" );
      return undef;
    }
  }
  
  return $self;
}

=item add( [\%attr,] $command, <arguments> )

This adds a new command to the C<PipeC> object.  It returns a handle
to the command (which is itself a C<PipeC::Cmd> object).  The optional
hash may be used to set attributes for the command.
The I<\%attr> hash
may contain one of the following key/value pairs:

=over 8

=item CmdSep

The string to print between commands.  Defaults to " \n".

=item CmdPfx

The string to print before the command.  It defaults to "\t" to
line things up nicely.

=item CmdOptSep

The string to print between the command and the first option. Defaults to
" \\\n".

=item OptPfx

The string to print before each option.  Defaults to "\t".

=item OptSep

The string to print between the options.  Defaults to " \\\n".

=item ArgSep

The argument separator.  This defaults to separator in use at the time each
command was created via the C<PipeC::add> method.

=back

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


=cut

sub add
{
  my $self = shift;

  my $cmd = new PipeC::Cmd @_;

  if ( $cmd )
  {
    push @{$self->{cmd}}, $cmd;
    $cmd->argsep( $self->{attr}{ArgSep} );
  }

  $cmd;
}

=item argsep( $argsep )

This sets the default B<PipeC> string which separates options and their
arguments.  This affects subsequent commands added to the pipe only.
The  B<PipeC::Cmd::argsep> method is available for existing commands.

=cut

sub argsep
{
  my $self = shift;
  
  $self->_error( "missing argument to argsep\n" )
    unless defined ( $self->{attr}->{ArgSep} = shift );
}

=item stdin( $stdin )

This specifies a file to which the standard input stream of the
pipeline will be connected. if I<$stdout> is C<undef> or unspecified,
it cancels any value previously set.

=cut

sub stdin
{
  my $self = shift;
  $self->{stdin} = shift;
}

=item stdout( $stdout )

This specifies a file to which the standard output stream of the
pipeline will be written. if I<$stdout> is C<undef> or unspecified, it
cancels any value previously set.

=cut

sub stdout
{
  my $self = shift;
  $self->{stdout} = shift;
}

=item stderr( $stderr )

This specifies a file to which the standard output stream of the
pipeline will be written. if I<$stderr> is C<undef> or unspecified, it
cancels any value previously set.

=cut

sub stderr
{
  my $self = shift;
  $self->{stderr} = shift;
}

=item dump( \%attr )

This method returns a string containing the sequence of commands in the
pipe. By default, this is a "pretty" representation.  The I<\%attr> hash
may contain one of the following key/value pairs to change the output format:

=over 8

=item CmdSep

The string to print between commands.  Defaults to " \n".

=item CmdPfx

The string to print before the command.  It defaults to "\t" to
line things up nicely.

=item CmdOptSep

The string to print between the command and the first option. Defaults to
" \\\n".

=item OptPfx

The string to print before each option.  Defaults to "\t".

=item OptSep

The string to print between the options.  Defaults to " \\\n".

=item ArgSep

The argument separator.  This defaults to separator in use at the time each
command was created via the C<PipeC::add> method.

=back

=cut

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

  if ( defined $self->{stderr} )
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


=item run

Execute the pipe.  Currently this is done by passing it to the Perl
system command and using the Bourne shell to evaluate the pipe.
It returns the value returned by the system call.

=cut

sub run
{
  my $self = shift;


  system( $self->dump( {
			CmdPfx => '',
			CmdOptSep => '',
			OptPfx => ' '
		       }) );

}

=item valrep( $pattern, $value, [$lastvalue, [$firstvalue] )

Replace arguments to options whose arguments match the Perl regular
expression, I<$pattern> with I<$value>.  If I<$lastvalue> is
specified, the last matched argument will be replaced with
I<$lastvalue>.  If I<$firstvalue> is specified, the first matched
argument will be replaced with I<$firstvalue>.

For example,

	my $pipe = new PipeC;
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

=cut

sub valrep
{
  my $self = shift;

  $self->_error( "missing argument(s) to valrep\n" )
    unless 2 <= @_;

  my $pattern = shift;
  my $value = shift;
  my $lastvalue = shift;
  my $firstvalue = shift;

  $lastvalue  ||= $value;
  $firstvalue ||= $value;

  my $match = 0;
  my $nmatch = $self->_valmatch( $pattern );

  foreach ( @{$self->{cmd}} )
  {
    $match += $_->valrep( $pattern,
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
    $match += $_->_valmatch($pattern);
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

=pod

=back

=head2 PipeC::Cmd Methods

B<PipeC::Cmd> objects have methods of their own.

=over 8

=item add( <arguments> )

This method adds additional arguments to the command.  The format of
the arguments is the same as to the B<PipeC::add> method.  This is useful
if some arguments should be conditionally given, e.g.

	$cmd = $pipe->add( 'ls' );
	$cmd->add( '-l' ) if $want_long_listing;

=item dump( \%attr )

This method returns a string containing the command and its arguments.
By default, this is a "pretty" representation.  The I<\%attr> hash
may contain one of the following key/value pairs to change the output format:

=over 8

=item CmdPfx

The string to print before the command.  It defaults to "\t" to
line things up nicely.

=item CmdOptSep

The string to print between the command and the first option. Defaults to
" \\\n".

=item OptPfx

The string to print before each option.  Defaults to "\t".

=item OptSep

The string to print between the options.  Defaults to " \\\n".

=item ArgSep

The argument separator.  This defaults to separator in use at the time each
command was created via the C<PipeC::add> method.

=back

=item argsep( $argsep )

This specifies the string used to separate arguments from their values.  It
defaults to the default value for the parent B<PipeC> object when the
B<PipeC::Cmd> object was created, which may be set via the B<PipeC::argsep>
method, or when the initial B<PipeC> object is created.  

=item valrep( $pattern, $value, [$lastvalue, [$firstvalue] ] )

Replace arguments to options whose arguments match the Perl regular
expression, I<$pattern> with I<$value>.  If I<$lastvalue> is
specified, the last matched argument will be replaced with
I<$lastvalue>.

For example,

        $cmd = $pipe->add( 'cmd1' );
        $cmd->add( [ opt1 => 'FOO' ] );
        $cmd->add( [ opt2 => 'FOO' ] );

	$cmd->valrep( 'FOO', 'FOO1', 'FOO2' );
	print $cmd->dump, "\n"

results in

	        cmd1 \
	          opt1=FOO1 \
	          opt2=FOO2
	

If I<$firstvalue> is specified, the first matched argument will be
replaced with I<$lastvalue>:

        $cmd = $pipe->add( 'cmd1' );
        $cmd->add( [ opt1 => 'FOO' ] );
        $cmd->add( [ opt2 => 'FOO' ] );

	$cmd->valrep( 'FOO', 'FOO1', undef, 'FOO2' );
	print $cmd->dump, "\n"

results in

	        cmd1 \
	          opt1=FOO2 \
	          opt2=FOO1


=back

=head2 Examples


Sometimes it's not possible to determine beforehand which command in a
pipeline will be the final one in the pipe; thus, it's not possible to
specify which command actually writes the output file until the very
end. In the following example the programs recognize the token
C<stdout> to refer to the standard output stream; this is specific to
their implementation.

	my $pipe = new PipeC;
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


If programs can write to C<stdout> directly, one can use B<PipeC::stdout> 
(and B<PipeC::stderr>, if need be):

	my $pipe = new PipeC;
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

which results in:

	(       ls \
	|       wc \
	>       line_count \
	) \
	2>      error

The entire pipe is run as a subshell, to ensure that all of the commands'
standard error streams go to the same place.


=head1 AUTHOR

Diab Jerius ( djerius@cfa.harvard.edu )
