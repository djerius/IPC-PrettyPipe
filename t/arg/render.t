#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Arg;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe::Arg->new( @_ ); }

sub run_methods {

    my $cmd = shift;

    while ( 1 ) {

        my ( $method, $args ) = ( shift, shift );
        last unless defined $method;
        $cmd->$method( @$args );
    }

    return;
}

sub run_test {

    my %args = @_;

    $args{render}  //= [];
    $args{methods} //= [];

    lives_and {

        my $arg = IPC::PrettyPipe::Arg->new( $args{new} );

        run_methods( $arg, @{ $args{methods} } );

        is_deeply( [ $arg->render( @{ $args{render} } ) ], $args{expect} );

    }
    $args{desc};

    return;
}



my @tests = (

    {
        desc => 'bool',
        new    => { name => 'a' },
        expect => [ 'a' ],
    },

    {
        desc => 'value',
        new    => { name => 'a', value => 42 },
        expect => [ [ a   => 42 ] ],
    },

    {
        desc => 'pfx',
        new  => {
            name   => 'a',
            value => 42,
            pfx   => '--',
        },
        expect => [ [ '--a' => 42 ] ],
    },

    {
        desc => 'sep',
        new  => {
            name   => 'a',
            value => 42,
            sep   => '=',
        },
        expect => [ 'a=42' ],
    },

    {
        desc => 'pfx+sep',
        new  => {
            name   => 'a',
            value => 42,
            pfx   => '--',
            sep   => '=',
        },
        expect => [ '--a=42' ],
    },

    {
        desc => 'pfx+sep',
        new  => {
            name   => 'a',
            value => q['33'],
            pfx   => '--',
            sep   => '=',
        },
        render => [{ quote => 1 }],
        expect => [ q('--a='\''33'\') ],
    },


    {
        desc => 'pfx, quote',
        new  => {
            name  => 'a',
            value => q['33'],
            pfx   => '-',
        },
        render => [{ quote => 1 }],
        expect => [ [ q(-a), q(\''33'\') ] ],
    },


    {
        desc => 'pfx, flatten',
        new  => {
            name  => 'a',
            value => 33,
            pfx   => '-',
        },
        render => [{ flatten => 1 }],
        expect => [ q(-a), 33 ],
    },

    {
        desc => 'pfx, defsep, no sep',
        new  => {
            name  => 'a',
            value => 33,
            pfx   => '-',
        },
        render => [{ defsep => ' ' }],
        expect => [ q(-a 33) ],
    },

    {
        desc => 'pfx, defsep, sep',
        new  => {
            name  => 'a',
            value => 33,
            pfx   => '-',
            sep   => '=',
        },
        render => [{ defsep => ' ' }],
        expect => [ q(-a=33) ],
    },

);

for my $test ( @tests ) {

    my %args = %$test;
    run_test( %args );

    $args{render} //= [{}];

    # now move sep & pfx to render
    $args{render}[0]{$_} = delete $args{new}{$_}
      for grep { exists $args{new}{$_} } qw[ sep ];

    $args{desc} = 'render ' . $args{desc};
    run_test( %args );

}

# corner cases

throws_ok {

	new( name => 'a' )->render( sep => [] );

} qr/invalid type/, "render: bad args check";

done_testing;
