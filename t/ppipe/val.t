#! perl

use strict;
use warnings;

use IPC::PrettyPipe;

use Test::More;
use Test::Exception;

sub new { IPC::PrettyPipe->new( @_ ); }


lives_and {
    is( new( [ 'ls', [ '-a', '%OUTPUT%' ] ] )
        ->valmatch( qr/%OUTPUT%/ ),
        1
      );
}
'valmatch: value, matched';

lives_and {
    is( new( [ 'ls', [ '-a', '%INPUT%' ] ] )
        ->valmatch( qr/%OUTPUT%/ ),
        0
      );
}
'valmatch: value, not matched';


lives_and {
    is( new( [ 'ls', '-l' ] )->valmatch( qr/%INPUT%/ ),
        0
      );
}
'valmatch: no value';

lives_and {
    is(
        new( [ 'ls', [ '-a', '%OUTPUT%' ],
                     [ '-b', '%OUTPUT%' ] ] )
          ->valmatch( qr/%OUTPUT%/ ),
        1
    );
}
'valmatch: match (1 cmd; 2 args)';

lives_and {

    my $pipe = new( [ 'ls', [ '-a', '%OUTPUT%' ] ] );
    $pipe->valsubst( qr/%OUTPUT%/, 'foo', );

    is( $pipe->cmds->[0]->args->[0]->value, 'foo' );
}
'valsubst: match ( 1 cmd; 1 arg )';

lives_and {

    my $pipe
      = new( [ 'a', [ '-a', '%OUTPUT%' ],
                    [ '-b', '%OUTPUT%' ]
             ]
           );
    $pipe->valsubst( qr/%OUTPUT%/, 'foo' );

    is( $pipe->cmds->[0]->args->[0]->value, 'foo' );
    is( $pipe->cmds->[0]->args->[1]->value, 'foo' );
}
'valsubst: match, 1 cmd, 2 args';


lives_and {

    my $pipe
      = new( [ 'a', [ '-a', '%OUTPUT%' ], [ '-b', '%OUTPUT%' ] ],
             [ 'b', [ '-a', '%OUTPUT%' ], [ '-b', '%OUTPUT%' ] ]
           );
    $pipe->valsubst( qr/%OUTPUT%/, 'foo' );

    is( $pipe->cmds->[0]->args->[0]->value, 'foo' );
    is( $pipe->cmds->[0]->args->[1]->value, 'foo' );

    is( $pipe->cmds->[1]->args->[0]->value, 'foo' );
    is( $pipe->cmds->[1]->args->[1]->value, 'foo' );
}
'valsubst: match, 2 cmds, 2 args';

lives_and {

    my $pipe
      = new( [ 'a', [ '-a', '%OUTPUT%' ] ],
             [ 'b', [ '-b', '%OUTPUT%' ] ]
           );
    $pipe->valsubst( qr/%OUTPUT%/, 'foo', lastvalue => 'last' );

    is( $pipe->cmds->[0]->args->[0]->value, 'foo' );
    is( $pipe->cmds->[1]->args->[0]->value, 'last' );
}
'valsubst: match, lastvalue, 2cmds, 1 arg';

lives_and {

    my $pipe = new( [ 'ls', [ '-a', '%OUTPUT%' ], [ '-b', '%INPUT%' ] ] );
    $pipe->valsubst( qr/%OUTPUT%/, 'foo', lastvalue => 'last' );

    is( $pipe->cmds->[0]->args->[0]->value, 'last' );
    is( $pipe->cmds->[0]->args->[1]->value, '%INPUT%' );
}
'valsubst: match, lastvalue, 1 cmd, 2 args, 1 match';

lives_and {

    my $pipe = new( [ 'ls', [ '-a', '%OUTPUT%' ], [ '-b', '%INPUT%' ] ] );
    $pipe->valsubst( qr/%OUTPUT%/, 'foo', { lastvalue => 'last' }, );

    is( $pipe->cmds->[0]->args->[0]->value, 'last' );
    is( $pipe->cmds->[0]->args->[1]->value, '%INPUT%' );
}
'valsubst: match, lastvalue in hash';

lives_and {

    my $pipe = new( [ 'ls', [ '-a', '%OUTPUT%' ], [ '-b', '%INPUT%' ] ] );

    is( $pipe->valsubst( qr/%OUTPUT%/, 'foo', firstvalue => 'first', ), 1 );

    is( $pipe->cmds->[0]->args->[0]->value, 'first' );
    is( $pipe->cmds->[0]->args->[1]->value, '%INPUT%' );

}
'valsubst: match, firstvalue, nmatch = 1';

lives_and {

    my $pipe
      = new( [ 'a', [ '-a', '%OUTPUT%' ] ],
             [ 'b', [ '-b', '%OUTPUT%' ] ] );

    is( $pipe->valsubst( qr/%OUTPUT%/, 'foo', firstvalue => 'first', ),
        2
      );

    is( $pipe->cmds->[0]->args->[0]->value, 'first' );
    is( $pipe->cmds->[1]->args->[0]->value, 'foo' );

}
'valsubst: match, firstvalue';


lives_and {

    my $pipe = new(
        [ 'a', [ '-a', '%OUTPUT%' ], [ '-b', '%OUTPUT%' ] ],
        [ 'b', [ '-a', '%OUTPUT%' ], [ '-b', '%OUTPUT%' ] ],
    );
    $pipe->valsubst(
        qr/%OUTPUT%/, 'foo',
        firstvalue => 'first',
        lastvalue  => 'last'
    );
    is( $pipe->cmds->[0]->args->[0]->value, 'first' );
    is( $pipe->cmds->[0]->args->[1]->value, 'first' );

    is( $pipe->cmds->[1]->args->[0]->value, 'last' );
    is( $pipe->cmds->[1]->args->[1]->value, 'last' );

}
'valsubst: match, firstvalue, lastvalue, 2 cmds';

lives_and {

    my $pipe = new(
        [ 'a', [ '-a', '%OUTPUT%' ], [ '-b', '%OUTPUT%' ] ],
        [ 'b', [ '-a', '%OUTPUT%' ], [ '-b', '%OUTPUT%' ] ],
        [ 'c', [ '-a', '%OUTPUT%' ], [ '-b', '%OUTPUT%' ] ],
    );
    $pipe->valsubst(
        qr/%OUTPUT%/, 'middle',
        firstvalue => 'first',
        lastvalue  => 'last'
    );
    is( $pipe->cmds->[0]->args->[0]->value, 'first' );
    is( $pipe->cmds->[0]->args->[1]->value, 'first' );

    is( $pipe->cmds->[1]->args->[0]->value, 'middle' );
    is( $pipe->cmds->[1]->args->[1]->value, 'middle' );

    is( $pipe->cmds->[2]->args->[0]->value, 'last' );
    is( $pipe->cmds->[2]->args->[1]->value, 'last' );

}
'valsubst: match, firstvalue, lastvalue, 3 cmds';



done_testing;
