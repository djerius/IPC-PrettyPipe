#! perl

use strict;
use warnings;

use IPC::PrettyPipe::Cmd;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe::Cmd->new( @_ ); }

lives_and {

	is( new( 'true' )->cmd, 'true');
}
'new: free form, no args';


lives_and {

	my $cmd = new( 'true', 'false' );

	is( $cmd->cmd, 'true');

	is( $cmd->args->[0]->name, 'false' );

}
'new: free form, args';


lives_and {

	is( new( { cmd => 'true' } )->cmd, 'true');
}
'new: hash, no args';


lives_and {

	my $cmd = new( { cmd => 'true', args => 'false' } );

	is( $cmd->cmd, 'true');

	is( $cmd->args->[0]->name, 'false' );

}
'new: hash, args';

lives_and {

	my $cmd = new( { cmd => 'true',
	                 args => [ [ arg1 => 'false' ] ],
	                 argpfx  => '--',
	               } );

	is( $cmd->cmd, 'true');

	is( $cmd->argpfx, '--' );

	is( $cmd->args->[0]->name, 'arg1' );
	is( $cmd->args->[0]->pfx, '--' );
	is( $cmd->args->[0]->sep, undef );
}
'new: hash, args, pfx';

lives_and {

	my $cmd = new( { cmd => 'true',
	                 args => [ [ arg1 => 'false' ] ],
	                 argpfx  => '--',
	                 argsep  => '='
	               } );

	is( $cmd->cmd, 'true');
	is( $cmd->argpfx, '--' );
	is( $cmd->argsep, '=' );

	is( $cmd->args->[0]->name, 'arg1' );
	is( $cmd->args->[0]->pfx, '--' );
	is( $cmd->args->[0]->sep, '=' );


}
'new: hash, args, pfx, sep';

### existing IPC::PrettyPipe::Arg

lives_and {

	my $cmd = new( foo => IPC::PrettyPipe::Arg->new( '-f', 'Makefile' ) );
	is ( $cmd->args->[0]->name, '-f' );
	is ( $cmd->args->[0]->value, 'Makefile' );
} 'new, existing Arg object';

lives_and {

	my $cmd = new( 'foo' );
	$cmd->add( [ '-f', IPC::PrettyPipe::Arg->new( '-l' ) ], boolarr => 1 );
	is ( $cmd->args->[0]->name, '-f' );
	is ( $cmd->args->[1]->name, '-l' );
} 'new, existing Arg object, boolarr';

lives_and {

	my $cmd = new( 'foo' );
	$cmd->add( [ -f => 'Makefile',
	             IPC::PrettyPipe::Arg->new( '-l' )
	           ]
	         );
	is ( $cmd->args->[0]->name, '-f' );
	is ( $cmd->args->[1]->name, '-l' );
} 'new, existing Arg object in array';



###
lives_and {

	my $cmd = new( { cmd => 'true',
	                 args => [ [ arg1 => 'false' ] ],
	                 argpfx  => '--',
	                 argsep  => '='
	               } );

	$cmd->add( [ f => 3, b => 9 ], pfx => '-', sep => ' ' );

	is( $cmd->args->[1]->name, 'f' );
	is( $cmd->args->[1]->value, '3' );
	is( $cmd->args->[1]->pfx, '-' );
	is( $cmd->args->[1]->sep, ' ' );


	is( $cmd->args->[2]->name, 'b' );
	is( $cmd->args->[2]->value, '9' );
	is( $cmd->args->[1]->pfx, '-' );
	is( $cmd->args->[1]->sep, ' ' );

}
'add, alternate pfx & sep';

### flush out corner cases
throws_ok {
	my $cmd = new( 'ls' );

	$cmd->add( 'l', boolarr => 1 );
} qr/expected arrayref/, 'boolarr: not an array' ;

throws_ok {
	my $cmd = new( 'ls' );

	$cmd->add( sub {} );
} qr/unexpected argument/, 'add: bad argument' ;

throws_ok {
	my $cmd = new( 'ls' );

	$cmd->add( [ 'l' ] );
} qr/not enough elements/, 'add array: not enough elements' ;

throws_ok {
	my $cmd = new( 'ls' );

	$cmd->add( [ {} ], boolarr => 1 );
} qr/unexpected argument/, 'boolarr: not scalar' ;

lives_ok {
	my $cmd = new( 'ls' );

	$cmd->add( 'l', { boolarr => 0 } );
} 'hash attr to add';

done_testing;
