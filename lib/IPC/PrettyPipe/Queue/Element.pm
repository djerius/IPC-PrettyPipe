#! perl

package IPC::PrettyPipe::Queue::Element;

use Moo::Role;

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


__END__

=head1 NAME

B<IPC::PrettyPipe::Queue::Element> - role for an element in an B<IPC::PrettyPipe::Queue>

=head1 SYNOPSIS

  with 'IPC::PrettyPipe::Queue::Element';


=head1 DESCRIPTION

This role should be composed into objects which will be contained in
B<IPC::PrettyPipe::Queue>s.  No object should be in more than one
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


=head1 COPYRIGHT & LICENSE

Copyright 2013 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>

=cut
