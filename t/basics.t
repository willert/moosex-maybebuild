#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Test::More;
use Find::Lib qw/lib/;

use Moose 1.99;
use MooseX::MaybeBuild;

use Test::Moose;
use Test::Fatal;

my $maybe = Moose::Meta::Class->create_anon_class(
  superclasses => [qw/ Moose::Meta::Attribute /],
  roles        => [qw/ MooseX::MaybeBuild::Attribute /],
  cache        => 1,
);

# Class::MOP::Attribute
my ( $eager_class, $lazy_class )  = map{
  Moose::Meta::Class->create_anon_class(
    methods    => { _build_foo => sub{
      # printf STDERR "Building foo\n", ;
      return 'foo';
    }, _build_bar => sub{
      # printf STDERR "Building bar\n", ;
      return;
    }},
    attributes => [
      $maybe->name->new( foo => (
        is => 'rw', isa => 'Str',
        builder   => '_build_foo',
        predicate => 'has_foo',
        %$_
      )),
      $maybe->name->new( bar => (
        is => 'rw', isa => 'Str',
        builder   => '_build_bar',
        predicate => 'has_bar',
        %$_
      )),
    ],
  );
} ( {}, { lazy => 1 } );

pass 'Class creation';

with_immutable {

  isa_ok my $eager_obj = eval{ $eager_class->new_object }, $eager_class->name;

  is exception { $eager_obj->has_foo, $eager_obj->foo }, undef,
    'Accessing eager attr foo while ' .
      ( $eager_obj->meta->is_mutable ? 'mutable' : 'immutable' );

  is exception { $eager_obj->has_bar && $eager_obj->bar }, undef,
    'Accessing eager attr bar while ' .
      ( $eager_obj->meta->is_mutable ? 'mutable' : 'immutable' );

  ok( $eager_obj->has_foo,    "Eager foo has been set" );
  is( $eager_obj->foo, 'foo', "Eager foo has correct value" );
  ok( ! $eager_obj->has_bar,  "Eager bar hasn't been set" );

  isa_ok my $lazy_obj  = eval{ $lazy_class->new_object  }, $lazy_class->name;

  is exception { $lazy_obj->has_foo && $lazy_obj->foo }, undef,
    'Accessing lazy attr foo while ' .
      ( $lazy_obj->meta->is_mutable ? 'mutable' : 'immutable' );

  is exception { $lazy_obj->has_bar && $lazy_obj->bar }, undef,
    'Accessing lazy attr bar while ' .
      ( $lazy_obj->meta->is_mutable ? 'mutable' : 'immutable' );

  ok( $lazy_obj->has_foo,    "Lazy foo has been set" );
  is( $lazy_obj->foo, 'foo', "Lazy foo has correct value" );
  ok( ! $lazy_obj->has_bar,  "Lazy bar hasn't been set" );

  like(
    exception { $lazy_obj->bar; },
    qr/ no \s? value /xi,
    'Reading empty value dies'
  );

} map{ $_->name } $eager_class, $lazy_class;

done_testing;
