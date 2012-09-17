#! perl

use strict;
use warnings;

use IPC::PrettyPipe;
use IPC::PrettyPipe::Cmd;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe->new( @_ ); }

lives_ok {

	new();
}
'new';

lives_ok {

     my %args = ( argpfx => 'a',
                  argsep => 'b',
                  cmdpfx => 'c',
                  cmdoptsep => 'd',
                  optsep => 'e',
                  optpfx => 'f',
                );

     my $p = new( \%args );

     is( $p->$_, $args{$_} ) for keys %args;
}
'new, hash';

lives_ok {

    is ( new( [ 'ls' ] )->cmds->[0]->cmd, 'ls' );
}
'new cmd';

lives_ok {

    is ( new( IPC::PrettyPipe::Cmd->new(  'ls' )  )->cmds->[0]->cmd, 'ls' );
}
'new IPC::PrettyPipe::Cmd';

lives_ok {

    my $pipe = new( [ 'ls' ],
		    ['make', [ '-f', 'Makefile' ], '-k' ]
		  );
    my $i = 0;

    is ( $pipe->cmds->[$i]->cmd, 'ls' );
    $i++;

    is ( $pipe->cmds->[$i]->cmd, 'make' );
    is ( $pipe->cmds->[$i]->args->[0]->name, '-f' );
    is ( $pipe->cmds->[$i]->args->[0]->value, 'Makefile' );
    is ( $pipe->cmds->[$i]->args->[1]->name, '-k' );

}
'add 2 cmds +args';


lives_ok {

    my $pipe = new();
    $pipe->add( 'make', [ '-f', 'Makefile' ], '-k' );

    is ( $pipe->cmds->[0]->cmd, 'make' );
    is ( $pipe->cmds->[0]->args->[0]->name, '-f' );
    is ( $pipe->cmds->[0]->args->[0]->value, 'Makefile' );
    is ( $pipe->cmds->[0]->args->[1]->name, '-k' );

    $pipe->add( 'ls', '-l' );
    is ( $pipe->cmds->[1]->cmd, 'ls' );
    is ( $pipe->cmds->[1]->args->[0]->name, '-l' );

}
'add cmd+args';

lives_ok {

    my $pipe = new();
    $pipe->add( IPC::PrettyPipe::Cmd->new( 'make', [ '-f', 'Makefile' ], '-k' ) );

    is ( $pipe->cmds->[0]->cmd, 'make' );
    is ( $pipe->cmds->[0]->args->[0]->name, '-f' );
    is ( $pipe->cmds->[0]->args->[0]->value, 'Makefile' );
    is ( $pipe->cmds->[0]->args->[1]->name, '-k' );

    $pipe->add( 'ls', '-l' );
    is ( $pipe->cmds->[1]->cmd, 'ls' );
    is ( $pipe->cmds->[1]->args->[0]->name, '-l' );

}
'add Cmd object';

done_testing;
