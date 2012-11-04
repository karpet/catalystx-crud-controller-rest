package CatalystX::CRUD::Controller::REST;
use Moose;
use namespace::autoclean;

use Data::Dump qw( dump );

BEGIN {
    extends qw( Catalyst::Controller::REST CatalystX::CRUD );
}

our $VERSION = '0.001';

__PACKAGE__->mk_accessors(
    qw(
        model_adapter
        model_name
        model_meta
        primary_key
        naked_results
        page_size
        )
);

with 'CatalystX::CRUD::ControllerRole';

=head1 NAME

CatalystX::CRUD::Controller::REST - Catalyst::Controller::REST with CRUD

=head1 SYNOPSIS

 package MyApp::Controller::Foo;
 use Moose;
 use namespace::autoclean;

 BEGIN { extends 'CatalystX::CRUD::Controller::REST' }
     
 __PACKAGE__->config(
    model_name      => 'Foo',
    primary_key     => 'id',
    page_size       => 50,
 );
    
 1;
    
 # now you can manage Foo objects with URIs like:
 # POST      /foo                -> create new record
 # GET       /foo                -> list all records
 # PUT       /foo/<pk>           -> create or update record (idempotent)
 # DELETE    /foo/<pk>           -> delete record
 # GET       /foo/<pk>           -> view record
 # GET       /foo/<pk>/bar       -> view 'bar' object(s) related to 'foo'
 # GET       /foo/<pk>/bar/<pk2> -> view 'bar' with id <pk2> related to 'foo' with <pk>
 # POST      /foo/<pk>/bar       -> create 'bar' object related to 'foo' (idempotent)
 # PUT       /foo/<pk>/bar/<pk2> -> create relationship between 'foo' and 'bar'
 # DELETE    /foo/<pk>/bar/<pk2> -> sever 'bar' object relationship to 'foo'
 # POST      /foo/<pk>/bar/<pk2> -> update 'bar' object related to 'foo'

=head1 DESCRIPTION

Subclass of Catalyst::Controller::REST for use with CatalystX::CRUD.

=head1 DISCLAIMERS

This module is B<not> to be confused with CatalystX::CRUD::REST.
This is not a drop-in replacement for existing CatalystX::CRUD::Controllers.

This module extends Catalyst::Controller::REST to work with the
CatalystX::CRUD::Controller API. It is designed for web services,
not managing CRUD actions via HTML forms.

This is B<not> a subclass of CatalystX::CRUD::Controller.

=cut

=head1 METHODS

=cut

##############################################################
# Local actions

sub search_objects : Path('search') : Args(0) : ActionClass('REST') { }

sub search_objects_GET {
    my ( $self, $c ) = @_;
    $c->log->debug('search_GET');
    $self->search($c);
    if ( !blessed( $c->stash->{results} ) ) {
        $self->status_bad_request( $c,
            message => 'Must provide search parameters' );
    }
    else {
        $self->status_ok( $c, entity => $c->stash->{results}->serialize );
    }
}

sub count_objects : Path('count') : Args(0) : ActionClass('REST') { }

sub count_objects_GET {
    my ( $self, $c ) = @_;
    $c->log->debug('count_GET');
    $self->count($c);
    if ( !blessed( $c->stash->{results} ) ) {
        $self->status_bad_request( $c,
            message => 'Must provide search parameters' );
    }
    else {
        $self->status_ok( $c, entity => $c->stash->{results}->serialize );
    }
}

##############################################################
# REST actions

# base method for /
sub zero_args : Path('') : Args(0) : ActionClass('REST') { }

# list objects
sub zero_args_GET {
    my ( $self, $c ) = @_;
    $self->list($c);
    $self->status_ok( $c, entity => $c->stash->{results}->serialize );
}

# create object
sub zero_args_POST {
    my ( $self, $c ) = @_;

    unless ( $self->can_write($c) ) {
        $self->status_forbidden( $c, message => 'Permission denied' );
        return;
    }

    $c->stash( object => $self->do_model( $c, 'fetch' ) );
    if ( my $obj = $self->save_object($c) ) {
        my $pk = $self->make_primary_key_string($obj);
        $self->status_created(
            $c,
            location => $c->uri_for($pk),
            entity   => $c->stash->{object}->serialize
        );
    }
    else {
        # TODO msg
        $self->status_bad_request( $c, message => 'Failed to create' );
    }
}

# base method for /<pk>
sub one_arg : Path('') : Args(1) : ActionClass('REST') {
    my ( $self, $c, $id ) = @_;
    $self->fetch( $c, $id );
}

sub one_arg_GET {
    my ( $self, $c, $id ) = @_;

    # rely on one_arg() to handle errors to this point.
    if ( $self->has_errors($c) ) {
        $c->clear_errors;
        return if $c->response->status;
    }

    $self->status_ok( $c, entity => $c->stash->{object}->serialize );
}

# create or update object (idempotent)
sub one_arg_PUT {
    my ( $self, $c, $id ) = @_;

    # remember if we're creating or updating
    my $obj_is_new = $c->stash->{object}->is_new;

    unless ( $self->can_write($c) ) {
        $self->status_forbidden( $c, message => 'Permission denied' );
        return;
    }

    if ( my $obj = $self->save_object($c) ) {
        if ( !$obj_is_new ) {
            $self->status_ok( $c, entity => $obj->serialize );
        }
        else {
            my $loc = $c->uri_for($id);
            $c->log->debug("PUT location=$loc") if $c->debug;
            $self->status_created(
                $c,
                location => $loc,
                entity   => $obj->serialize,
            );
        }
    }
    else {
        # TODO msg
        $self->status_bad_request( $c, message => 'Failed to update' );
    }
}

# delete object
sub one_arg_DELETE {
    my ( $self, $c, $id ) = @_;

    # rely on one_arg() to handle errors to this point.
    if ( $self->has_errors($c) ) {
        $c->clear_errors;
        return if $c->response->status;
    }

    unless ( $self->can_write($c) ) {
        $self->status_forbidden( $c, message => 'Permission denied' );
        return;
    }

    if ( $self->delete_object($c) ) {
        $self->status_no_content($c);
    }
    else {
        # TODO msg
        $self->status_bad_request( $c, message => 'Failed to delete' );
    }
}

# related to /<pk>
sub two_args : Path('') : Args(2) : ActionClass('REST') {
    my ( $self, $c, $id, $rel ) = @_;
    $self->fetch( $c, $id );
    $c->stash( rel_name => $rel );
}

# list /<pk>/<rel>
sub two_args_GET {
    my ( $self, $c, $id, $rel ) = @_;

    # rely on two_args() to handle errors to this point.
    if ( $self->has_errors($c) ) {
        $c->clear_errors;
        return if $c->response->status;
    }

    my $results
        = $self->do_model( $c, 'iterator_related', $c->stash->{object},
        $rel, );
    $self->status_ok( $c, entity => $results->serialize );
}

# create /<pk>/<rel>
sub two_args_POST {
    my ( $self, $c, $id, $rel ) = @_;

    # rely on two_args() to handle errors to this point.
    if ( $self->has_errors($c) ) {
        $c->clear_errors;
        return if $c->response->status;
    }

    unless ( $self->can_write($c) ) {
        $self->status_forbidden( $c, message => 'Permission denied' );
        return;
    }

    my $rel_obj
        = $self->do_model( $c, 'create_related', $c->stash->{object}, $rel, );
    if ($rel_obj) {
        my $rel_id = $self->make_primary_key_string($rel_obj);
        $self->status_created(
            $c,
            location =>
                $c->uri_for( sprintf( "%s/%s/%s", $id, $rel, $rel_id ) ),
            entity => $rel_obj->serialize
        );
    }
    else {
        # TODO msg
        $self->status_bad_request( $c, message => 'Failed to delete' );
    }

}

# actions on <rel> related to /<pk>
sub three_args : Path('') : Args(3) : ActionClass('REST') {
    my ( $self, $c, $id, $rel, $rel_id ) = @_;
    $self->fetch( $c, $id );
    $c->stash( rel_name         => $rel );
    $c->stash( foreign_pk_value => $rel_id );
}

# /<pk>/<re>/<pk2>
sub three_args_GET {
    my ( $self, $c, $id, $rel, $rel_id ) = @_;

    # rely on three_args() to handle errors to this point.
    if ( $self->has_errors($c) ) {
        $c->clear_errors;
        return if $c->response->status;
    }

    my $result = $self->do_model( $c, 'find_related', $c->stash->{object},
        $rel, $rel_id, );
    if ( !$result ) {
        my $err_msg = sprintf( "No such %s with id '%s'", $rel, $rel_id );
        $self->status_not_found( $c, message => $err_msg );
    }
    else {
        $self->status_ok( $c, entity => $result->serialize );
    }
}

# DELETE    /foo/<pk>/bar/<pk2> -> sever 'bar' object relationship to 'foo'

sub three_args_DELETE {
    my ( $self, $c, $id, $rel, $rel_id ) = @_;

    # rely on three_args() to handle errors to this point.
    if ( $self->has_errors($c) ) {
        $c->clear_errors;
        return if $c->response->status;
    }

    unless ( $self->can_write($c) ) {
        $self->status_forbidden( $c, message => 'Permission denied' );
        return;
    }

    my $rt = $self->do_model(
        $c, 'rm_related', $c->stash->{object},
        $c->stash->{rel_name},
        $c->stash->{foreign_pk_value}
    );
    if ($rt) {
        $self->status_no_content($c);
    }
    else {
        # TODO msg
        $self->status_bad_request( $c,
            message => 'Failed to remove relationship' );
    }
}

# TODO
# POST      /foo/<pk>/bar/<pk2> -> create relationship between 'foo' and 'bar'
# PUT       /foo/<pk>/bar/<pk2> -> update 'bar' object related to 'foo'

##########################################################
# CRUD methods

# override base method
sub save_object {
    my ( $self, $c ) = @_;

    # get a valid object
    my $obj = $self->inflate_object($c);
    if ( !$obj ) {
        $c->log->debug("inflate_object() returned false") if $c->debug;
        return 0;
    }

    # write our changes
    unless ( $self->precommit( $c, $obj ) ) {
        $c->stash->{template} ||= $self->default_template;
        return 0;
    }
    $self->create_or_update_object( $c, $obj );
    $self->postcommit( $c, $obj );
    return $obj;
}

=head2 create_or_update_object( I<context>, I<object> )

Calls the update() or create() method on the I<object> (or model_adapter()),
picking the method based on whether C<object_id> in stash() 
evaluates true (update) or false (create).

=cut

sub create_or_update_object {
    my ( $self, $c, $obj ) = @_;
    my $method = $obj->is_new ? 'create' : 'update';
    $c->log->debug("object->$method") if $c->debug;
    if ( $self->model_adapter ) {
        $self->model_adapter->$method( $c, $obj );
    }
    else {
        $obj->$method;
    }
}

sub delete_object {
    my ( $self, $c ) = @_;
    unless ( $self->can_write($c) ) {
        $self->status_forbidden( $c, message => 'Permission denied' );
        return;
    }

    my $o = $c->stash->{object};

    unless ( $self->precommit( $c, $o ) ) {
        return 0;
    }
    if ( $self->model_adapter ) {
        $self->model_adapter->delete( $c, $o );
    }
    else {
        $o->delete;
    }
    $self->postcommit( $c, $o );
    return 1;
}

=head2 inflate_object( I<ctx> )

Returns the object from stash() initialized with the request data.

=cut

sub inflate_object {
    my ( $self, $c ) = @_;
    my $object = $c->stash->{object};
    if ( !$object ) {
        $self->throw_error("object not set in stash");
    }
    my $req_data = $c->req->data;
    if ( !$req_data ) {
        $c->status_bad_request( $c, message => 'Missing request data' );
        return;
    }

    # TODO other sanity checks?

    for my $f ( keys %$req_data ) {
        if ( $object->can($f) ) {
            $object->$f( $req_data->{$f} );
        }
    }
    return $object;
}

sub can_read  {1}
sub can_write {1}

sub precommit {1}

=head2 postcommit( I<cxt>, I<obj> )

Called internally inside save_object(). Overrides parent class
which issues redirect on successful save_object(). Our default just returns true.
Override this method to post-process a successful save_object() action.

=cut

sub postcommit {1}

sub fetch {
    my ( $self, $c, $id ) = @_;

    unless ( $self->can_read($c) ) {
        $self->status_forbidden( $c, message => 'Permission denied' );
        return;
    }

    $c->stash->{object_id} = $id;
    my @pk = $self->get_primary_key( $c, $id );

    # make sure all elements of the @pk pairs are not-null
    if ( scalar(@pk) % 2 ) {
        $self->throw_error(
            "Odd number of elements returned from get_primary_key()");
    }
    my %pk_pairs = @pk;
    my $pk_is_null;
    for my $key ( keys %pk_pairs ) {
        my $val = $pk_pairs{$key};
        if ( !defined($val) or !length($val) ) {
            $pk_is_null = $key;
            last;
        }
    }
    if ( $c->debug and defined $pk_is_null ) {
        $c->log->debug("Null PK value for '$pk_is_null'");
    }
    my @arg = ( defined $pk_is_null || !$id ) ? () : (@pk);
    $c->log->debug( "fetch: " . dump \@arg ) if $c->debug;
    $c->stash->{object} = $self->do_model( $c, 'fetch', @arg );
    if ( $self->has_errors($c) or !$c->stash->{object} ) {
        my $err_msg
            = sprintf( "No such %s with id '%s'", $self->model_name, $id );
        $self->status_not_found( $c, message => $err_msg );
        $c->log->error($err_msg);
    }
}

=head2 do_search( I<context>, I<arg> )

Prepare and execute a search. Called internally by list()
and search().

Results are saved in stash() under the C<results> key.

If B<naked_results> is true, then results are set just as they are
returned from search() or list() (directly from the Model).

If B<naked_results> is false (default), then results is a
CatalystX::CRUD::Results object.

=cut

sub do_search {
    my ( $self, $c, @arg ) = @_;

    $self->throw_error("TODO");

    # stash the form so it can be re-displayed
    # subclasses must stick-ify it in their own way.
    $c->stash->{form} ||= $self->form($c);

    # if we have no input, just return for initial search
    if ( !@arg && !$c->req->param && $c->action->name eq 'search' ) {
        return;
    }

    # turn flag on unless explicitly turned off
    $c->stash->{view_on_single_result} = 1
        unless exists $c->stash->{view_on_single_result};

    my $query;
    if ( $self->can('make_query') ) {
        $query = $self->make_query( $c, @arg );
    }
    elsif ( $self->model_can( $c, 'make_query' ) ) {
        $query = $self->do_model( $c, 'make_query', @arg );
    }
    else {
        $self->throw_error(
            "neither controller nor model implement a make_query() method");
    }
    my $count = $self->do_model( $c, 'count', $query ) || 0;
    my $results;
    unless ( $c->stash->{fetch_no_results} ) {
        $results = $self->do_model( $c, 'search', $query );
    }

    if (   $results
        && $count == 1
        && $c->stash->{view_on_single_result}
        && ( my $uri = $self->uri_for_view_on_single_result( $c, $results ) )
        )
    {
        $c->log->debug("redirect for single_result") if $c->debug;
        $c->response->redirect($uri);
    }
    else {

        my $pager;
        if ( $count && $self->model_can( $c, 'make_pager' ) ) {
            $pager = $self->do_model( $c, 'make_pager', $count, $results );
        }

        $c->stash->{results}
            = $self->naked_results
            ? $results
            : CatalystX::CRUD::Results->new(
            {   count   => $count,
                pager   => $pager,
                results => $results,
                query   => $query,
            }
            );
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

=head1 COPYRIGHT & LICENSE

Copyright 2012 Peter Karman.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
