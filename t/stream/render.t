#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Stream;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe::Stream->new( @_ ); }

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

        my $arg = IPC::PrettyPipe::Stream->new( $args{new} );

        run_methods( $arg, @{ $args{methods} } );

        is_deeply( [ $arg->render( @{ $args{render} } ) ], $args{expect} );

    }
    $args{desc};

    return;
}



my @tests = (

    {
        desc => 'unquote',
        new    => { op => '>',
		    file => q(a'b"c),
		  },
        expect => [ [ '>', q(a'b"c) ] ],
    },

    {
        desc => 'quote',
        new    => { op => '>',
		    file => q(a'b"c),
		  },
        render => [ quote => 1 ],
        expect => [ [ '>', q('a'\''b"c') ] ],
    },

    {
        desc => 'sep',
        new    => { op => '>',
		    file => q(a'b"c),
		    sep => ' '
		  },
        expect => [ q(> a'b"c) ],
    },

    {
        desc => 'render sep',
        new    => { op => '>',
		    file => q(a'b"c),
		  },
        render => [ sep => ' ' ],
        expect => [ q(> a'b"c) ],
    },

    {
        desc => 'render override',
        new    => { op => '>',
		    file => q(a'b"c),
		    sep => 'xx',
		  },
        render => [ sep => ' ' ],
        expect => [ q(> a'b"c) ],
    },

    {
        desc => 'defsep n/a',
        new    => { op => '>',
		    file => q(a'b"c),
		    sep => 'xx',
		  },
        render => [ defsep => ' ' ],
        expect => [ q(>xxa'b"c) ],
    },

    {
        desc => 'defsep',
        new    => { op => '>',
		    file => q(a'b"c),
		  },
        render => [ defsep => ' ' ],
        expect => [ q(> a'b"c) ],
    },

    {
        desc => 'flatten',
        new    => { op => '>',
		    file => q(a'b"c),
		  },
        render => [ flatten => 1 ],
        expect => [ '>', q(a'b"c) ],
    },

);

run_test( %$_ ) for @tests;


done_testing;
