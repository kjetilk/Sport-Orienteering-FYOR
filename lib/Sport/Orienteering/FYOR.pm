package Sport::Orienteering::FYOR;

use 5.006;
use strict;
use warnings;
use Web::Simple;
use Web::Dispatch::HTTPMethods;
use FindBin;
use RDF::Trine qw(iri statement variable);
use Plack::Request;
use Scalar::Util qw(blessed);
#use Error qw(:try);

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
  my ($self, $env) = @_;
  my $req = Plack::Request->new($env);
  my $uri = iri($req->uri);

##############
# First we look implement the cameras
  sub (/cam/) {
	  sub (GET) {


		  ## The following is equivalent to taking the WHERE-clause to a SPARQL CONSTRUCT query as:
		  # {
		  #   ?stream a dctype:MovingImage ;
		  #           ?sp ?so ;
		  #   OPTIONAL { ?so rev:hasReview ?vote .
		  #              ?vote ?vp ?vo . }
		  # }

		  my $streamsmodel = RDF::Trine::Model->temporary_model;
		  my @allstreams = $self->{model}->subjects(iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
																  iri('http://purl.org/dc/dcmitype/MovingImage'),
																  undef);
		  $streamsmodel->begin_bulk_ops();
		  foreach my $subject (@allstreams) {
			  my $streamsit = $self->{model}->get_statements($subject, undef, undef, undef);
			  while (my $sst = $streamsit->next) {
				  $streamsmodel->add_statement( $sst );
				  if($sst->predicate->equal(iri('http://purl.org/stuff/rev#hasReview'))) {
					  my $votesit = $self->{model}->get_statements($sst->object, undef, undef, undef);
					  while (my $vst = $votesit->next) {
						  $streamsmodel->add_statement( $vst );
					  }
				  }
			  }
		  }
		  $streamsmodel->end_bulk_ops();
		  my ($ct, $serializer) = RDF::Trine::Serializer->negotiate($req->headers);
		  my $output =  $serializer->serialize_model_to_string($streamsmodel);
		  return [ 200, 
					  [ 'Content-type', $ct ], 
					  [ $output ]
					]
	  }
	},
	sub (/cam/*) {
	  sub (GET) {
		  my $iterator = $self->{model}->get_statements(undef, undef, undef, $uri);
		  my ($ct, $serializer) = RDF::Trine::Serializer->negotiate($req->headers);
		  my $output =  $serializer->serialize_iterator_to_string($iterator);
		  return [ 200, 
					  [ 'Content-type', $ct ], 
					  [ $output ]
					]
	  },
	  sub (PUT) {
		  my $parser = _get_parser($req->content_type);
		  return $parser unless (blessed($parser) && ($parser->isa("RDF::Trine::Parser"))); # Then, we didn't get a parser, but an error
		  eval {
			  $parser->parse_into_model($self->config->{base_uri}, $req->content, $self->{model}, context => $uri);
		  }; if ($@) {
			  warn $@;
		   	  return [ 400,
		   			[ 'Content-Type', 'text/plain' ],
		   			[ "Can't parse the request body: $@" ]
		   		 ];
		  }

		  return [ 204, [], []	];
	  }

  }
}

sub _get_parser {
	my ($ct) = split(';', shift);
	chomp($ct);
	my $parser = RDF::Trine::Parser->parser_by_media_type($ct);
	if ($parser) {
		return $parser->new;
	} else {
		return [ 415, 
					[ 'Content-Type', 'text/plain' ],
					[ "Can't parse $ct" ]
				 ];
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
