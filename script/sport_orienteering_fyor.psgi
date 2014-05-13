use strictures 1;
use Plack::Builder;
use Sport::Orienteering::FYOR;

builder {
  mount '/' => Sport::Orienteering::FYOR->to_psgi_app;
};

