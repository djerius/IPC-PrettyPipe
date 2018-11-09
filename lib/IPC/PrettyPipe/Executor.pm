package IPC::PrettyPipe::Executor;

# ABSTRACT: role for executor backends

use Moo::Role;

our $VERSION = '0.04';

requires qw[ run ];

use namespace::clean;

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

  package IPC::PrettyPipe::Execute::My::Backend;

  sub run { }

  with 'IPC::PrettyPipe::Executor';

=head1 DESCRIPTION

This role defines the required interface for execution backends for
B<L<IPC::PrettyPipe>>.  Backend classes must consume this role.


=head1 METHODS

The following methods must be defined:

=over

=item B<run>

Execute the pipeline.

=back
