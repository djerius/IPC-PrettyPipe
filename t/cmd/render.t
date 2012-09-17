#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Cmd;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe::Cmd->new( @_ ); }


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

        my $cmd = new( @{ $args{new} } );

        run_methods( $cmd, @{ $args{methods} } );

        is_deeply( [ $cmd->render( @{ $args{render} } ) ], $args{expect} );

    }
    $args{desc};

    return;
}



my @tests = (

    {
        desc   => 'list',
        new    => [ 'ls', '-l', '-r' ],
        expect => [ 'ls', '-l', '-r' ],
    },

    {
        desc    => 'list, add',
        new     => ['ls'],
        methods => [
            argpfx => ['-'],
            add    => ['l'],
            add    => ['r'],
        ],
        expect => [ 'ls', '-l', '-r' ],
    },

    {
        desc    => 'list, add',
        new     => ['ls'],
        methods => [
            argpfx => ['-'],
            add    => [ ['l', 'r'], boolarr => 1 ],
        ],
        expect => [ 'ls', '-l', '-r' ],
    },

    {
        desc => 'array',
        new  => [ 'ls', [ -W => 80, -T => 3 ] ],
        expect => [ 'ls', ['-W', 80], ['-T', 3]  ],
    },

    {
        desc => 'add hash',
        new  => [ 'ls' ],
        methods => [
                    argsep => [ ' ' ],
                    add => [ { -W => 80 } ],
                   ],
        expect => [ 'ls', '-W 80' ],
    },

    {
        desc => 'array, add',
        new  => ['ls'],
        methods =>
          [ add => [ [ width => 80, tab => 3 ], pfx => '--', sep => '=' ], ],
        expect => [ 'ls', '--width=80', '--tab=3' ],
    },

    #  render args
    {
        desc => 'array, render pfx',
        new  => ['ls', [ -W => 80, -T => 3 ] ],
        render => [ sep => '=' ],
        expect => [ 'ls', '-W=80', '-T=3' ],
    },

    {
        desc => 'array, render pfx, hash',
        new  => ['ls', [ -W => 80, -T => 3 ] ],
        render => [ { sep => '=' } ],
        expect => [ 'ls', '-W=80', '-T=3' ],
    },

    {
        desc => 'array, render pfx',
        new  => ['ls', [ -W => 80, -T => 3 ] ],
        render => [ quote => 1, sep => '=' ],
        expect => [ 'ls', q['-W=80'], q['-T=3'] ],
    },


);


run_test( %$_ ) for @tests;


done_testing;
