#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 26;
use Test::Exception;

do {
    package Person;

    sub new {
        my $class = shift;
        my %args  = @_;

        bless \%args, $class;
    }

    sub name { $_[0]->{name} = $_[1] if @_ > 1; $_[0]->{name} }
    sub age { $_[0]->{age} = $_[1] if @_ > 1; $_[0]->{age} }

    sub make_string {
        my($self, $template) = @_;
        return sprintf $template, $self->name;
    }

    package Class;
    use Mouse;

    has person => (
        is        => 'rw',
        lazy      => 1,
        default   => sub { Person->new(age => 37, name => "Chuck") },
        predicate => 'has_person',
        handles   => {
            person_name => 'name',
            person_age  => 'age',
            person_hello => [make_string => 'Hello, %s'],
        },
    );

    has me => (
        is => 'rw',
        default => sub { Person->new(age => 21, name => "Shawn") },
        predicate => 'quid',
        handles => [qw/name age/],
    );
};

can_ok(Class => qw(person has_person person_name person_age name age quid));

my $object = Class->new;
ok(!$object->has_person, "don't have a person yet");
$object->person_name("Todd");
ok($object->has_person, "calling person_name instantiated person");
ok($object->person, "we really do have a person");

is($object->person_name, "Todd", "handles method");
is($object->person->name, "Todd", "traditional lookup");
is($object->person_age, 37, "handles method");
is($object->person->age, 37, "traditional lookup");
is($object->person_hello, 'Hello, Todd', 'curring');

my $object2 = Class->new(person => Person->new(name => "Philbert"));
ok($object2->has_person, "we have a person from the constructor");
is($object2->person_name, "Philbert", "handles method");
is($object2->person->name, "Philbert", "traditional lookup");
is($object2->person_age, undef, "no age because we didn't use the default");
is($object2->person->age, undef, "no age because we didn't use the default");
is($object2->person_hello, 'Hello, Philbert', 'currying');

ok($object->quid, "we have a Shawn");
is($object->name, "Shawn", "name handle");
is($object->age, 21, "age handle");
is($object->me->name, "Shawn", "me->name");
is($object->me->age, 21, "me->age");

is_deeply(
    $object->meta->get_attribute('me')->handles,
    [ 'name', 'age' ],
    "correct handles layout for 'me'",
);

is_deeply(
    $object->meta->get_attribute('person')->handles,
    { person_name => 'name', person_age => 'age', person_hello => [make_string => 'Hello, %s']},
    "correct handles layout for 'person'",
);


{
    throws_ok{
        $object->person(undef);
        $object->person_name();
    } qr/Cannot delegate person_name to name because the value of person is not defined/;

    throws_ok{
        $object->person([]);
        $object->person_age();
    } qr/Cannot delegate person_age to age because the value of person is not an object/;
}

eval{
    $object->person(undef);
    $object->person_name();
};
like $@, qr/Cannot delegate person_name to name because the value of person is not defined/;

eval{
    $object->person([]);
    $object->person_age();
};
like $@, qr/Cannot delegate person_age to age because the value of person is not an object/;


