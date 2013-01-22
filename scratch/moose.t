#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Test::More;
use Find::Lib qw/lib/;

use Moose 1.99;
use MooseX::MaybeBuild;

use Test::Moose;
use Test::Exception;

my $maybe = Moose::Meta::Class->create_anon_class(
  superclasses => [qw/ Moose::Meta::Attribute /],
  roles        => [qw/ MooseX::MaybeBuild::Attribute /],
  cache        => 1,
);

# Class::MOP::Attribute
my ( $eager_class, $lazy_class )  = map{
  Moose::Meta::Class->create_anon_class(
    methods    => { _build_foo => sub{ return 'bar' } },
    attributes => [
      $maybe->name->new( foo => (
        is => 'rw', isa => 'Str',
        builder => '_build_foo',
        predicate => 'barbar',
        %$_
      )),
    ],
  );
} ( {}, { lazy => 1 } );

pass 'Class creation';

with_immutable {

  isa_ok my $eager_obj = eval{ $eager_class->new_object }, $eager_class->name;
  lives_ok { $eager_obj->foo } 'Accessing eager attr';

  isa_ok my $lazy_obj  = eval{ $lazy_class->new_object  }, $lazy_class->name;
  lives_ok { $lazy_obj->foo }  'Accessing lazy attr';
}, map{ $_->name } $eager_class, $lazy_class;

done_testing;
