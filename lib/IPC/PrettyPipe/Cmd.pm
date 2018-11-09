package IPC::PrettyPipe::Cmd;

# ABSTRACT: A command in an B<IPC::PrettyPipe> pipeline

use Carp;

use List::Util qw[ sum pairs ];
use Scalar::Util qw[ blessed ];

use Try::Tiny;

use Safe::Isa;

use IPC::PrettyPipe::Arg;
use IPC::PrettyPipe::Stream;

use Types::Standard -all;
use Type::Params qw[ validate ];

use IPC::PrettyPipe::Types -all;
use IPC::PrettyPipe::Queue;
use IPC::PrettyPipe::Arg::Format;

use String::ShellQuote 'shell_quote';

use Moo;

our $VERSION = '0.04';

with 'IPC::PrettyPipe::Queue::Element';

use namespace::clean;


# need access to has method which will get removed at the end of the
# compilation of this module
BEGIN {
    IPC::PrettyPipe::Arg::Format
        ->shadow_attrs( fmt => sub { 'arg' . shift } );
}

has cmd => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

# delay building args until all attributes have been specified
has _init_args => (
    is       => 'ro',
    init_arg => 'args',
    coerce   =>  AutoArrayRef->coercion,
    isa =>  ArrayRef,
    predicate => 1,
    clearer   => 1,
);

has args => (
    is       => 'ro',
    default  => sub { IPC::PrettyPipe::Queue->new },
    init_arg => undef,
);

has streams => (
    is       => 'ro',
    default  => sub { IPC::PrettyPipe::Queue->new },
    init_arg => undef,
);

has argfmt => (
  is => 'ro',
  lazy => 1,
  handles => IPC::PrettyPipe::Arg::Format->shadowed_attrs,
  default => sub { IPC::PrettyPipe::Arg::Format->new_from_attrs( shift ) },
);

=for Pod::Coverage BUILDARGS BUILD

=cut

sub BUILDARGS {

    my $class = shift;

    my $args
      = @_ == 1
      ? (
        'HASH' eq ref( $_[0] )        ? $_[0]
        : 'ARRAY' eq ref( $_[0] )
          && @{ $_[0] } == 2          ? { cmd => $_[0][0], args => $_[0][1] }
        :                               { cmd => $_[0] }
        )
      : {@_};

    ## no critic (ProhibitAccessOfPrivateData)
    delete @{$args}{ grep { ! defined $args->{$_} }  keys %$args };

    return $args;
}


sub BUILD {


    my $self = shift;

    if ( $self->_has_init_args ) {

        $self->ffadd( @{ $self->_init_args } );
        $self->_clear_init_args;
    }

    return;
}

sub quoted_cmd {  shell_quote( $_[0]->cmd )  }

sub add {

    my $self = shift;

    unshift @_, 'arg' if @_ == 1;

    ## no critic (ProhibitAccessOfPrivateData)

    my $argfmt = $self->argfmt->clone;

    my $argfmt_attrs = IPC::PrettyPipe::Arg::Format->shadowed_attrs;

    my ( $attr ) = validate(
        \@_,
        slurpy Dict [
            arg    => Str | Arg | ArrayRef | HashRef,
            value  => Optional [Str],
            argfmt => Optional [ InstanceOf ['IPC::PrettyPipe::Arg::Format'] ],
            ( map { $_ => Optional [Str] } keys %{$argfmt_attrs} ),
        ] );

    my $arg = $attr->{arg};
    my $ref = ref $arg;

    croak( "cannot specify a value if arg is a hash, array, or Arg object\n" )
      if $ref && exists $attr->{value};

    $argfmt->copy_from( $attr->{argfmt} ) if defined $attr->{argfmt};
    $argfmt->copy_from( IPC::PrettyPipe::Arg::Format->new_from_hash( $attr ) );

    if ( 'HASH' eq $ref ) {

        while ( my ( $name, $value ) = each %$arg ) {

            $self->args->push(
                IPC::PrettyPipe::Arg->new(
                    name  => $name,
                    value => $value,
                    fmt   => $argfmt->clone
                ) );

        }
    }

    elsif ( 'ARRAY' eq $ref ) {

        croak( "missing value for argument ", $arg->[-1] )
          if  @$arg % 2;

        foreach ( pairs @$arg ) {

            my ( $name, $value ) = @$_;

            $self->args->push(
                IPC::PrettyPipe::Arg->new(
                    name  => $name,
                    value => $value,
                    fmt   => $argfmt->clone
                ) );

        }
    }

    elsif ( $arg->$_isa( 'IPC::PrettyPipe::Arg' ) ) {

        $self->args->push( $arg );

    }

    # everything else
    else {

        $self->args->push(
            IPC::PrettyPipe::Arg->new(
                name => $attr->{arg},
                exists $attr->{value} ? ( value => $attr->value ) : (),
                fmt => $argfmt->clone
            ) );
    }

    return;
}


# free form add
sub ffadd {

    my $self = shift;
    my @args = @_;

    my $argfmt = $self->argfmt->clone;

    for ( my $idx = 0 ; $idx < @args ; $idx ++ ) {

        my $t = $args[$idx];

        if ( $t->$_isa( 'IPC::PrettyPipe::Arg::Format' ) ) {

            $t->copy_into( $argfmt );

        }

        elsif ( $t->$_isa( 'IPC::PrettyPipe::Arg' ) ){

            $self->add( arg => $t );


        }

        elsif( ref( $t ) =~ /^(ARRAY|HASH)$/ )  {

            $self->add( arg => $t, argfmt => $argfmt->clone );

        }

        elsif ( $t->$_isa( 'IPC::PrettyPipe::Stream' ) ) {

            $self->stream( $t );

        }

        else {

            try {

                my $stream = IPC::PrettyPipe::Stream->new(
                    spec     => $t,
                    strict => 0,
                );

                if ( $stream->requires_file ) {

                        croak( "arg[$idx]: stream operator $t requires a file\n" )
                          if ++$idx == @args;

                        $stream->file( $args[$idx] );
                }

                $self->stream( $stream );
            }
            catch {

                die $_ if /requires a file/;

                $self->add( arg => $t, argfmt => $argfmt->clone );
            };

        }
    }

    return;
}

sub stream {

    my $self = shift;

    my $spec = shift;

    if ( $spec->$_isa( 'IPC::PrettyPipe::Stream' ) ) {

        croak( "too many arguments\n" )
          if @_;

        $self->streams->push( $spec );

    }

    elsif ( !ref $spec ) {

        $self->streams->push(
          IPC::PrettyPipe::Stream->new( spec => $spec, +@_ ? ( file => @_ ) : () )
                             );
    }

    else {

        croak( "illegal stream specification\n" );

    }


    return;
}


sub valmatch {
    my $self    = shift;
    my $pattern = shift;

    # find number of matches;
    return sum 0, map { $_->valmatch( $pattern ) } @{ $self->args->elements };
}

sub valsubst {
    my $self = shift;

    my @args = ( shift, shift, @_ > 1 ? { @_ } : @_ );


    ## no critic (ProhibitAccessOfPrivateData)

    my ( $pattern, $value, $args ) =
      validate( \@args,
                RegexpRef,
                Str,
                Optional[ Dict[
                            lastvalue  => Optional[ Str ],
                            firstvalue => Optional[ Str ]
                           ] ],
              );

    my $nmatch = $self->valmatch( $pattern );

    if ( $nmatch == 1 ) {

        $args->{lastvalue} //= $args->{firstvalue} // $value;
        $args->{firstvalue} //= $args->{lastvalue};

    }
    else {
        $args->{lastvalue}  ||= $value;
        $args->{firstvalue} ||= $value;
    }

    my $match = 0;
    foreach ( @{ $self->args->elements } ) {

        $match++
          if $_->valsubst( $pattern,
              $match == 0 ? $args->{firstvalue}
            : $match == ( $nmatch - 1 ) ? $args->{lastvalue}
            :                             $value );
    }

    return $match;
}


1;

# COPYRIGHT

__END__

=for stopwords
Bourne
argfmt
argpfx
argsep
cmd
ffadd
valmatch
valsubst


=head1 SYNOPSIS

  use IPC::PrettyPipe::Cmd;

  # named arguments
  $cmd = IPC::PrettyPipe::Cmd->new( cmd  => $cmd,
                                    args => $args,
                                    %attrs
                                  );

  # concise constructor interface
  $cmd = IPC::PrettyPipe::Cmd->new( $cmd );
  $cmd = IPC::PrettyPipe::Cmd->new( [ $cmd, $args ] );

  #####
  # different argument prefix for different arguments
  $cmd = IPC::PrettyPipe::Cmd->new( 'ls' );
  $cmd->argpfx( '-' ); # prefix applied to subsequent arguments
  $cmd->add( 'f' );    # -f
  $cmd->add( 'r' );    # -r

  # "long" arguments, random order
  $cmd->add( { width => 80, sort => 'time' },
               argpfx => '--', argsep => '=' );

  # "long" arguments, specified order
  $cmd->add( [ width => 80, sort => 'time' ],
               argpfx => '--', argsep => '=' );

  # attach a stream to the command
  $cmd->stream( $spec, $file );

  # be a little more free form in adding arguments
  $cmd->ffadd( '-l', [-f => 3, -b => 9 ], '>', 'stdout' );

  # perform value substution on a command's arguments' values
  $cmd->valsubst( %stuff );


=head1 DESCRIPTION

B<IPC::PrettyPipe::Cmd> objects are containers for the individual
commands in a pipeline created by B<L<IPC::PrettyPipe>>.  A command
may have one or more arguments, some of which are options consisting
of a name and an optional value.

Options traditionally have a prefix (e.g. C<--> for "long" options,
C<-> for short options).  B<IPC::PrettyPipe::Cmd> makes no distinction
between option and non-option arguments.  The latter are simply
specified as arguments with a blank prefix.


=head1 METHODS

=head2 Constructor

=over

=item B<new>

  # constructor with named arguments
  $cmd = IPC::PrettyPipe::Cmd->new( cmd => $cmd, %attr );

  # concise constructor interface
  $cmd = IPC::PrettyPipe::Cmd->new( $cmd );
  $cmd = IPC::PrettyPipe::Cmd->new( [ $cmd, $args ] );


Construct a B<IPC::PrettyPipe::Cmd> object encapsulating C<$cmd>.
C<$cmd> must be specified.


The available attributes are:

=over

=item C<cmd>

The program to execute.

=item C<args>

I<Optional>. Arguments for the program.  C<args> may be

=over

=item *

A scalar, e.g. a single argument;

=item *

An B<L<IPC::PrettyPipe::Arg>> object;

=item *

A hashref with pairs of names and values. The arguments will be
supplied to the command in a random order.

=item *

An array reference containing more complex argument specifications.
Its elements are processed with the B<L</ffadd>> method.

=back

=item C<argpfx>, C<argsep>

I<Optional>.  The default prefix and separation attributes for
command arguments.  See B<L<IPC::PrettyPipe::Arg>> for more
details.  These override any specified via the C<L</argfmt>> object.

=item C<argfmt>

I<Optional>. An B<L<IPC::PrettyPipe::Arg::Format>> object which will be used to
specify the default prefix and separation attributes for arguments to
commands.  May be overridden by C<L</argpfx>> and C<L</argsep>>.


=back

=back

=head2 Other methods

=over

=item B<add>

  $cmd->add( $args );
  $cmd->add( arg => $args, %options );

Add one or more arguments to the command.  If a single parameter is
passed, it is assumed to be the C<arg> parameter.

This is useful if some arguments should be conditionally given, e.g.

        $cmd = IPC::PrettyPipe::Cmd->new( 'ls' );
        $cmd->add( '-l' ) if $want_long_listing;


The available options are:

=over

=item C<arg>

The argument or arguments to add.  It may take one of the following
values:

=over

=item *

an B<L<IPC::PrettyPipe::Arg>> object;

=item *

A scalar, e.g. a single argument;

=item *

An arrayref with pairs of names and values.  The arguments will be supplied to the
command in the order they appear.

=item *

A hashref with pairs of names and values. The arguments will be supplied to the
command in a random order.

=back

=item C<argpfx> => I<string>

=item C<argsep> => I<string>

These override the object's C<argpfx> and C<argsep> attributes for this
argument only.

=item C<argfmt> => B<L<IPC::PrettyPipe::Arg::Format>> object

This will override the format attributes for this argument only.

=back

=item B<args>

  $args = $cmd->args;

Return a B<L<IPC::PrettyPipe::Queue>> object containing the
B<L<IPC::PrettyPipe::Arg>> objects associated with the command.

=item B<argpfx>,

=item B<argsep>

=item B<argfmt>

Retrieve (when called with no arguments) or modify (when called with
an argument) the similarly named object attributes.  See
B<L<IPC::PrettyPipe::Arg>> for more information.  Changing them
affects new, not existing, arguments;

=item B<cmd>

  $name = $cmd->cmd

Return the name of the command.

=item B<quoted_cmd>

  $name = $cmd->quoted_cmd

Return the name of the command, appropriately quoted for passing as a
single word to a Bourne compatible shell.

=item B<ffadd>

  $cmd->ffadd( @arguments );

A more relaxed means of adding argument specifications. C<@arguments>
may contain any of the following items:

=over

=item *

an B<L<IPC::PrettyPipe::Arg>> object

=item *

A scalar, representing an argument without a value.

=item *

An arrayref with pairs of names and values.  The arguments will be supplied to the
command in the order they appear.

=item *

A hashref with pairs of names and values. The arguments will be supplied to the
command in a random order.

=item *

An B<L<IPC::PrettyPipe::Arg::Format>> object, specifying the prefix
and separator attributes for successive arguments.

=item *

An B<L<IPC::PrettyPipe::Stream>> object

=item *

A string which matches a stream specification
(L<IPC::PrettyPipe::Stream::Utils/Stream Specification>), which will cause
a new I/O stream to be attached to the command.  If the specification
requires an additional parameter, the next value in C<@arguments> will be
used for that parameter.

=back

=item B<stream>

  $cmd->stream( $stream_obj );
  $cmd->stream( $spec );
  $cmd->stream( $spec, $file );

Add an I/O stream to the command.  It may be passed either a stream
specification (L<IPC::PrettyPipe::Stream::Utils/Stream Specification>)
or an B<L<IPC::PrettyPipe::Stream>> object.

See B<L<IPC::PrettyPipe::Stream>> for more information.

=item B<streams>

  $streams = $cmd->streams

Return a B<L<IPC::PrettyPipe::Queue>> object containing the
B<L<IPC::PrettyPipe::Stream>> objects associated with the command.

=item B<valmatch>

  $n = $cmd->valmatch( $pattern );

Returns the number of arguments whose value matches the passed
regular expression.

=item B<valsubst>

  $cmd->valsubst( $pattern, $value, %options );

Replace the values of arguments whose names match the Perl regular
expression I<$pattern> with I<$value>. The following options are
available:

=over

=item C<firstvalue>

If true, the first occurence of a match will be replaced with
this.

=item C<lastvalue>

If true, the last occurence of a match will be replaced with
this.  In the case where there is only one match and both
C<firstvalue> and C<lastvalue> are specified, C<lastvalue> takes
precedence.

=back

=back
