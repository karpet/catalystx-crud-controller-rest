package MyApp::Controller::REST::File;
use strict;
use base qw(
    CatalystX::CRUD::Controller::REST
);
use Carp;
use Data::Dump qw( dump );
use File::Temp;
use MyApp::Form;
use MRO::Compat;
use mro 'c3';

__PACKAGE__->config(
    primary_key => 'absolute',
    data_fields => [qw( file content )],
    model_name  => 'File',
    primary_key => 'file',
    default     => 'application/json',     # default response content type
);

sub fetch {
    my ( $self, $c, $id ) = @_;
    eval { $self->next::method( $c, $id ); };
    if ( $self->has_errors($c) or $c->res->status == 404 ) {

        my $err = $c->error->[0] || 'No such File';
        if ( $err =~ m/^No such File/ ) {
            my $file = $self->do_model( $c, 'new_object', file => $id );
            $file = $self->do_model( $c, 'prep_new_object', $file );
            $c->log->debug("empty file object:$file") if $c->debug;
            $c->stash( object => $file );
        }
        else {
            # re-throw
            $self->throw_error($err);
        }
    }

    # clean up at end
    MyApp::Controller::Root->push_temp_files( $c->stash->{object} );
}

sub do_search {
    my ( $self, $c, @arg ) = @_;
    $self->next::method( $c, @arg );

    #carp dump $c->stash->{results};

    for my $file ( @{ $c->stash->{results}->{results} } ) {
        $file->read;
    }
}

1;
