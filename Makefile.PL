use inc::Module::Install;

name 'IPC-PipeC';
all_from 'lib/IPC/PipeC.pm';

test_requires 'Test::More';
requires 'IPC::Run';

WriteAll;
