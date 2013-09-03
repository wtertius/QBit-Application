package QBit::Application::_Utils::TmpRights;

use qbit;

use base qw(QBit::Class);

sub init {
    my ($self) = @_;

    my @missed_required_params = grep {!exists($self->{$_})} qw(app rights);
    throw Exception::BadArguments gettext('Missed requred fields "%s"', join(', ', @missed_required_params))
      if @missed_required_params;

    ++$self->{'app'}->{'__TMP_RIGHTS__'}{$_} foreach @{$self->{'rights'}};

}

sub DESTROY {
    my ($self) = @_;

    foreach (@{$self->{'rights'}}) {
        delete($self->{'app'}->{'__TMP_RIGHTS__'}{$_}) unless --$self->{'app'}->{'__TMP_RIGHTS__'}{$_};
    }
}

TRUE;
