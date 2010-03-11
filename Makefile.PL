use inc::Module::Install;

name 'IPC-PipeC';
all_from 'lib/IPC/PipeC.pm';

requires 'IPC::Exe';

WriteAll;
