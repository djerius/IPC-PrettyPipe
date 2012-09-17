#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Stream;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe::Stream->new( @_ ) } 


lives_and {

    is( new( '>' )->op, '>' )

} 'just an op';

lives_and {

    my $arg = new( '>' => 'output' );

    is( $arg->op, '>' );

    is( $arg->file, 'output' );

} 'op+file';

throws_ok {

    new( '>>>' );

} qr/cannot parse/, "bad operator";

done_testing;
