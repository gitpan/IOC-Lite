# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 11;
# BEGIN { use_ok('IOC::Lite') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use IOC::Lite;

#========================================================
# A Mock test class, that inherits from Startable.
#========================================================
package Mock;

use base ("IOC::Lite::Startable");

sub new{
    my $class = shift;
    return bless([], $class);
}

sub say_hello{
    my $self = shift;
    return "Hello";
}

sub start{
    my $self = shift;
    print "Init called\n";
}

sub stop{
    my $self = shift;
    print "Destroy called\n";
}

#==================================================
# Kissalbe interface from 2-minute pico drill
#==================================================
package Kissable;

sub kiss($){
    die "abstract class cannot be imported!";
}

#=================================================
# Boy from pico 2-minute drill
#=================================================
package Boy;

use base ("Kissable");

sub new{
    my $class = shift;
    return bless [], $class;
}

sub kiss($){
    my ($self, $kissee) = @_;
    print "I was kissed by a " . ref( $kissee ) . "\n";
}

#=================================================
# Girl from pico 2-minute drill
#=================================================
package Girl;

use base ("IOC::Lite::Startable");

sub new{
    my($class, $kissable) = @_;
    
    unless ( $kissable->isa("Kissable")){
	die "$kissable is not Kissable!\n";
    }

    my $struct = { kissable => $kissable};
    return bless $struct, $class;
}

sub start{
    my $self = shift;
    $self->kiss();
}

sub kiss{
    my $self = shift;
    $self->{kissable}->kiss($self);
}

sub stop{
    my $self = shift;
}

package main;

# test a simple mock object
my $container = new IOC::Lite::Container();
ok($container->register("Mock", "new"), "Testing registering a mock object");
my $mock = $container->new_instance("Mock");
ok($mock->say_hello() eq "Hello", "Testing creating a basic mock object");

eval{
    $container->verify();
};
ok(! $@, "Testing verify on a one component container");

# test an invalid container
ok($container->unregister("Mock"), "Mock unregistered");
ok($container->register("Mock", "new", "AClassThatDoesntExist"), "Registering mock with invalid object (will work)");
eval{
   $container->verify();
};
isnt(! $@, "Container is invalid");


$container = new IOC::Lite::Container();
# pico two minute drill test
ok($container->register("Boy", "new"), "Created boy");
ok($container->register("Girl", "new",  "Boy"), "Created Girl with dependency on Boy");
my $girl = $container->new_instance("Girl");
ok($girl, "A Girl was created!");
ok($girl->kiss(), "A Girl kissed a boy");
$girl = undef;
$container = undef;

# Test the lifecycle
$container = new IOC::Lite::Container();
$container->register("Boy", "new");
$container->register("Girl","new", "Boy");
$container->start();

($girl) = $container->get_components("Girl");
ok($girl->isa("Girl"), "A girl started automatically!");