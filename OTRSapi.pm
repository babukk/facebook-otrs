package OTRSapi;

use strict;
use warnings;

use SOAP::Lite;
use Data::Dumper;

sub new {
    my ($class, $params) = @_;

    my $self = {};

    while (my ($k, $v) = each %{$params}) {
        $self->{ $k } = $v;
    }

    $self->{ 'otrs_url' } .= '/otrs/nph-genericinterface.pl/Webservice/GenericTicketConnector';
    $self->{ 'namespace' } = 'http://www.otrs.org/TicketConnector/';
    $self->{ 'ticket_type' } = 'Facebook'  unless $self->{ 'ticket_type' };
    $self->{ 'ticket_priority' } = '3 normal'  unless $self->{ 'ticket_priority' };
    $self->{ 'ticket_content_type' } = 'text/plain; charset=utf8'  unless $self->{ 'ticket_content_type' };

    bless $self, $class;

    return $self;
}

sub createTicket {
    my ($self, $post_id, $post_date_time, $post_message) = @_;

    my $Operation = 'TicketCreate';
    my $NameSpace = 'http://www.otrs.org/TicketConnector/';

    $post_message = '*** No text ***'  unless $post_message;

    my @TicketData = ();
    my $Param = SOAP::Data->name( Title => 'Facebook ticket' );
    $Param->type('string');
    push @TicketData, $Param;

    $Param = SOAP::Data->name( Queue => $self->{ 'otrs_queue' } );
    $Param->type('string');
    push @TicketData, $Param;

    $Param = SOAP::Data->name( Type => $self->{ 'ticket_type' } );
    $Param->type('string');
    push @TicketData, $Param;

    $Param = SOAP::Data->name( State => 'new' );
    $Param->type('string');
    push @TicketData, $Param;

    $Param = SOAP::Data->name( Priority => $self->{ 'ticket_priority' } );
    $Param->type('string');
    push @TicketData, $Param;

    $Param = SOAP::Data->name( CustomerUser => $self->{ 'otrs_customer_user' } );
    $Param->type('string');
    push @TicketData, $Param;

    my @ArticleData = ();
    $Param = SOAP::Data->name( Subject => 'Ticket created by FB post id:' . $post_id );
    $Param->type('string');
    push @ArticleData, $Param;

    $Param = SOAP::Data->name( ContentType => $self->{ 'ticket_content_type' } );
    $Param->type('string');
    push @ArticleData, $Param;

    $Param = SOAP::Data->name( Body => $post_message );
    $Param->type('string');
    push @ArticleData, $Param;

    my @DynamicFields = ();

    my @SOAPData;
    push @SOAPData, SOAP::Data->name('UserLogin')->value($self->{ 'otrs_login' });
    push @SOAPData, SOAP::Data->name('Password')->value($self->{ 'otrs_password' });
    push @SOAPData, SOAP::Data->name(Ticket => \SOAP::Data->value(@TicketData));
    push @SOAPData, SOAP::Data->name(Article => \SOAP::Data->value(@ArticleData));
    push @SOAPData, SOAP::Data->name(DynamicField => @DynamicFields) if @DynamicFields;

    my $SOAPObject = SOAP::Lite
        ->uri($self->{ 'namespace' })
        ->proxy($self->{ 'otrs_url' })
        ->$Operation(@SOAPData);

    if ($SOAPObject->fault) {
        $self->{ 'logger' }->error($SOAPObject->faultcode . '; ' . $SOAPObject->faultstring)  if $self->{ 'logger' };
    }
    else {
        my $XMLResponse = $SOAPObject->context()->transport()->proxy()->http_response()->content();
        my $Deserialized = eval {
            SOAP::Deserializer->deserialize($XMLResponse);
        };
        my $Body = $Deserialized->body();
        if (defined $Body->{ 'TicketCreateResponse' }->{ 'Error' }) {
            $self->{ 'logger' }->error( 'Could not create ticket. ' . 'ErrorCode:   ' . $Body->{ 'TicketCreateResponse' }->{ 'Error' }->{ 'ErrorCode' } .
                                        'ErrorMessage: ' . $Body->{ 'TicketCreateResponse' }->{ 'Error' }->{ 'ErrorMessage' });
        }
        else {
            $self->{ 'logger' }->info('Created ticket ' . $Body->{ 'TicketCreateResponse' }->{ 'TicketNumber' })  if $self->{ 'logger' };
            return $Body->{ 'TicketCreateResponse' }->{ 'TicketNumber' };
        }
    }

    return undef;
}

1;
