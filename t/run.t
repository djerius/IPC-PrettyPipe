

use strict;
use warnings;

use Test::More tests => 3;

BEGIN {
  use_ok('IPC::PrettyPipe');
}

eval {
    my $stdout;
    my $stderr;
    my $pipe = IPC::PrettyPipe->new;

    $pipe->add( $^X, -le => 'for (0..10) { print $_;  print STDERR "cmd1: $_"; }' );
    $pipe->add( $^X, -nle => '$_ = 10 - $_; print $_ ; print STDERR "cmd2: $_"' );
    $pipe->stdout( \$stdout );
    $pipe->stderr( \$stderr );
    $pipe->run;

    is ( $stdout,  join("\n", reverse 0..10 ) . "\n", "simple pipe with stashed stdout" );

    # this assumes that STDERR isn't flushed and that the lines are combined in a sane order.
    is ( $stderr,  join("\n", (map { "cmd1: $_" } 0..10 ), ( map { "cmd2: $_" } reverse 0..10 ) ) . "\n",
	"simple pipe with stashed stderr" );

}
