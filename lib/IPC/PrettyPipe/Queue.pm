package IPC::PrettyPipe::Queue;

# ABSTRACT: A simple queue

use Moo;

our $VERSION = '0.13';

use Safe::Isa;
use Types::Standard -types;

use namespace::clean;


=method new

  $q = IPC::PrettyPipe::Queue->new( %attributes );

Construct a new queue.  See L</ATTRIBUTES> for the available attributes. 

=cut

=for Pod::Coverage BUILD

=cut

sub BUILD {

    my $self = shift;

    if ( @{ $self->elements } ) {

        for ( @{ $self->elements } ) {
            $_->_set_first( 0 );
            $_->_set_last( 0 );
        }

        $self->elements->[0]->_set_first( 1 );
        $self->elements->[-1]->_set_last( 1 );
    }
}



=method elements

  $elements = $q->elements;

Returns an arrayref containing the queue's elements.

=cut

=attr elements

The initial set of queue elements.  This should be an arrayref of objects
which consume the L<IPC::PrettyPipe::Queue::Element> role.x

=cut

has elements => (
    is      => 'ro',
    isa     => ArrayRef [ ConsumerOf ['IPC::PrettyPipe::Queue::Element'] ],
    default => sub { [] },
);

=method empty

  $is_q_empty = $q->empty;

Returns true if there are no elements in the queue.

=cut

sub empty { !!!@{ $_[0]->elements } }

=method nelements

  $nelements = $q->nelements;

Returns the number of elements in the queue.

sub nelements { scalar @{ $_[0]->elements } }

=cut

=method push

  $q->push( $element );

Push the element on the end of the queue.  The element must perform
the B<L<IPC::PrettyPipe::Queue::Element>> role.

=cut

sub push {

    my ( $self, $elem ) = ( shift, shift );

    die(
        "attempt to push an incompatible element onto an IPC::PrettyPipe::Queue\n"
    ) unless $elem->$_does( 'IPC::PrettyPipe::Queue::Element' );

    my $elements = $self->elements;

    if ( @$elements ) {
        ## no critic (ProhibitAccessOfPrivateData)
        $elements->[-1]->_set_last( 0 );
        $elem->_set_last( 1 );
        $elem->_set_first( 0 );
    }
    else {

        $elem->_set_last( 1 );
        $elem->_set_first( 1 );

    }

    push @{$elements}, $elem;

    return;
}

1;

# COPYRIGHT

__END__

=for stopwords
nelements

=head1 SYNOPSIS

  $q = IPC::PrettyPipe::Queue->new( elements => [...] );

  $q->push( $elem );

  $elements = $q->elements;
  $is_q_empty = $q->empty;


=head1 DESCRIPTION

This module provides a simple queue for objects which perform the
B<L<IPC::PrettyPipe::Queue::Element>> role.  No object should be in more than
one queue at a time.

=head1 METHODS

The following methods are available:


=over

=back


=head1 COPYRIGHT & LICENSE

Copyright 2014 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>

=cut
