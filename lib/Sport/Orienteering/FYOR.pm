package Sport::Orienteering::FYOR;

use 5.006;
use strict;
use warnings;
use Web::Simple;
use Web::Dispatch::HTTPMethods;
use FindBin;
use RDF::Trine qw(iri);

=head1 NAME

Sport::Orienteering::FYOR - Follow your own runner server

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

A prototype implementation of some ideas around following your own runner in orienteering competitions.

=cut


sub default_config {
	my $base_dir = '/home/kjetil/dev/Sport-Orienteering-FYOR'; #$FindBin::Bin;
	store => {
				 storetype => 'DBI',
				 dsn       => "dbi:SQLite:dbname=$base_dir/fyor.db",
				 username  => '',
				 password  => ''
				},
	base_dir => $base_dir,
	base_uri => 'http://localhost:5000/'
}

#has model => (is => 'ro', isa => 'RDF::Trine::Model', builder => '_build_model');

sub BUILD {
	my $self = shift;
	my $store = RDF::Trine::Store->new( $self->config->{store} );
	$self->{model} = RDF::Trine::Model->new( $store );
}


sub dispatch_request {
  my $self = shift;
  sub (/cam/*) {
	  sub (GET) {
		  my $iterator = $self->{model}->get_statements(undef, undef, undef, iri('http://localhost:5000/cam/1'));
		  my $serializer = RDF::Trine::Serializer::Turtle->new();
		  my $output =  $serializer->serialize_iterator_to_string($iterator);
		  warn $output;

		  return [ 200, 
					  [ 'Content-type', 'text/turtle' ], 
					  [ $output ]
#					  [ $serializer->serialize_iterator_to_string($iterator) ]
					]
	  }
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
