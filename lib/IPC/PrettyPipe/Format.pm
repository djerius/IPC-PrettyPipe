package IPC::PrettyPipe::Format;

# ABSTRACT: Format role

## no critic (ProhibitAccessOfPrivateData)

use Try::Tiny;
use Module::Load;


use Moo::Role;
our $VERSION = '0.11';

with 'MooX::Attributes::Shadow::Role';

requires 'copy_into';

use namespace::clean;

# IS THIS REALLY NEEDED?????  this will convert an attribute with a
# an undef value into a switch.
#
# undefined values are the same as not specifying a value at all
if ( 0 ) {
    around BUILDARGS => sub {

        my ( $orig, $class ) = ( shift, shift );

        my $attrs = $class->$orig( @_ );

        delete @{$attrs}{ grep { !defined $attrs->{$_} } keys %$attrs };

        return $attrs;
    };
}

sub _copy_attrs {

    my ( $from, $to ) = ( shift, shift );

    for my $attr ( @_ ) {


        next unless $from->${ \"has_$attr" };

        try {
            if ( defined( my $value = $from->$attr ) ) {

                $to->$attr( $value );

            }

            else {

                $to->${ \"clear_$attr" };

            }
        }
        catch {

            croak(
                "unable to copy into or clear attribute $attr in object of type ",
                ref $to,
                ": $_\n"
            );
        };

    }

    return;
}


=method copy_from

  $self->copy_from( $src );

Copy attributes from the C<$src> object into the object.


=cut

sub copy_from {

    $_[1]->copy_into( $_[0] );

    return;
}

=method clone

  $object = $self->clone;

Clone the object;

=cut

sub clone {

    my $class = ref( $_[0] );
    load $class;

    my $clone = $class->new;

    $_[0]->copy_into( $clone );

    return $clone;
}

=method new_from_attrs


   my $obj = IPC::PrettyPipe::Format->new_from_attrs( $container_obj, \%options );

Create a new object using attributes from the C<$container_obj>.

=cut

sub new_from_attrs {

    my $class = shift;
    load $class;

    return $class->new( $class->xtract_attrs( @_ ) );
}

=method new_from_hash


   my $obj = IPC::PrettyPipe::Format->new_from_hash( ?$container, \%attr );

Create a new object using attributes from C<%attr> which are indicated as
being shadowed from C<$container>.  If C<$container> is not specified
it is taken from the Caller's class.

=cut


sub new_from_hash {

    my $contained = shift;
    my $hash      = pop;

    my $container = shift || caller();

    load $contained;

    my $shadowed = $contained->shadowed_attrs( $container );

    my %attr;
    while ( my ( $alias, $orig ) = each %{$shadowed} ) {

        $attr{$orig} = $hash->{$alias} if exists $hash->{$alias};

    }

    return $contained->new( \%attr );
}

1;

# COPYRIGHT

__END__
