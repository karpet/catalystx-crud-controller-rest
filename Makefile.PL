use strict;
use warnings;

use inc::Module::Install;

# Define metadata
name 'CatalystX-CRUD-Controller-REST';
perl_version '5.008003';

all_from 'lib/CatalystX/CRUD/Controller/REST.pm';

requires 'Test::More'                            => 0;
requires 'CatalystX::CRUD'                       => 0.54;
requires 'Catalyst::Action::REST'                => 0;
requires 'Scalar::Util'                          => 0;
requires 'JSON::XS'                              => 2.23;

license 'perl';
homepage 'http://dev.catalyst.perl.org/repos/Catalyst/CatalystX-CRUD/CatalystX-CRUD-Controller-REST';
bugtracker 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=CatalystX-CRUD-Controller-REST';
repository 'http://dev.catalyst.perl.org/repos/Catalyst/CatalystX-CRUD/CatalystX-CRUD-Controller-REST';

WriteAll;
