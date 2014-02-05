use inc::Module::Install;

name 'IPC-PrettyPipe';

license 'gpl3';
author 'Diab Jerius';

repository 'http://bitbucket.org/djerius/ipc-prettypipe';
bugtracker 'https://rt.cpan.org/Public/Dist/Display.html?Name=IPC-PrettyPipe';

all_from 'lib/IPC/PrettyPipe.pm';

author_tests 'xt';
author_requires 'Test::NoBreakpoints';
author_requires 'Test::Pod';
author_requires 'Test::Pod::Coverage';
author_requires 'Test::Perl::Critic';

tests_recursive;

test_requires 'File::pushd';
test_requires 'Devel::FindPerl';
test_requires 'Test::Base';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
test_requires 'Test::File';
test_requires 'Test::Lib';
test_requires 'Test::More';
test_requires 'Test::Most';
test_requires 'Test::Trap';


requires 'IO::ReStoreFH';
requires 'IPC::Run';
requires 'List::Util' => 1.34;
requires 'Module::Load';
requires 'Module::Path';
requires 'Module::Runtime';
requires 'Moo' => '1.001000';
requires 'Type::Tiny' => 0.038;
requires 'MooX::Attributes::Shadow';
requires 'Safe::Isa';
requires 'Template::Tiny';
requires 'Term::ANSIColor';
requires 'Try::Tiny';
requires 'parent';

WriteAll;
