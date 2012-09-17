use inc::Module::Install;

name 'IPC-PrettyPipe';
all_from 'lib/IPC/PrettyPipe.pm';

tests_recursive;

test_requires 'Test::More';
test_requires 'Test::Exception';

requires 'Moo';
requires 'MooX::Types::MooseLike::Base';
requires 'Safe::Isa';

requires 'String::ShellQuote';

WriteAll;
