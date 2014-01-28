package IPC::PrettyPipe::Executor;

use Moo::Role;

requires qw[ run ];

1;

__END__

=head1 NAME

IPC::PrettyPipe::Executor - role for executor backends

=head1 SYNOPSIS

  package IPC::PrettyPipe::Execute::My::Backend;

  sub run { }

  with 'IPC::PrettyPipe::Executor';

=head1 DESCRIPTION

This role defines the required interface for execution backends for
B<IPC::PrettyPipe>.  Backend classes must consume this role.


=head1 METHODS

The following methods must be defined:

=over

=item B<run>

Execute the pipeline.

=back


=head1 COPYRIGHT & LICENSE

Copyright 2013 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>

=cut


