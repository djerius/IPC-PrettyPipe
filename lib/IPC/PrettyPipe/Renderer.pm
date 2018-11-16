package IPC::PrettyPipe::Renderer;

# ABSTRACT: role for renderer backends

use Moo::Role;

our $VERSION = '0.09';

use namespace::clean;

requires qw[ render ];

1;

# COPYRIGHT

__END__

=for stopwords
renderer

=head1 SYNOPSIS

  package IPC::PrettyPipe::Render::My::Backend;

  sub render { }

  with 'IPC::PrettyPipe::Renderer';

=head1 DESCRIPTION

This role defines the required interface for rendering backends for
B<L<IPC::PrettyPipe>>.  Backend classes must consume this role.


=head1 METHODS

The following methods must be defined:

=over

=item B<render>

Return the rendered the pipeline.

=back
