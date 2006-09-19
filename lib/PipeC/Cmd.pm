package PipeC::Cmd;

use strict;
use warnings;
use Carp;

our $MAGIC_CHARS = q/\\\$"'!*{};()[]<>&/; #";
$MAGIC_CHARS =~ s/(\W)/\\$1/g;

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
	$self->_error( __PACKAGE__, "::new: unknown attribute: $key\n" );
	return undef;
      }
    }
  }

  $self->_error(__PACKAGE__, 
		"::new: missing or unacceptable type for command" )
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
	$self->_error( __PACKAGE__,
		       "::add: odd number of elements in array: '@$arg'" );
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
      $self->_error( __PACKAGE__,
		     "::add: unacceptable argument to PipeC::Cmd::add\n" );
      return undef;
    }
  }

  1;
}

sub dump
{
  my $self = shift;
  my $attr = shift;

  $self->_error( __PACKAGE__, "::dump: illegal attribute argument\n" )
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

  $self->_error( __PACKAGE__, "::argsep: missing argument to argsep\n" )
    unless defined ( $self->{attr}->{ArgSep} = shift );
}

sub valrep
{
  my $self = shift;

  $self->_error( __PACKAGE__, "::valrep: missing argument(s) to valrep\n" )
    unless 2 <= @_;

  my $pattern = shift;
  my $value = shift;
  my $lastvalue = shift;
  my $firstvalue = shift;

  my $match = 0;
  my $nmatch = $self->_valmatch( $pattern );

  $firstvalue ||= $lastvalue if $nmatch == 1;
  $lastvalue  ||= $value;
  $firstvalue ||= $value;

  # first value may be special
  my $curvalue = $firstvalue;

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


  # if there's white space or a magic character, single quote the
  # entire word.  however, since single quotes can't be escaped inside
  # single quotes, isolate them from the single quoted part and escape
  # them.  i.e., the string a 'b turns into 'a '\''b'

  if ( $str =~ /[\s$MAGIC_CHARS]/o )
  {
    # isolate the lone single quotes
    $str =~ s/'/'\\''/g;

    # quote the whole string
    $str = "'$str'";

    # remove obvious duplicate quotes.
    $str =~ s/(^|[^\\])''/$1/g;
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

__END__

=head1 NAME

PipeC::Cmd - manage command pipe commands

=head1 SYNOPSIS

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
  

=head1 DESCRIPTION

B<PipeC::Cmd> objects are containers for the individual commands in a
pipeline created by B<PipeC>.  

=head1 METHODS

B<PipeC::Cmd> objects have a class constructor, but it is rarely used.
Instead, use the parent B<PipeC> object's B<add()> method.

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

=head1 COPYRIGHT & LICENSE

Copyright 2006 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
