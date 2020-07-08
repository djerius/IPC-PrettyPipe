package IPC::PrettyPipe::Arg::Format;

# ABSTRACT: Encapsulate argument formatting attributes

use Types::Standard qw[ Str ];

use Moo;

our $VERSION = '0.14';

with 'IPC::PrettyPipe::Format';


shadowable_attrs( qw[ pfx sep ] );

use namespace::clean;


=method B<new>

  $fmt = IPC::PrettyPipe::Arg::Format->new( %attr );

The constructor.

=cut


=attr pfx

The prefix to apply to an argument

=attr has_pfx

A predicate for the C<pfx> attribute.

=cut

has pfx => (
    is        => 'rw',
    isa       => Str,
    clearer   => 1,
    predicate => 1,
);

=attr sep

The string which will separate option names and values.  If C<undef> (the default),
option names and values will be treated as separate entities.

=attr has_sep

A predicate for the C<sep> attribute.


=cut

has sep => (
    is        => 'rw',
    isa       => Str,
    clearer   => 1,
    predicate => 1,
);

=method copy_into

  $self->copy_into( $dest, @attrs );

Copy the C<sep> and C<pfx> attributes from the object to the destination object.

=cut

sub copy_into { $_[0]->_copy_attrs( $_[1], 'sep', 'pfx' ); }


1;

# COPYRIGHT

__END__

=for stopwords
pfx
sep

=head1 SYNOPSIS

  use IPC::PrettyPipe::Arg::Format;

  $fmt = IPC::PrettyPipe::Arg::Format->new( %attr );

=head1 DESCRIPTION

This class encapsulates argument formatting attributes
