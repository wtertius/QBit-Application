
=head1 Name

QBit::Application - base class for create applications.

=head1 Description

It union all project models.

=cut

package QBit::Application;

use qbit;

use base qw(QBit::Class);

use QBit::Application::_Utils::TmpLocale;
use QBit::Application::_Utils::TmpRights;

=head1 RO accessors

=over

=item

B<timelog>

=back

=cut

__PACKAGE__->mk_ro_accessors(qw(timelog));

sub init {
    my ($self) = @_;

    $self->SUPER::init();
    $self->{'__ORIG_OPTIONS__'} = {};
    package_merge_isa_data(
        ref($self),
        $self->{'__ORIG_OPTIONS__'},
        sub {
            my ($package, $res) = @_;

            my $pkg_stash = package_stash($package);

            foreach my $cfg (@{$pkg_stash->{'__OPTIONS__'} || []}) {
                foreach (keys %{$cfg->{'config'}}) {
                    warn gettext('%s: option "%s" replaced', $cfg->{'filename'}, $_)
                      if exists($res->{$_});
                    $res->{$_} = $cfg->{'config'}{$_};
                }
            }
        },
        __PACKAGE__
    );

    my $app_module = ref($self) . '.pm';
    $app_module =~ s/::/\//g;

    $self->{'__ORIG_OPTIONS__'}{'FrameworkPath'} = $INC{'QBit/Class.pm'} =~ /(.+?)QBit\/Class\.pm$/ ? $1 : './';
    $self->{'__ORIG_OPTIONS__'}{'ApplicationPath'} =
        ($INC{$app_module} || '') =~ /(.*?\/?)(?:lib\/*)?$app_module$/
      ? ($1 || './')
      : './';

    $self->{'__OPTIONS__'} = $self->{'__ORIG_OPTIONS__'};    # To set global options

    my $locales = $self->get_option('locales', {});
    if (%$locales) {
        my ($locale) = grep {$locales->{$_}{'default'}} keys(%$locales);
        ($locale) = keys(%$locales) unless $locale;

        $self->set_app_locale($locale);
    }

    if ($self->get_option('preload_accessors')) {
        $self->$_ foreach keys(%{$self->get_models()});
    }

    delete($self->{'__OPTIONS__'});    # Options initializing in pre_run
}

=head1 Package methods

=head2 config_opts

Short method description

B<Arguments:>

=over

=item

B<%opts> - additional arguments:

=back

B<Return value:> type, description

=cut

sub config_opts {
    my ($self, %opts) = @_;

    my $class = ref($self) || $self;

    my $pkg_name = $class;
    $pkg_name =~ s/::/\//g;
    $pkg_name .= '.pm';

    $self->_push_pkg_opts($INC{$pkg_name} || $pkg_name => \%opts);
}

=head2 use_config

Short method description

B<Arguments:>

=over

=item

B<$filename> - type, description

=back

B<Return value:> type, description

=cut

sub use_config {
    my ($self, $filename) = @_;

    my %config;
    try {
        my @config = do $filename;

        throw $@ if $@;
        throw $! if $!;
        throw gettext("Invalid config") if @config % 2 == 1 || !defined($config[0]);

        %config = @config;
    }
    catch {
        throw gettext('Read config file "%s" failed: %s', $filename, $_[0]->message);
    };

    my %dev_config;
    {
        no warnings;
        %dev_config = do "$filename.dev";
    }
    throw gettext('Read devconfig file "%s" failed: %s', "$filename.dev", $@)
      if $@;

    %dev_config = ()
      if keys(%dev_config) == 1
          && exists($dev_config{''})
          && !defined($dev_config{''});
    while (my ($key, $value) = each %dev_config) {
        l(gettext('Option "%s" does not exists in main config "%s"', $key, $filename))
          unless exists($config{$key})
              || in_array($key, [qw(find_app_mem_cycle)]);
        $config{$key} = $value;
    }

    $self->_push_pkg_opts($filename => \%config);
}

=head1 Methods

=head2 get_option

Short method description

B<Arguments:>

=over

=item

B<$name> - type, description

=item

B<$default> - type, description

=back

B<Return value:> type, description

=cut

sub get_option {
    my ($self, $name, $default) = @_;

    my $res = $self->{'__OPTIONS__'}{$name} || return $default;

    foreach my $str (ref($res) eq 'ARRAY' ? @$res : $res) {
        while ($str =~ /^(.*?)(?:\${([\w\d_]+)})(.*)$/) {
            $str = ($1 || '') . ($self->get_option($2) || '') . ($3 || '');
        }
    }

    return $res;
}

=head2 set_option

Short method description

B<Arguments:>

=over

=item

B<$name> - type, description

=item

B<$value> - type, description

=back

B<Return value:> type, description

=cut

sub set_option {
    my ($self, $name, $value) = @_;

    $self->{'__OPTIONS__'}{$name} = $value;
}

=head2 get_models

Short method description

B<No arguments.>

B<Return value:> type, description

=cut

sub get_models {
    my ($self) = @_;

    my $models = {};

    package_merge_isa_data(
        ref($self),
        $models,
        sub {
            my ($package, $res) = @_;

            my $pkg_models = package_stash($package)->{'__MODELS__'} || {};
            $models->{$_} = $pkg_models->{$_} foreach keys(%$pkg_models);
        },
        __PACKAGE__
    );

    return $models;
}

=head2 get_registered_rights

Short method description

B<No arguments.>

B<Return value:> type, description

=cut

sub get_registered_rights {
    my ($self) = @_;

    my $rights = {};
    package_merge_isa_data(
        ref($self),
        $rights,
        sub {
            my ($ipackage, $res) = @_;

            my $ipkg_stash = package_stash($ipackage);
            $res->{'__RIGHTS__'} = {%{$res->{'__RIGHTS__'} || {}}, %{$ipkg_stash->{'__RIGHTS__'} || {}}};
        },
        __PACKAGE__
    );

    $self->{'__REGISTERED_RIGHTS__'} = $rights->{'__RIGHTS__'};

    return $rights->{'__RIGHTS__'};
}

=head2 get_registered_right_groups

Short method description

B<No arguments.>

B<Return value:> type, description

=cut

sub get_registered_right_groups {
    my ($self) = @_;

    my $rights = {};
    package_merge_isa_data(
        ref($self),
        $rights,
        sub {
            my ($ipackage, $res) = @_;

            my $ipkg_stash = package_stash($ipackage);
            $res->{'__RIGHT_GROUPS__'} =
              {%{$res->{'__RIGHT_GROUPS__'} || {}}, %{$ipkg_stash->{'__RIGHT_GROUPS__'} || {}}};
        },
        __PACKAGE__
    );

    return $rights->{'__RIGHT_GROUPS__'};
}

sub get_registred_right_groups {&get_registered_right_groups;}

=head2 check_rights

Short method description

B<Arguments:>

=over

=item

B<@rights> - type, description

=back

B<Return value:> type, description

=cut

sub check_rights {
    my ($self, @rights) = @_;

    return FALSE unless @rights;

    if ($self->get_option('die_on_unregistered_right_check')) {
        foreach my $right (map {ref($_) ? @$_ : $_} @rights) {
            throw gettext("Unregistered right '%s'", $right)
              unless ($self->{__REGISTERED_RIGHTS__} || $self->get_registered_rights())->{$right};
        }
    }

    my $cur_user = $self->get_option('cur_user');
    my $cur_rights;

    if ($cur_user) {
        $cur_rights = $cur_user->{'rights'};

        unless (defined($cur_rights)) {
            my $cur_roles = $self->rbac->get_cur_user_roles();

            $cur_rights =
              {map {$_->{'right'} => TRUE}
                  @{$self->rbac->get_roles_rights(fields => [qw(right)], role_id => [keys(%$cur_roles)])}};

            $cur_user->{'rights'} = $cur_rights if defined($cur_user);
        }
    }

    my %user_and_temp_rights;
    push_hs(%user_and_temp_rights, $cur_rights) if $cur_rights;
    push_hs(%user_and_temp_rights, \%{$self->{'__TMP_RIGHTS__'} || {}});

    foreach (@rights) {
        return FALSE unless ref($_) ? scalar(grep($user_and_temp_rights{$_}, @$_)) : $user_and_temp_rights{$_};
    }

    return TRUE;
}

=head2 set_app_locale

Short method description

B<Arguments:>

=over

=item

B<$locale_id> - type, description

=back

B<Return value:> type, description

=cut

sub set_app_locale {
    my ($self, $locale_id) = @_;

    my $locale = $self->get_option('locales', {})->{$locale_id};
    throw gettext('Unknown locale') unless defined($locale);
    throw gettext('Undefined locale code for locale "%s"', $locale_id) unless $locale->{'code'};

    set_locale(
        project => $self->get_option('locale_domain', 'application'),
        path    => $self->get_option('ApplicationPath') . '/locale',
        lang    => $locale->{'code'},
    );

    $self->set_option(locale => $locale_id);
}

=head2 set_tmp_app_locale

Short method description

B<Arguments:>

=over

=item

B<$locale_id> - type, description

=back

B<Return value:> type, description

=cut

sub set_tmp_app_locale {
    my ($self, $locale_id) = @_;

    my $old_locale_id = $self->get_option('locale');
    $self->set_app_locale($locale_id);

    return QBit::Application::_Utils::TmpLocale->new(app => $self, old_locale => $old_locale_id);
}

=head2 add_tmp_rights

Short method description

B<Arguments:>

=over

=item

B<@rights> - type, description

=back

B<Return value:> type, description

=cut

sub add_tmp_rights {
    my ($self, @rights) = @_;

    return QBit::Application::_Utils::TmpRights->new(app => $self, rights => \@rights);
}

=head2 pre_run

Short method description

B<No arguments.>

B<Return value:> type, description

=cut

sub pre_run {
    my ($self) = @_;

    $self->{'__OPTIONS__'} = clone($self->{'__ORIG_OPTIONS__'});

    unless (exists($self->{'__TIMELOG_CLASS__'})) {
        my $tl_package = $self->{'__TIMELOG_CLASS__'} = $self->get_option('timelog_class', 'QBit::TimeLog');

        $tl_package =~ s/::/\//g;
        $tl_package .= '.pm';
        require $tl_package;
    }

    $self->{'timelog'} = $self->{'__TIMELOG_CLASS__'}->new();
    $self->{'timelog'}->start(gettext('Total application run time'));

    foreach (keys(%{$self->get_models()})) {
        $self->$_->pre_run() if exists($self->{$_}) && $self->{$_}->can('pre_run');
    }
}

=head2 post_run

Short method description

B<No arguments.>

B<Return value:> type, description

=cut

sub post_run {
    my ($self) = @_;

    foreach (keys(%{$self->get_models()})) {
        $self->$_->finish()   if exists($self->{$_}) && $self->{$_}->can('finish');
        $self->$_->post_run() if exists($self->{$_}) && $self->{$_}->can('post_run');
    }

    $self->timelog->finish();

    $self->process_timelog($self->timelog);

    if ($self->get_option('find_app_mem_cycle')) {
        if (eval {require 'Devel/Cycle.pm'}) {
            Devel::Cycle->import();
            my @cycles;
            Devel::Cycle::find_cycle($self, sub {push(@cycles, shift)});
            $self->process_mem_cycles(\@cycles) if @cycles;
        } else {
            l(gettext('Devel::Cycle is not installed'));
        }
    }
}

=head2 process_mem_cycles

Short method description

B<Arguments:>

=over

=item

B<$cycles> - type, description

=back

B<Return value:> type, description

=cut

sub process_mem_cycles {
    my ($self, $cycles) = @_;

    my $counter = 0;
    my $text    = '';
    foreach my $path (@$cycles) {
        $text .= gettext('Cycle (%s):', ++$counter) . "\n";
        foreach (@$path) {
            my ($type, $index, $ref, $value, $is_weak) = @$_;
            $text .= gettext(
                "\t%30s => %-30s\n",
                ($is_weak ? 'w-> ' : '') . Devel::Cycle::_format_reference($type, $index, $ref, 0),
                Devel::Cycle::_format_reference(undef, undef, $value, 1)
            );
        }
        $text .= "\n";
    }

    l($text);
    return $text;
}

=head2 process_timelog

Short method description

B<No arguments.>

B<Return value:> type, description

=cut

sub process_timelog { }

=head2 _push_pkg_opts

Short method description

B<Arguments:>

=over

=item

B<$filename> - type, description

=item

B<$config> - type, description

=back

B<Return value:> type, description

=cut

sub _push_pkg_opts {
    my ($self, $filename, $config) = @_;

    my $pkg_stash = package_stash(ref($self) || $self);

    $pkg_stash->{'__OPTIONS__'} = []
      unless exists($pkg_stash->{'__OPTIONS__'});

    push(
        @{$pkg_stash->{'__OPTIONS__'}},
        {
            filename => $filename,
            config   => $config,
        }
    );
}

TRUE;
