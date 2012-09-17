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

package IPC::PrettyPipe::Arg;

use strict;
use warnings;
use Carp;

use Params::Check qw[ check ];
use String::ShellQuote qw[ shell_quote ];

use IPC::PrettyPipe::Check;

use Moo;
use MooX::Types::MooseLike::Base ':all';

has name => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has value => (
    is        => 'rwp',
    isa       => Str,
    predicate => 1,
);

has pfx => (
    is      => 'ro',
    isa       => Str,
    default => sub { '' },
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

	return { name => shift } if @_ == 1;

	return { name => shift, value => shift }
	  if @_ == 2 && $_[0] ne 'name';

	return {@_};
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

    my @retval;

    if ( $self->has_value ) {

        ## no critic (ProhibitAccessOfPrivateData)

	    my $sep = $args->{sep} // $self->sep;

        @retval =
          defined $sep
          ? $self->pfx . $self->name . $sep . $self->value
          : ( $self->pfx . $self->name, $self->value );

    }

    else {

        @retval = $self->pfx . $self->name;
    }

    @retval = map { shell_quote( $_ ) } @retval
      if $args->{quote};

    @retval = ( join( $args->{defsep}, @retval ) )
      if exists $args->{defsep};

    return
        1 == @retval      ? $retval[0]
      : $args->{flatten}  ? @retval
      :                     \@retval;
}

sub valmatch {

    my $self    = shift;
    my $pattern = shift;

    return $self->has_value && $self->value =~ /$pattern/;
}

sub valsubst {

    my $self = shift;

    my ( $pattern, $rep ) = @_;

    if ( $self->has_value && ( my $value = $self->value ) =~ s/$pattern/$rep/ )
    {

        $self->_set_value( $value );

        return 1;

    }

    return 0;
}

1;


__END__

=head1 NAME

IPC::PrettyPipe::Arg - An argument to a IPC::PrettyPipe::Cmd command

=head1 SYNOPSIS

  use IPC::PrettyPipe::Arg;

  # positional arguments
  $bool_arg  = IPC::PrettyPipe::Arg->new( $name );
  $value_arg = IPC::PrettyPipe::Arg->new( $name, $value );

  # named arguments; allows specifying other attributes, such as prefix
  # note enclosure in hash
  $bool_arg  = IPC::PrettyPipe::Arg->new( { name => $name } );
  $value_arg = IPC::PrettyPipe::Arg->new( { name => $name,
                                          value => $value } );

  # perform value substitution
  $arg->valsubst( $pattern, $rep );

  # return a rendered argument
  $arg->render;

=head1 DESCRIPTION

B<IPC::PrettyPipe::Arg> objects are containers for arguments to commands in an
B<IPC::PrettyPipe::Cmd> object.  They are typically automatically created
by the B<IPC::PrettyPipe::Cmd> object.

=head1 METHODS

=over 8

=item B<new>

  # positional interface
  $arg = IPC::PrettyPipe::Arg->new( $name );
  $arg = IPC::PrettyPipe::Arg->new( $name, $value );

  # named interface; may provide additional attributes
  $arg = IPC::PrettyPipe::Arg->new( name => $name, value => $value );
  $arg = IPC::PrettyPipe::Arg->new( \%attr );

Objects may be created either with a simplified positional interface, or with
a named argument interface, which provides additonal attributes.

The available attributes are:

=over

=item C<name>

The name of the argument.  This is required.

=item C<value>

The value of the argument.  If an argument is a switch, no value is required.

=item C<pfx>

A string prefix to be applied to the argument name before being
rendered. This is often C<-> or C<-->.

A prefix is not required (the argument name may already have it). This
attribute is useful when programmatically creating arguments from
hashes where the keys do not contain a prefix.

=item C<sep>

A string to insert between the argument name and value when rendering.
In some cases arguments must be a single string where the name and
value are separated with an C<=> character; in other cases they
are treated as separate entities.  This defaults to C<undef>, indicating
that they are treated as separate entitites.

=back

=item B<render>

  $rendered_arg = $arg->render( %options )

Render the argument.  If the argument's C<sep> attribute is defined, B<render>
returns a string which looks like:

  $pfx . $name . $sep . $value

If C<sep> is not defined, it returns an array ref which looks like

  [ $pfx . $name, $value ]

unless the C<flatten> option is specified, in which case it returns a list

  $pfx . $name, $value

If the argument has no value, it returns

  $pfx . $name

The available options are:

=over

=item C<sep>

Override the existing value of the C<sep> attribute.

=item C<defsep>

Override the existing value of the C<sep> attribute, but only if it
was C<undef>. Quoting is also affected; see below.

=item C<quote>

Quote the rendered argument so that it's contents will survive parsing
by a shell (currently uses L<String::ShellQuote>).

If the argument has a defined C<sep> attribute, the entire

  $pfx . $name . $sep . $value

string is quoted at once.  Otherwise  the argument's name and
value are quoted separately.

If the C<defsep> option is specified, the quotation is done prior
to joining the name and value with C<defsep>

=item C<flatten>

Return a list rather than an arrayref if C<sep> is undefined and the
argument has a value.

=back

=item valmatch

  $bool = $arg->valmatch( $pattern );

Returns true if the argument has a value and it matches the passed
regular expression.

=item valsubst

  $arg->valsubst( $pattern, $rep );

If the argument has a value, perform the equivalent to

  $value =~ s/$pattern/$rep/;

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
