#!/usr/bin/perl
#
# Provides the StateCheck and StateTransition abstractions for writing
# UBOS web app tests.
#
# This file is part of webapptest.
# (C) 2012-2014 Indie Computing Corp.
#
# webapptest is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# webapptest is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with webapptest.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package UBOS::WebAppTest;

use UBOS::App;
use UBOS::Logging;

use fields qw(
        name
        description
        packageName
        packageVersion
        testContext
        customizationPointValues
        statesTransitions );

##
# Constructor.
# $packageName: name of the application's package to be tested
# $description: human-readable description of the test
# @_: parameters
sub new {
    my $self = shift;
    my %pars = @_;
    
    my $packageName       = $pars{appToTest};
    my $name              = $pars{name};
    my $testContext       = $pars{testContext};
    my $description       = $pars{description};
    my $custPointValues   = $pars{customizationPointValues};
    my $statesTransitions = $pars{checks};

    unless( $packageName ) {
        fatal( 'AppTest must identify the application package being tested. Use parameter named "appToTest".' );
    }
    if( ref( $name )) {
        fatal( 'AppTest name name must be a string.' );
    }
    if( defined( $testContext )) {
        if( ref( $testContext )) {
            fatal( 'AppTest testContext name must be a string.' );
        }
        unless( $testContext eq '' || $testContext =~ m!^/[-_.a-z0-9%]+$! ) {
            fatal( 'AppTest testContext must be a single-level relative path starting with a slash, or be empty' );
        }
    }
    if( defined( $pars{hostname} )) {
        fatal( 'AppTest must not specify a hostname any more; use parameter to TestPlan instead' );
    }
    if( ref( $description )) {
        fatal( 'AppTest description name must be a string.' );
    }
    if( $custPointValues ) {
        if( ref( $custPointValues ) ne 'HASH' ) {
            fatal( 'CustomizationPointValues must be a hash' );
        }
        foreach my $name ( keys %$custPointValues ) {
            my $value = $custPointValues->{$name};

            if( ref( $name ) || ref( $value )) {
                fatal( 'CustomizationPointValues must be a hash with simple name-value pairs in it.' );
            }
        }
    }
    if( !$statesTransitions || !@$statesTransitions ) {
        fatal( 'AppTest must provide at least a StateCheck for the virgin state' );
    }

    my $i = 0;
    foreach my $candidate ( @$statesTransitions ) {
        if( $i % 2 ) {
            if( !ref( $candidate ) || !$candidate->isa( 'UBOS::WebAppTest::StateTransition' )) {
                fatal( 'Array of StateChecks and StateTransitions must alternate: expected StateTransition' );
            }
        } else {
            if( !ref( $candidate ) || !$candidate->isa( 'UBOS::WebAppTest::StateCheck' )) {
                fatal( 'Array of StateChecks and StateTransitions must alternate: expected StateCheck' );
            }
        }
        ++$i;
    }    
    
    unless( @$statesTransitions % 2 ) {
        fatal( 'Array of StateChecks and StateTransitions must alternate and end with a StateCheck.' );
    }

    unless( ref( $self )) {
        $self = fields::new( $self );
    }
    $self->{name}                     = $name;
    $self->{description}              = $description;
    $self->{packageName}              = $packageName;
    $self->{packageVersion}           = UBOS::Host::packageVersion( $packageName );
    $self->{testContext}              = $testContext;
    $self->{customizationPointValues} = $custPointValues;
    $self->{statesTransitions}        = $statesTransitions;

    return $self;
}

##
# Obtain the name of the text
# return: name
sub name {
    my $self = shift;

    return $self->{name};
}

##
# Allows the Run command to set a name for the test
# $name: the name
sub setName {
    my $self = shift;
    my $name = shift;

    $self->{name} = $name;
}

##
# Obtain the name of the package being tested
# return: the package name
sub packageName {
    my $self = shift;

    return $self->{packageName};
}

##
# Obtain the version of the package being tested
# return: the package version
sub packageVersion {
    my $self = shift;

    return $self->{packageVersion};
}

##
# Obtain the description
# return: the description
sub description {
    my $self = shift;

    return $self->{description};
}

##
# Obtain the siteId of the site currently being tested.
# return: the siteId
sub siteId {
    my $self = shift;

    return $self->{siteId};
}

##
# Obtain the appconfigid of the AppConfiguration currently being tested.
# return the appconfigid
sub appConfigId {
    my $self = shift;

    return $self->{appConfigId};
}

##
# Obtain the relative context at which the app will be installed and tested
# return: the context
sub getTestContext {
    my $self = shift;

    return $self->{testContext};
}

##
# Determine the apache context directory of the application being tested.
sub apache2ContextDir {
    my $self = shift;

    return '/srv/http/sites/' . $self->siteId . $self->getTestContext;
}

##
# Obtain the customization point values as a hash, if any
# return: hash, or undef
sub getCustomizationPointValues {
    my $self = shift;

    return $self->{customizationPointValues};
}

##
# Obtain the StateTest for the virgin state
# return: the StateTest
sub getVirginStateTest {
    my $self = shift;

    return $self->{statesTransitions}->[0];
}

##
# Obtain the outgoing StateTransition from this State. May return undef.
# $state the starting state
# return: the Transition, or undef
sub getTransitionFrom {
    my $self  = shift;
    my $state = shift;

    for( my $i=0 ; $i<@{$self->{statesTransitions}} ; ++$i ) {
        if( $state == $self->{statesTransitions}->[$i] ) {
            return ( $self->{statesTransitions}->[$i+1], $self->{statesTransitions}->[$i+2] );
        }
    }
    return undef;
}

################################################################################

package UBOS::WebAppTest::StatesTransitions;

use fields qw( name function );

##
# Superclass constructor.
# $name: name of the state
# $function: subroutine to check this state
sub new {
    my $self     = shift;
    my $name     = shift;
    my $function = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->{name}     = $name;
    $self->{function} = $function;

    return $self;
}

##
# Obtain the name of the StateCheck or StateTransition.
# return: the name
sub getName {
    my $self = shift;

    return $self->{name};
}


################################################################################

package UBOS::WebAppTest::StateCheck;

use base qw( UBOS::WebAppTest::StatesTransitions );
use fields;

use MIME::Base64;
use UBOS::Logging;

##
# Instantiate the StateCheck.
# $pars{name}: name of the state
# $pars{function}: subroutine to check this state
sub new {
    my $self = shift;
    my %pars = @_;

    my $name     = $pars{name};
    my $function = $pars{check};

    unless( $name ) {
        fatal( 'All StateChecks must have a name.' );
    }
    if( ref( $name )) {
        fatal( 'A StateCheck\'s name must be a string.' );
    }
    unless( $function ) {
        fatal( 'All StateChecks must have a check function.' );
    }
    unless( ref( $function ) eq 'CODE' ) {
        fatal( 'A StateCheck\'s check function must be a Perl subroutine.' );
    }

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $function );

    return $self;
}

##
# Check this state
# $c: the TestContext
# return: 1 if check passed
sub check {
    my $self = shift;
    my $c    = shift;

    $c->clearHttpSession(); # always before a new StateCheck
                        
    eval { &{$self->{function}}( $c ); };
    
    my $errors = $c->errorsAndClear;
    my $msg    = 'failed.';
    
    my $ret;
    if( $errors ) {
        $msg = 'failed.';
        $ret = 0;
    } elsif( $@ ) {
        $msg = $@;
        $ret = 0;
    } else {
        $ret = 1;
    }

    unless( $ret ) {
        error( 'StateCheck', $self->{name}, ':', $msg );
    }
        
    return $ret;
}

##
# Check the well-known site fields in this state
# $c: the TestContext
# $siteJson: the site JSON that contains the values for the well-known site fields
# return: 1 if check passed
sub checkWellKnown {
    my $self     = shift;
    my $c        = shift;
    my $siteJson = shift;

    my $ret = 1;
    my $response = $c->absGet( '/robots.txt' );
    if( exists( $siteJson->{wellknown}->{robotstxt} )) {
        $ret &= !exists( $c->mustStatus( $response, '200',                               'robots.txt' )->{error} );
        $ret &= !exists( $c->mustBe(     $response, $siteJson->{wellknown}->{robotstxt}, 'robots.txt' )->{error} );
    }
    # Currently the else is not true, because an app at root might serve this
    # } else {
    #     $ret &= !exists( $c->mustStatus( $response, '404', 'robots.txt' )->{error} );
    # }

    $response = $c->absGet( '/sitemap.xml' );
    if( exists( $siteJson->{wellknown}->{sitemapxml} )) {
        $ret &= !exists( $c->mustStatus( $response, '200',                                'sitemap.xml' )->{error} );
        $ret &= !exists( $c->mustBe(     $response, $siteJson->{wellknown}->{sitemapxml}, 'sitemap.xml' )->{error} );
    }
    # Currently the else is not true, because an app at root might serve this
    # } else {
    #     $ret &= !exists( $c->mustStatus( $response, '404', 'sitemap.xml' )->{error} );
    # }

    $response = $c->absGet( '/favicon.ico' );
    if( exists( $siteJson->{wellknown}->{faviconicobase64} )) {
        my $favicon = decode_base64( $siteJson->{wellknown}->{faviconicobase64} );
        $ret &= !exists( $c->mustStatus( $response, '200',   'favicon.ico' )->{error} );
        $ret &= !exists( $c->mustBe(     $response, $favicon, 'favicon.ico' )->{error} );
    }
    # Currently the else is not true, because an app at root might serve this
    # } else {
    #     $ret &= !exists( $c->mustStatus( $response, '404', 'favicon.ico' )->{error} );
    # }

    return $ret;
}

    
################################################################################

package UBOS::WebAppTest::StateTransition;

use base qw( UBOS::WebAppTest::StatesTransitions );
use fields;
use UBOS::Logging;

##
# Instantiate the StateTransition.
# $pars{name}: name of the state
# $pars{function}: subroutine to check this state
sub new {
    my $self     = shift;
    my %pars = @_;

    my $name     = $pars{name};
    my $function = $pars{transition};

    unless( $name ) {
        fatal( 'All StateTransitions must have a name.' );
    }
    if( ref( $name )) {
        fatal( 'A StateTransition\'s name must be a string.' );
    }
    unless( $function ) {
        fatal( 'All StateTransitions must have a transition function.' );
    }
    unless( ref( $function ) eq 'CODE' ) {
        fatal( 'A StateTransition\'s transition function must be a Perl subroutine.' );
    }

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $name, $function );

    return $self;
}

##
# Execute the state transition
# $c: the TestContext
# return: 1 if check passed
sub execute {
    my $self = shift;
    my $c    = shift;

    $c->clearHttpSession(); # always before a new StateTransition

    eval { &{$self->{function}}( $c ); };

    my $errors = $c->errorsAndClear;
    my $msg    = 'failed.';
    
    my $ret;
    if( $errors ) {
        $msg = 'failed.';
        $ret = 0;
    } elsif( $@ ) {
        $msg = $@;
        $ret = 0;
    } else {
        $ret = 1;
    }

    unless( $ret ) {
        error( 'StateTransition', $self->{name}, ':', $msg );
    }
        
    return $ret;
}

1;
