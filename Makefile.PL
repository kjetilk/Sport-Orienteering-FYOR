use inc::Module::Install;

name     'Sport-Orienteering-FYOR';
all_from 'lib/Sport/Orienteering/FYOR.pm';
author   q{Kjetil Kjernsmo <kjetilk@cpan.org>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

