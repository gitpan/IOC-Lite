package IOC::Lite;

use 5.008001;
use strict;
use warnings;
our $VERSION = 0.01;

#====================================================
# Startable "interface" adopted from the Pico project.
# It is an interface for basic object lifecyle management
#===================================================
package IOC::Lite::Startable;

sub new  { return bless [], shift;         }
sub start{ die "This is abstract\n"; }
sub stop { die "This is abstract\n"; }

#===================================================
# Dispose "interface" adopted from the Pico project.
# This is not used as of yet, it's role is still in
# ideation.  I see a need for something like this 
# if the ejb model of creation and destruction is
# used (you know objects never really die, they 
# just change state)
#==================================================
package IOC::Lite::Dispose;

sub dispose{ die "This is abstract\n"; }

#===================================================
# This apapter is adopted from the Pico project although
# I've turned it into more of a proxy here.  The name will
# likely change as I come to understand it better.  It does
# help manage the lifecycle events and even keeps track
# of the owning container.
#==================================================
package IOC::Lite::Adaptor;

use base ("IOC::Lite::Startable");

our $AUTOLOAD;

sub new {
    my ($class, $obj, $container) = @_;
    return bless { object => $obj, container => $container}, $class;
}

sub start{
    my $self = shift;
    if ($self->{object}->isa("IOC::Lite::Startable")){
	$self->{object}->start();
    }
}

sub stop{
    my $self = shift;
    if ($self->{object}->isa("IOC::Lite::Startable")){
	$self->{object}->stop();
    }
}

sub get_type{
    my $self = shift;
    return ref($self->{object})
}

sub isa{
    my ($self, $class) = @_;
    return $self->{object}->isa($class);
}

sub AUTOLOAD{
    my($self, @args) = @_;
    my @method_and_structure  = split m|\:\:|, $AUTOLOAD;
    my $method = $method_and_structure[@method_and_structure-1];
    if ($self->{object}->can($method)){
	return $self->{object}->$method(@args);
    }
    die ">$method is not found on " . $self->get_type() . "\n";
}

sub DESTROY{
    my $self = shift;
    $self->stop();
}

#==============================================
# This is the main container (manager) class for
# IOC::Lite.  It has a life cycle and manages 
# dependancies and performs injections. It adopts
# Pico's interface for the most part (or
# important parts..:).
#==============================================
package IOC::Lite::Container;

use base ("IOC::Lite::Startable");

sub new{
    my $class = shift;
    my $struct = 
    {
	classes => {},
	class_creation => {},
	objects => [],
    };
    return bless($struct, $class);
}

sub register{
    my ($self, $class_name, $creation , @params) = @_;

    die "No class name given\n" unless $class_name;
    die "No creation method given\n" unless $class_name->can($creation);

    $self->{classes}->{$class_name} = @params == 0 ? [] : \@params;
    $self->{class_creation}->{$class_name} = $creation;
}

sub unregister{
    my ($self, $class_name) = @_;
    if (defined($self->{classes}->{$class_name})){
	delete $self->{classes}->{$class_name};
	delete $self->{class_creation}->{$class_name};
    }
    else{
	warn "Class <$class_name> not defined\n";
    }
}

# verifies the dependancies of registered classes
sub verify{
    my ($self) = @_;
    
    # grab each registered class
    foreach my $class (keys %{ $self->{classes} } ){
	
	my @dependencies = @{ $self->{classes}->{$class} };
	my $to_find = @dependencies;
	my $found = 0;

	# grab each array ref
	foreach my $depend ( @dependencies){
	    

	    # look at every reference in classes
	    foreach my $lookup ( keys %{ $self->{classes} }){
		if ($lookup eq $depend){
		    $found++;
		    last;
		}
	    }
      	}
	
	# determine if all dependencies were met
	unless ($found == $to_find){
	    die "Could not find all dependencies for $class\n";
	}
    }
}


# Creates a new instance, including the creation of all
# dependencies.  It also stores a reference to the object
# to manage it.  Probably not need in all cases.
sub new_instance{
    my ($self, $class_name) = @_;
    my ($params, $argument_string);

    # look for registered class
    unless(defined($self->{classes}->{$class_name})){
	die "Unknown class: $class_name\nClass not registered";
    }

    # get constructor injection data
    $params = $self->{classes}->{$class_name};

    my $first = 1;
    $argument_string = "";
    foreach my $class (@{$params}){
	$argument_string .= ", " unless $first;
	$argument_string = "\$self->new_instance(\"$class\")";
	$first = 0;
    }

    # perform massively unsafe eval...
    # probably should the symbol table in some future
    # iteration...but for now, behold the power of eval.
    my $creation_name = $self->{class_creation}->{$class_name};
    print ">>>$creation_name\n";
    my $obj = new IOC::Lite::Adaptor ( eval("$class_name->$creation_name($argument_string)")) ;

    if($@){
	die "EVAL FAILED:\n $@";
    }
   
    $obj->start();
    
    # store a reference for stop later
    push @{$self->{objects}}, $obj;

    return $obj;
}

sub start{ 
    my $self = shift; 
    
    foreach my $class (keys %{	$self->{classes}}){
	my $isa = eval {$class->isa("IOC::Lite::Startable")};
	if ($isa){
	    $self->new_instance($class);
	}
    }
}

sub stop{
    my $self = shift;
    foreach my $obj (@$self->{objects}){
	$obj->stop();
    }
}

sub get_components{
    my ($self, $type) = @_;
    my @ret;
    if ($type){
	foreach my $obj (@{ $self->{objects}  }){
	    if($obj->get_type() eq $type){
		push @ret, $obj;
	    }
	}
	return @ret;
    }
    return @{$self->{objects}};
}

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

IOC::Lite - Perl extension for Inversion of Control

=head1 SYNOPSIS

# see the 1.t tests for a more complete (and working) example.

use IOC::Lite;
  
# A simple example which demonstrates the simple use as a
# overweight factory.
my $container = new IOC::Lite::Container();
$container->register("Mock", "new");
my $mock = $container->new_instance("Mock");
$mock->say_hello();

$container->verify();

# A more complex example which demonstrates the dependency injection of
# Girls required Kissable class.  This example is taken from the Two Minute
# introduction of Picocontainer.
$container = new IOC::Lite::Container();
$container->register("Boy", "new");
$container->register("Girl", "new",  "Boy");
my $girl = $container->new_instance("Girl");
$girl->kiss();

# The same example which now uses the containers lifecycle
# methods.  Girl is created on Startup.
$container = new IOC::Lite::Container();
$container->register("Boy", "new");
$container->register("Girl","new", "Boy");
$container->start();

# if you really want to get girl back for some reason
($girl) = $container->get_components("Girl");

=head1 DESCRIPTION

IOC::Lite is an inplementation of the Inversion of Control (IoC) pattern currently being popularised by Spring and Picocontainer.
IOC::Lite is actually a Perlised implementation of Picocontainer and uses Pico's form of dependency injection.
What is dependency injection and IoC?  I'll give a brief explanation below, but be sure to check out
see also for more details.

IoC is a combination of a factory, a bridge, and some other pattern I haven't been able to place just yet.
It is more precisely, a factory that creates the implementation of a bridge object on-the-fly without requiring the user to do anything.  As you can see above, $girl is registered with "Boy" because that's the class that Girl depends on.  IOC::Lite::Container automatically creates boy for girl.  Cool, eh?

Now add the other pattern I can't yet name, which is a container of sorts.  
This container manages the lifecycle of objects it creates and that are based on "Startable".
This enalbes the container to start and stop components (managed classes in this case) as required or on destroy events.

Add this all together and you get the basic foundation of an Application Server.
Except that this is an application that you can make into any type of Application Server you want.
Those Picocontainer and Spring developers have a great idea there...

Oh yeh.  If you grab you object back out of the container, it's not really your object.
You've grabbed a dynamic adaptor/proxy thing that acts like your object.
If you really need your object back you can get it with $object->{object}.
You shouldn't need to do this, but just in case.

=head2 EXPORT

None by default.



=head1 SEE ALSO

For a detailed overview of IoC see Martin Folwer's document.
http://www.martinfowler.com/articles/injection.html

For a simplified version see the Picocontainer explanation.
http://docs.codehaus.org/display/PICO/History+of+Inversion+of+Control

For a couple of projects that use IoC see Spring and Pico.
http://docs.codehaus.org/display/PICO/Home
http://www.springframework.org/


=head1 AUTHOR

John Fraser, E<lt>john.fraser4@verizon.net<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by John Fraser

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
