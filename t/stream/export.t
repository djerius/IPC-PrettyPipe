#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Stream qw[ parse_op ];

use Test::More;
use Test::Exception;

lives_and {

	my $op = parse_op( '2>&3' );

    is( $op->{Op}, '>&' );
	is( !!$op->{param}, !!0 );

} 'N>&M';

lives_and {

	my $op = parse_op( '>' );

    is( $op->{Op}, '>' );
	is( $op->{param}, 1 );

} '>';

lives_and {

	my $op = parse_op( '>&' );

    is( $op->{Op}, '>&' );
	is( $op->{param}, 1 );

} '>&';


done_testing;
