#!perl

use strict;
use warnings;

use IPC::PrettyPipe::DSL ':all';

use Test2::V0;

my @tests = (

    {
        label    => 'One command',
        input    => sub { ppipe ['cmd1'] },
        expected => << 'EOT'
  cmd1
EOT
    },

    {
        label    => 'One command w/ one arg',
        input    => sub { ppipe [ 'cmd1', 'a' ] },
        expected => << 'EOT'
  cmd1     \
    a
EOT
    },

    {
        label    => 'One command w/ one arg + value, no sep',
        input    => sub { ppipe [ 'cmd1', [ 'a', 3 ] ] },
        expected => << 'EOT'
  cmd1     \
    a 3
EOT
    },

    {
        label    => 'One command w/ one arg + blank value, no sep',
        input    => sub { ppipe [ 'cmd1', [ 'a', '' ] ] },
        expected => << 'EOT'
  cmd1      \
    a ''
EOT
    },

    {
        label    => 'One command w/ one arg + value, sep',
        input    => sub { ppipe [ 'cmd1', argsep '=', [ 'a', 3 ] ] },
        expected => << 'EOT'
  cmd1     \
    a=3
EOT
    },

    {
        label    => 'One command w/ one arg + value, pfx, no sep',
        input    => sub { ppipe [ 'cmd1', argpfx '-', [ 'a', 3 ] ] },
        expected => << 'EOT'
  cmd1      \
    -a 3
EOT
    },

    {
        label => 'One command w/ one arg + value, pfx, sep',
        input => sub {
            ppipe [
                'cmd1',
                argpfx '--',
                argsep '=',
                [ 'a', 3 ],
                [ 'b', 'is after a' ] ];
        },
        expected => << 'EOT'
  cmd1                  \
    --a=3               \
    --b='is after a'
EOT
    },

    {
        label    => 'One command w/ two args',
        input    => sub { ppipe [ 'cmd1', 'a', 'b' ] },
        expected => << 'EOT'
  cmd1     \
    a      \
    b
EOT
    },

    {
        label    => 'One command w/ one stream',
        input    => sub { ppipe [ 'cmd1', '>', 'file' ] },
        expected => << 'EOT'
  cmd1        \
    > file
EOT

    },

    {
        label    => 'One command w/ one stream, one arg',
        input    => sub { ppipe [ 'cmd1', '>', 'file', '-a' ] },
        expected => << 'EOT'
  cmd1        \
    -a        \
    > file
EOT
    },

    {
        label    => 'One command w/ two streams',
        input    => sub { ppipe [ 'cmd1', '>', 'stdout', '2>', 'stderr' ] },
        expected => << 'EOT'
  cmd1           \
    > stdout     \
    2> stderr
EOT
    },

    {
        label => 'One command w/ two streams, one arg',
        input => sub { ppipe [ 'cmd1', '>', 'stdout', '2>', 'stderr', '-a' ] },
        expected => << 'EOT'
  cmd1           \
    -a           \
    > stdout     \
    2> stderr
EOT
    },

    {
        label    => 'Two commands',
        input    => sub { ppipe ['cmd1'], ['cmd2'] },
        expected => << 'EOT'
  cmd1     \
| cmd2
EOT

    },

    {
        label    => 'Two commands w/ args',
        input    => sub { ppipe [ 'cmd1', '-a' ], [ 'cmd2', '-b' ] },
        expected => << 'EOT'
  cmd1     \
    -a     \
| cmd2     \
    -b
EOT

    },

    {
        label => 'Two commands w/ args and one stream apiece',
        input => sub {
            ppipe [ 'cmd1', '-a', '2>', 'stderr' ],
              [ 'cmd2', '-b', '>', 'stdout' ];
        },
        expected => << 'EOT'
  cmd1            \
    -a            \
    2> stderr     \
| cmd2            \
    -b            \
    > stdout
EOT
    },

    {
        label => 'Two commands w/ args and two streams apiece',
        input => sub {
            ppipe [ 'cmd1', '-a', '2>', 'stderr', '3>', 'out put' ],
              [ 'cmd2', '-b', '>', 0, '2>', 'std err' ];
        },
        expected => << 'EOT'
  cmd1               \
    -a               \
    2> stderr        \
    3> 'out put'     \
| cmd2               \
    -b               \
    > 0              \
    2> 'std err'
EOT
    },

    {
        label => 'Two commands + pipe streams',
        input => sub {
            ppipe ['cmd1'], ['cmd2'], '>', 'stdout';
        },
        expected => << 'EOT'
(             \
  cmd1        \
| cmd2        \
) > stdout
EOT
    },

    {
        label => 'Two commands w/ args and one stream apiece + pipe streams',
        input => sub {
            ppipe [ 'cmd 1', '-a', '2>', 'std err' ],
              [ 'cmd 2', '-b', '>', 'std out' ],
              '>', 0;
        },
        expected => << 'EOT'
(                    \
  'cmd 1'            \
    -a               \
    2> 'std err'     \
| 'cmd 2'            \
    -b               \
    > 'std out'      \
) > 0
EOT
    },

    {
        label => 'nested pipes, outer pipe streams, not merged',
        input => sub {
            IPC::PrettyPipe->new(
                cmds => [
                    [ 'cmd 1', '-a', '2>', 'std err' ],
                    ppipe [ 'cmd 2', '-b', '>', 'std out' ],
                ],
                streams     => [ ppstream '>', 0 ],
                merge_pipes => 0,
            );
        },
        expected => << 'EOT'
(                       \
  'cmd 1'               \
    -a                  \
    2> 'std err'        \
|     'cmd 2'           \
        -b              \
        > 'std out'     \
) > 0
EOT
    },

    {
        label => 'nested pipes, outer pipe streams, merged',
        input => sub {
            ppipe [ 'cmd 1', '-a', '2>', 'std err' ],
              ppipe( [ 'cmd 2', '-b', '>', 'std out' ] ),
              '>', 0;
        },
        expected => << 'EOT'
(                    \
  'cmd 1'            \
    -a               \
    2> 'std err'     \
| 'cmd 2'            \
    -b               \
    > 'std out'      \
) > 0
EOT

    },

    {
        label => 'nested pipes, inner pipe streams',
        input => sub {
            ppipe   [ 'cmd 1', '-a', '2>', 'std err' ],
              ppipe [ 'cmd 2', '-b', '>',  'std out' ],
              '>', 0;
        },

        expected => << 'EOT'
  'cmd 1'               \
    -a                  \
    2> 'std err'        \
| (                     \
    'cmd 2'             \
        -b              \
        > 'std out'     \
  ) > 0
EOT
    },
);

for my $test ( @tests ) {
    my $pipe = $test->{input}->();
    is( $pipe->render( colorize => 0 ), $test->{expected}, $test->{label} );
}

done_testing;
