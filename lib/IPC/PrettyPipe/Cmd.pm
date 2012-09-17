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

package IPC::PrettyPipe::Cmd;

use strict;
use warnings;
use Carp;

use List::Util qw[ sum first ];
use Params::Check qw[ check ];

use String::ShellQuote qw[ shell_quote ];

use Safe::Isa;

use IPC::PrettyPipe::Check;
use IPC::PrettyPipe::Arg;
use IPC::PrettyPipe::Stream;

use Moo;
use MooX::Types::MooseLike::Base ':all';

has cmd => (
    is    => 'ro',
    isa   => Str,
    required => 1,
);

has _args => (
    is       => 'ro',
    init_arg => 'args',
    coerce   => sub { ref $_[0] ? $_[0] : [ $_[0] ] },
    isa      => sub {
        die( "args must be a scalar or list\n" )
          unless 'ARRAY' eq ref( $_[0] );
    },
    default => sub { [] },
    clearer => 1,
);

# must delay building args until all attributes have been specified
has args => (
    is       => 'lazy',
    init_arg => undef,
);

has argsep => (
    is        => 'rw',
    isa       => ArgSep,
    default   => sub { undef },
    predicate => 1,
);


has argpfx => (
    is        => 'rw',
    default   => sub { '' },
);

has streams => (
    is        => 'ro',
    default   => sub { [] },
    init_arg => undef,
);

sub BUILDARGS {

    my $class = shift;

    return $_[0] if 1 == @_ && 'HASH' eq ref $_[0];

    return { cmd => shift, args => [@_] };
}

sub _build_args {

    my $self = shift;

    my $args = [];

    $self->_add( $args, $_ ) foreach @{ $self->_args };

    $self->_clear_args;

    return $args;
}

sub add {

    my $self = shift;

    $self->_add( $self->args, @_ );

    return;
}

# do something with an argument
sub _handle_arg {

    my ( $self, $attr, $args, $arg ) = ( shift, shift, shift, shift );

    if ( $arg->$_isa('IPC::PrettyPipe::Stream') ) {

        push @{ $self->streams }, $arg;

    }

    elsif ( $arg->$_isa('IPC::PrettyPipe::Arg') ) {

        push @{$args}, $arg;

    }

    elsif ( is_Str($arg) ) {

        if ( $arg =~ /[<>]/ ) {

            push @{ $self->streams },
              IPC::PrettyPipe::Stream->new(
                op => $arg,
                ( @_ ? ( target => shift ) : () )
              );
        }

        else {

            push @{$args},
              IPC::PrettyPipe::Arg->new(
                name => $arg,
                ( @_ ? ( value => shift ) : () ),
                %$attr
              );
        }

    }

    else {
        croak( __PACKAGE__, ": unexpected argument $arg" );
    }

}

sub _add {

    my ( $self, $args, $arg ) = ( shift, shift, shift );

    my $attr = check(
        {
            sep     => { default => $self->argsep, allow => CheckArgSep },
            pfx     => { default => $self->argpfx },
            boolarr => { default => 0 },
        },
        ( 'HASH' eq ref $_[0] ? $_[0] : {@_} )
    ) or croak( __PACKAGE__, "::add ", Params::Check::last_error() );

    if ( $attr->{boolarr} ) {

	croak( "expected arrayref when boolarr is true\n" )
	  unless 'ARRAY' eq ref $arg;

	$self->_handle_arg( $attr, $args, $_ ) for @{ $arg };

    }

    else {

	my $ref = ref $arg;

        if ( 'HASH' eq $ref ) {

            while ( my ( $key, $value ) = each %$arg ) {

		$self->_handle_arg( $attr, $args, $key, $value );

            }
        }

        elsif ( 'ARRAY' eq $ref ) {

            ## no critic (ProhibitAccessOfPrivateData)
            my $idx = 0;
            while ( $idx < @$arg ) {

                if ( ref $arg->[$idx] ) {

		    $self->_handle_arg( $attr, $args, $arg->[$idx++] );

                }

                else {

                    croak( __PACKAGE__,
                        "::add: not enough elements in array: '@$arg'" )
                      if $idx + 1 == @$arg;

		    $self->_handle_arg( $attr, $args, @{$arg}[$idx, $idx+1] );
                    $idx += 2;
                }

            }

        }

        # everything else
        else {

	    $self->_handle_arg( $attr, $args, $arg );

        }

    }

    return;
}

sub render {

    my $self = shift;

    my $args = check( {
            sep     => { allow => CheckArgSep },
            defsep  => { allow => CheckArgSep },
            flatten => { allow => CheckBool, default => 0 },
            quote   => { allow => CheckBool, default => 0 },
            stream  => { allow => CheckBool, default => 0 },
        },
        ( 'HASH' eq ref $_[0] ? $_[0] : {@_} )
    ) or croak( __PACKAGE__, ': ', Params::Check::last_error );

    my $render_stream = delete $args->{stream};

    my @retval = (
                  $self->cmd,
                  ( map { $_->render( $args ) } @{ $self->args },
                                                @{ $self->streams }
                  ),
                 );

    return @retval;
}


sub valmatch {
    my $self    = shift;
    my $pattern = shift;

    # find number of matches;
    return sum 0, map { $_->valmatch( $pattern ) } @{ $self->args };
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

    my $nmatch = $self->valmatch( $args->{pattern} );

    if ( $nmatch == 1 ) {

        $args->{lastvalue} //= $args->{firstvalue} // $args->{value};
        $args->{firstvalue} //= $args->{lastvalue};

    }
    else {
        $args->{lastvalue}  ||= $args->{value};
        $args->{firstvalue} ||= $args->{value};
    }

    my $match = 0;
    foreach ( @{ $self->args } ) {

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

IPC::PrettyPipe::Cmd - A command in an IPC::PrettyPipe pipeline

=head1 SYNOPSIS

  use IPC::PrettyPipe::Cmd;

  # one shot creation of command; group arguments and values, streams
  $cmd = IPC::PrettyPipe::Cmd->new( make => [ '-f', 'Makefile' ],
                                    [ '>', 'output_file' ],
                                  );

  # mix long and short arguments; default to short
  $cmd = IPC::PrettyPipe::Cmd->new( 'ls' );
  $cmd->argpfx( '-');

  # or use named args; can specify extra attributes
  # note enclosure in hash
  $cmd = IPC::PrettyPipe::Cmd->new( { cmd => 'ls', argpfx => '-' } );

  # add a single boolean argument
  $cmd->add( 'f' );
  $cmd->add( 'r' );

  # add multiple boolean arguments
  $cmd->add( [ 'm', 'k' ], boolarr => 1 );

  # add long options; if order is important, use an array instead
  # of a hash.
  $cmd->add( { width => 80, sort => 'time' }, pfx => '--', sep => '=' );

  # perform value substution on a command's arguments' values
  $cmd->valsubst( %stuff );

  # attach a stream to the command
  $cmd->add_stream( $op, [ $target ] );

  # return an encoded, prettified command line
  $cmd->render;


=head1 DESCRIPTION

B<IPC::PrettyPipe::Cmd> objects are containers for the individual commands in a
pipeline created by B<IPC::PrettyPipe>.  Typically they are created automatically
by B<IPC::PrettyPipe::add>.

=head1 METHODS

=over

=item B<new>

  # positional arguments
  $cmd = IPC::PrettyPipe::Cmd->new( $cmd, @args );

  # named arguments; other attributes may be specified
  $cmd = IPC::PrettyPipe::Cmd->new( cmd => $cmd, %attr );

Objects may be created either with a simplified positional interface,
or with a named argument interface, which provides for the possibility
of specifying additonal attributes.

The available attributes are:

=over

=item C<cmd>

The name of the program to execute

=item C<args>

The arguments to the program. If passed as a named attribute, this
must be an arrayref.  An argument specification may be one of

=over

=item an B<IPC::PrettyPipe::Arg> object

The object is added (not copied!).

=item a string

This specifies the argument's name and that it takes no value.

=item an arrayref

This may contain a combination of B<IPC::PrettyPipe::Arg> objects or
I<pairs> of names and values.  The arguments will be supplied to the
command in the order they appear in the array.

=item a hashref

This specifies one or more pairs of names and values.
The arguments will be supplied to the command in a random order.


=back


=item C<argpfx>

A string prefix to be applied to the argument names before being
rendered.  See the C<pfx> attribute in L<IPC::PrettyPipe::Arg> for
more information.  This provides a default; it may be overridden.


=item C<argsep>

A string to insert between argument names and values when rendering.
See the C<sep> attribute in L<IPC::PrettyPipe::Arg> for more
information.  This provides a default; it may be overridden.

=back

=item B<add>

  $cmd->add( $args, %options );

This method adds one or more additional arguments to the command.
This is useful if some arguments should be conditionally given, e.g.

	$cmd = IPC::PrettyPipe::Cmd->new( 'ls' );
	$cmd->add( '-l' ) if $want_long_listing;

I<$args> may take any of the forms that the C<args> attribute to the
B<new> method accepts.

The available options are:

=over

=item C<boolarr>

This is a boolean value indicating that the passed C<$args> element is
an array containing the names of boolean (switch) arguments and not
name-value pairs.

=item C<pfx>

A string prefix to be applied to the argument names before being
rendered.  This overrides that specified by the C<argpfx> attribute
in the constructor.


=item C<sep>

A string to insert between argument names and values when rendering.
This overrides that specified by the C<argsep> attribute in the
constructor.

=back


=item B<render>

  $rendered_cmd = $cmd->render( %options )

Render the command, returning an arrayref containing the command and
its rendered arguments. See the B<render> method in
L<IPC::PrettyPipe::Arg> for a description of I<%options> and the format
of the rendered arguments.


=item B<valmatch>

  $n = $cmd->valmatch( $pattern );

Returns the number of arguments whose value a matched the passed
regular expression.

=item B<valsubst>

  $cmd->valsubst( $pattern, $value, %options );

Replace arguments to options whose arguments match the Perl regular
expression I<$pattern> with I<$value>. The following options are available:

=over

=item C<firstvalue>

If specified, the first occurance of a match will be replaced with
this.

=item C<lastvalue>

If specified, the last occurance of a match will be replaced with
this.  In the case where there is only one match and both
C<firstvalue> and C<lastvalue> are specified, C<lastvalue> takes
precedence.

=back

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
