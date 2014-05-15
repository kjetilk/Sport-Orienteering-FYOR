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
use RDF::Trine::Model::StatementFilter;

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

has model => (is => 'ro', isa => 'RDF::Trine::Model', builder => '_build_model');

sub _build_model {
	my $self = shift;
	my $store = RDF::Trine::Store->new( $self->config->{store} );
	return RDF::Trine::Model->new( $store );
}


sub dispatch_request {
  my ($self, $env) = @_;
  my $req = Plack::Request->new($env);
  my $uri = iri($req->uri);
  $self->{model} = $self->model;

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
			  return [ 400,
						  [ 'Content-Type', 'text/plain' ],
						  [ "Can't parse the request body: $@" ]
						];
		  }

		  return [ 204, [], []	];
	  }

  },

################
# Votes per user
  sub (/user/*/vote/*) {
	  sub (GET) {
		  return _just_bounded_description($self->{model}, $req);
	  },
	  sub (PUT) {
		  # TODO: Check it is the correct user
		  my $parser = _get_parser($req->content_type);
		  return $parser unless (blessed($parser) && ($parser->isa("RDF::Trine::Parser"))); # Then, we didn't get a parser, but an error
		  my $model = RDF::Trine::Model::StatementFilter->temporary_model;
		  $model->add_rule(sub { return ($_[0]->subject->equal($uri) ? 1 : 0) });
		  eval {
			  $parser->parse_into_model($self->config->{base_uri}, $req->content, $model);
		  }; if ($@) {
			  return [ 400,
						  [ 'Content-Type', 'text/plain' ],
						  [ "Can't parse the request body: $@" ]
						];
		  }
		  # Remove any previous votes
		  $self->{model}->remove_statements($uri, iri('http://purl.org/stuff/rev#rating'), undef, undef);
		  # Add the statements back to the persistent model
		  $self->{model}->begin_bulk_ops();
		  my $stream = $model->as_stream;
		  while (my $st = $stream->next) {
			  $self->{model}->add_statement($st);
		  }
		  $self->{model}->end_bulk_ops();

		  return [ 204, [], []	];
	  },
	  sub (DELETE) {
		  $self->{model}->remove_statements($uri, undef, undef, undef);
		  $self->{model}->remove_statements(undef, undef, $uri, undef);
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

sub _just_bounded_description {
	my ($model, $req) = @_;
	my $iterator = $model->bounded_description(iri($req->uri));
#	my ($ct, $serializer) = RDF::Trine::Serializer->negotiate($req->headers); # TODO: fix bug
	my $ct = 'text/turtle';
	my $serializer = RDF::Trine::Serializer::Turtle->new;
	my $output =  $serializer->serialize_iterator_to_string($iterator);
	return [ 200,
				[ 'Content-type', $ct ], 
				[ $output ]
			 ]
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
