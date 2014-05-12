package Sport::Orienteering::FYOR;

use 5.006;
use strict;
use warnings;
use Web::Simple;


=head1 NAME

Sport::Orienteering::FYOR - Follow your own runner server

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

A prototype implementation of some ideas around following your own runner in orienteering competitions.

=cut


sub dispatch_request {
  sub (GET) {
    [ 200, [ 'Content-type', 'text/plain' ], [ 'Hello world!' ] ]
  },
  sub () {
    [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
  }
}

Sport::Orienteering::FYOR->run_if_script;


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Kjetil Kjernsmo.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Sport::Orienteering::FYOR
