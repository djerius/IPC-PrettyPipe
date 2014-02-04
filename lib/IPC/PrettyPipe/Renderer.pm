package IPC::PrettyPipe::Renderer;

use Moo::Role;

requires qw[ render ];

1;

__END__

=head1 NAME

IPC::PrettyPipe::Renderer - role for renderer backends

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


=head1 COPYRIGHT & LICENSE

Copyright 2013 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>

=cut
