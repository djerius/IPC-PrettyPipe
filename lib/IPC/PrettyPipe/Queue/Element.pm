package IPC::PrettyPipe::Queue::Element;

# ABSTRACT: role for an element in an B<IPC::PrettyPipe::Queue>

use Moo::Role;

use namespace::clean;

our $VERSION = '0.06';

has last => (
    is => 'rwp',
    default => sub { 0 },
    init_arg => undef,
);

has first => (
    is => 'rwp',
    default => sub { 0 },
    init_arg => undef,
);


1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

  with 'IPC::PrettyPipe::Queue::Element';


=head1 DESCRIPTION

This role should be composed into objects which will be contained in
B<L<IPC::PrettyPipe::Queue>> objects.  No object should be in more than one
queue at a time.


=head1 METHODS

The following methods are available:


=over

=item first

  $is_first = $element->first;

This returns true if the element is the first in its containing queue.

=item last

  $is_last = $element->last;

This returns true if the element is the last in its containing queue.

=back
