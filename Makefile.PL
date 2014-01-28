use inc::Module::Install;

name 'IPC-PrettyPipe';
all_from 'lib/IPC/PrettyPipe.pm';

author_tests 'xt';
author_requires 'Test::NoBreakpoints';
author_requires 'Test::Pod';
author_requires 'Test::Pod::Coverage';
author_requires 'Test::Perl::Critic';

tests_recursive;

test_requires 'File::pushd';
test_requires 'Probe::Perl';
test_requires 'Test::Base';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
test_requires 'Test::File';
test_requires 'Test::Lib';
test_requires 'Test::More';
test_requires 'Test::Most';


requires 'IO::ReStoreFH';
requires 'IPC::Run';
requires 'Module::Load';
requires 'Module::Path';
requires 'Module::Runtime';
requires 'Moo' => '1.001000';
requires 'MooX::Types::MooseLike' => 0.11;
requires 'MooX::Attributes::Shadow';
requires 'Params::Check';
requires 'Safe::Isa';
requires 'Template::Tiny';
requires 'Term::ANSIColor';
requires 'Try::Tiny';
requires 'parent';

WriteAll;
