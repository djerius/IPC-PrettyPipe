#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Arg;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe::Arg->new( @_ ) } 

lives_ok { new( name => 'a' ) } 'simple constructor';

for my $name ( [ [], 'array' ],
              [ {}, 'hash' ],
              [ \'a', 'scalar ref' ] ) {

	dies_ok { new( name => $name->[0] ) } "bad name: $name->[1]"
}

# check convenience construction

lives_and {
	is( new( 'a' )->name, 'a' )
} 'just a name';

lives_and {
	my $arg = new( a => 3 );
    is( $arg->name, 'a' );
    is( $arg->value, 3 );

} 'name+value';

done_testing;
