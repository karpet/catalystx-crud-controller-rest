package CatalystX::CRUD::Controller::REST;
use Moose;
use namespace::autoclean;

use Data::Dump qw( dump );

BEGIN {
    extends 'Catalyst::Controller::REST', 'CatalystX::CRUD::Controller',;
}

our $VERSION = '0.001';

=head1 NAME

CatalystX::CRUD::Controller::REST - Catalyst::Controller::REST with CRUD

=head1 SYNOPSIS

 package MyApp::Controller::Foo;
 use Moose;
 use namespace::autoclean;

 BEGIN { extends 'CatalystX::CRUD::Controller::REST' }

=head1 DESCRIPTION

This module is B<not> to be confused with CatalystX::CRUD::REST.
This is not a drop-in replacement for existing CatalystX::CRUD::Controllers.

This module extends Catalyst::Controller::REST to work with the
CatalystX::CRUD::Controller API.

=cut

=head1 METHODS

=cut

# override all the CRUD methods to undo their attributes
# and create *_HTTP methods instead.

sub create       { }
sub read         { }
sub update       { }
sub delete       { }
sub add          { }
sub edit         { }
sub save         { }
sub view         { }
sub remove       { }
sub rm           { }
sub list_related { }
sub view_related { }

sub list : Path('') : Args(0) : ActionClass('REST') { }

sub list_GET {
    my ( $self, $c ) = @_;
    $c->log->debug('list_GET');
    $self->SUPER::list($c);
    $self->status_ok( $c, entity => $c->stash->{results}->serialize );
}

sub search : Local : Args(0) : ActionClass('REST') { }

sub search_GET {
    my ( $self, $c ) = @_;
    $c->log->debug('search_GET');
    $self->SUPER::search($c);
    if ( !blessed( $c->stash->{results} ) ) {
        $self->status_bad_request( $c,
            message => 'Must provide search parameters' );
    }
    else {
        $self->status_ok( $c, entity => $c->stash->{results}->serialize );
    }
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-catalystx-crud-controller-rest at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CatalystX-CRUD-Controller-REST>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CatalystX::CRUD::Controller::REST


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CatalystX-CRUD-Controller-REST>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CatalystX-CRUD-Controller-REST>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CatalystX-CRUD-Controller-REST>

=item * Search CPAN

L<http://search.cpan.org/dist/CatalystX-CRUD-Controller-REST/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2012 Peter Karman.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
