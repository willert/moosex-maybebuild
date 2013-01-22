package MooseX::MaybeBuild;

use Class::Throwable qw/ MooseX::MaybeBuild::Attribute::NoValue /;

package MooseX::MaybeBuild::Attribute;
use Moose::Role 0.90;
use Try::Tiny;

sub _maybe_initialize_slot {
  my ( $self, $instance ) = @_;

  my ( $value, $dont_set_value );
  try {
    $value = $self->_call_builder($instance)
  } catch {
    die $_ unless blessed $_ and
      $_->isa('MooseX::MaybeBuild::Attribute::NoValue');
    $dont_set_value = 1;
  };

  unless ( $dont_set_value ) {
    $value = $self->_coerce_and_verify( $value, $instance );
    $self->set_initial_value($instance, $value);
    if ( ref $value && $self->is_weak_ref ) {
      $self->_weaken_value($instance);
    }
    return 1;
  }

  return;
}

after install_accessors => sub {
  my ( $self, $inline ) = @_;
  my $metaclass = $self->associated_class;

  if ( $self->has_predicate ) {
    $metaclass->add_before_method_modifier( $self->predicate, sub {
      my $instance = shift;
      return if $self->has_value( $instance );
      $self->_maybe_initialize_slot( $instance );
    });
  }

  if ( $self->has_reader || $self->has_accessor ) {
    my $reader = $self->has_reader ? $self->reader : $self->accessor;
    $metaclass->add_around_method_modifier( $reader, sub {
      my $orig = shift;
      my $instance = shift;

      return $instance->$orig( @_ ) if @_;
      return $instance->$orig if $self->has_value( $instance );

      if ( not $self->_maybe_initialize_slot( $instance )) {
        $self->throw_error( join(
          q{}, blessed( $instance ),
          " has no value for attribute '", $self->name, "'",
        ), object => $instance );
      }
      $instance->$orig
    });
  }

};


sub _call_builder {
  my ( $self, $instance ) = @_;

  $self->throw_error( join(
    q{}, blessed( $instance ),
    " does not support builder method '", $self->builder,
    "' for attribute '", $self->name, "'",
  ), object => $instance ) unless $instance->can( $self->builder );

  my $builder = $self->builder();
  my @value = $instance->$builder();

  MooseX::MaybeBuild::Attribute::NoValue->throw unless @value;

  $self->throw_error( join(
    q{},
    "Builder method '", $self->builder, "' of ",
    blessed( $instance ),
    " should return either an empty list or exactly one value",
    " for attribute '", $self->name, "'",
  ), object => $instance ) unless @value == 1;

  return $value[0];
}

around initialize_instance_slot => sub {
  my ( $orig, $self, @args ) = @_;
  try {
    $self->$orig( @args );
  } catch {
    die $_ unless blessed $_ and
      $_->isa('MooseX::MaybeBuild::Attribute::NoValue');
  };
};

around get_value => sub {
  my ( $orig, $self, @args ) = @_;
  try {
    $self->$orig( @args );
  } catch {
    die $_ unless blessed $_ and
      $_->isa('MooseX::MaybeBuild::Attribute::NoValue');
  };
};

around _inline_init_from_default => sub {
  my $orig = shift;
  my ( $self, $instance, $default, $tc, $coercion, $message, $for_lazy ) = @_;

  my @code = $self->$orig(
    $instance, $default, $tc, $coercion, $message, $for_lazy
  );

  #  printf STDERR "Inlining IFD as:\n  %s\n", join( "\n  ", @code );

  return @code;
};



use Moose::Role 0.90;

package Moose::Meta::Attribute::Custom::Trait::MaybeBuild;

sub register_implementation { 'MooseX::MaybeBuild::Attribute' }

1;
