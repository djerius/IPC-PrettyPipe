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

package IPC::PipeC::Cmd;

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
		       ArgSep => undef,
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
	return;
      }
    }
  }

  $self->_error(__PACKAGE__, 
		"::new: missing or unacceptable type for command" )
    if ! defined( $self->{cmd} = shift) || ref( $self->{cmd} );

  $self->add( @_ ) or return;

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
	return;
      }
      for ( my $i = 0 ; $i < @{$arg} ; $i += 2 )
      {
	## no critic (ProhibitAccessOfPrivateData)
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
		     "::add: unacceptable argument to IPC::PipeC::Cmd::add\n" );
      return;
    }
  }

  1;
}

sub render {

    my ( $self ) = @_;

    return [
	    $self->{cmd},
	    map {
		     ! ref $_                      ? $_
		   : defined $self->{attr}{ArgSep} ? join( $self->{attr}{ArgSep}, @{$_} )
		                                   : @{$_} 
						   ;
	    } @{$self->{args}}
	   ];
}

sub dump
{
  my $self = shift;
  my $attr = shift;

  $self->_error( __PACKAGE__, "::dump: illegal attribute argument\n" )
    if defined $attr && 'HASH' ne ref($attr);

  my %attr = ( %{$self->{attr}}, $attr ? %$attr : ());

  $attr{ArgSep} = ' ' if ! defined $attr{ArgSep};

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
	       ## no critic (ProhibitAccessOfPrivateData)
	       _shell_escape($_->[0]) . $attr{ArgSep} .
	       _shell_escape($_->[1] eq '' ? '""' : $_->[1]) ;
	   }
	} @{$self->{args}}
	);
}

sub argsep
{
  my $self = shift;

  @_ || $self->_error( __PACKAGE__, "::argsep: missing argument to argsep\n" );

  $self->{attr}->{ArgSep} = shift;

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

    ## no critic (ProhibitAccessOfPrivateData)
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
      ## no critic (ProhibitAccessOfPrivateData)
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

IPC::PipeC::Cmd - manage command pipe commands

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


=head1 DESCRIPTION

B<IPC::PipeC::Cmd> objects are containers for the individual commands in a
pipeline created by B<IPC::PipeC>.

=head1 METHODS

B<IPC::PipeC::Cmd> objects have a class constructor, but it is rarely used.
Instead, use the parent B<IPC::PipeC> object's B<add()> method.

=over 8

=item new

  $obj = IPC::PipeC::Cmd->new( \%attr );

Create a B<IPC::PipeC::Cmd> object. The optional attribute hash
may contain the following keys:

=over 8

=item CmdPfx

The string to print before the command.  It defaults to C<\t> to
line things up nicely.

=item CmdOptSep

The string to print between the command and the first option.
This defaults to  C< \\n>.

=item OptPfx

The string to print before each option.
This defaults to C<\t  >.

=item OptSep

The string to print between the options.
This defaults to C< \\n>.

=item ArgSep

This specifies the default string to separate arguments from their
values.  If this is undefined (the default), the argument name and
value are passed to the command separately.  The dumped output will
use a space.

=item RaiseError

If true, throws exceptions upon error. This defaults to C<0>.

=back


=item add( @arguments )

This method adds additional arguments to the command.  The format of
the arguments is the same as to the B<IPC::PipeC::add> method.  This is useful
if some arguments should be conditionally given, e.g.

	$cmd = $pipe->add( 'ls' );
	$cmd->add( '-l' ) if $want_long_listing;

=item render

Returns an arrayref containing the command and its arguments, as appropriate
for passing to B<IPC::Run>.

=item dump( \%attr )

This method returns a string containing the command and its arguments.
By default, this is a "pretty" representation.  The I<\%attr> hash is
optional may contain any of the documented for the B<new> method.

=item argsep( $argsep )

This changes the B<ArgSep> attribute to the specified value.

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

=head1 COPYRIGHT & LICENSE

Copyright 2006 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
