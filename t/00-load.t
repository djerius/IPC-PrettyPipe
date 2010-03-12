#!perl -T

use Test::More tests => 1;

BEGIN {
  use_ok('IPC::PipeC');
}

diag( "Testing IPC::PipeC $IPC::PipeC::VERSION, Perl $], $^X" );
