use inc::Module::Install;

name 'IPC-PrettyPipe';
all_from 'lib/IPC/PrettyPipe.pm';

test_requires 'Test::More';
requires 'IPC::Run';

WriteAll;
