#!/usr/bin/perl
#
# A scaffold for Python app packages on UBOS.
#
# This file is part of ubos-scaffold.
# (C) 2017 Indie Computing Corp.
#
# ubos-scaffold is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ubos-scaffold is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ubos-scaffold.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package UBOS::Scaffold::Scaffolds::PythonApp;

use UBOS::Scaffold::ScaffoldUtils;

##
# Declare which parameters should be provided for this scaffold.
sub pars {
    return [
        {
            'name'        => 'name',
            'description' => <<DESC
Name of the package
DESC
        },
        {
            'name'        => 'developer',
            'description' => <<DESC
URL of the developer, such as your company URL
DESC
        },
        {
            'name'        => 'url',
            'description' => <<DESC
URL of the package, such as a product information page on your company website
DESC
        },
        {
            'name'        => 'description',
            'description' => <<DESC
One-line description of your package, which will be shown to the user when
they ask pacman about your package (-i flag to pacman)
DESC
        },
        {
            'name'        => 'license',
            'description' => <<DESC
License of your package, such as GPL, Apache, or Proprietary
DESC
        }
    ];
}

##
# Do the generation
# $pars: the parameters to use
# $dir: the output directory
sub generate {
    my $pars = shift;
    my $dir  = shift;

    my $packageName = $pars->{name};
    unless( $dir ) {
        $dir = $packageName;
        UBOS::Scaffold::ScaffoldUtils::ensurePackageDirectory( $dir );
    }

    my $pkgBuild = <<END;
#
# PKGBUILD for package $pars->{name}, generated by ubos-scaffold.
# For the syntax of this file, please refer to the description on the
# Arch Linux wiki here: https://wiki.archlinux.org/index.php/PKGBUILD
#

developer='$pars->{developer}'
url='$pars->{url}'
maintainer='\${developer}'
pkgname='$packageName'
pkgver=0.1
pkgrel=1
pkgdesc='$pars->{description}'
arch=('any')
license=('$pars->{license}')
depends=(
    # Insert your UBOS package dependencies here as a bash array, like this:
    #     'python' 'python-lxml' 'python-pillow' 'python-psycopg2' 'python-setuptools'
    # and close with a parenthesis
)
makedepends=(
    # Insert the UBOS build-time package dependencies here, like this:
    #     'python-virtualenv')
)

backup=(
    # List any config files your package uses that should NOT be overridden
    # upon the next package update if the user has modified them.
)
source=(
    # Insert URLs to the source(s) of your code here, usually one or more tar files
    # or such, like this:
    #     "https://download.nextcloud.com/server/releases/nextcloud-\${pkgver}.tar.bz2"
)
sha512sums=(
    # List the checksums for one source at a time, same sequence as the in
    # the sources array, like this:
    #     '1c1e59d3733d4c1073c19f54c8eda48f71a7f9e8db74db7ab761fcd950445f7541bce5d9ac800238ab7099ff760cb51bd59b7426020128873fa166870c58f125'
)

build() {
    # Insert your python build commands here, like this:
    #
    #     cd "\${srcdir}/\${pkgname}-\${pkgver}"
    #
    #     [ -d site-packages ] || mkdir site-packages
    #     PYTHONPATH=\$(pwd)/site-packages python2 setup.py develop --verbose --install-dir \$(pwd)/site-packages
}

package() {
# Manifest
    mkdir -p \${pkgdir}/var/lib/ubos/manifests
    install -m0644 \${startdir}/ubos-manifest.json \${pkgdir}/var/lib/ubos/manifests/\${pkgname}.json

# Icons
    mkdir -p \${pkgdir}/srv/http/_appicons/\${pkgname}
    install -m644 \${startdir}/appicons/{72x72,144x144}.png \${pkgdir}/srv/http/_appicons/\${pkgname}/

# Data
    mkdir -p \${pkgdir}/var/lib/\${pkgname}

# Code
    mkdir -p \${pkgdir}/usr/share/\${pkgname}
    # install your code here, such as:
    #     install -m0755 \${startdir}/my-\${pkgname}-script \${pkgdir}/usr/bin/
    #     cp -dr --no-preserve=ownership \${startdir}/src/\${pkgname}-\${pkgver}/* \${pkgdir}/usr/share/\${pkgname}/

# Configuration from templates
    mkdir -p \${pkgdir}/usr/share/\${pkgname}/tmpl
    install -m644 \${startdir}/tmpl/{wsgi.py,$pars->{name}.ini,htaccess}.tmpl \${pkgdir}/usr/share/{pkgname}/tmpl/

# Celery service
    mkdir -p \${pkgdir}/usr/lib/systemd/system
    install -m755 \${startdir}/systemd/$pars->{name}-celeryd\@.service \${pkgdir}/usr/lib/systemd/system/
}
END

    my $manifest = <<END;
{
    "type" : "app",

    "roles" : {
        "apache2" : {
            "defaultcontext" : "/$pars->{name}",
            "depends" : [
                "mod_wsgi2"
            ],
            "apache2modules" : [
                "wsgi"
            ],
            "appconfigitems" : [
                {
                    "type"  : "directory",
                    "name"  : "\${appconfig.datadir}",
                    "uname" : "\${apache2.uname}",
                    "gname" : "\${apache2.gname}"
                },
                {
                    "type"  : "directory",
                    "names"  : [
                        "/var/cache/\${appconfig.appconfigid}",
                        "/var/cache/\${appconfig.appconfigid}/egg-cache",
                    ],
                    "uname" : "\${apache2.uname}",
                    "gname" : "\${apache2.gname}"
                },
                {
                    "type"         : "file",
                    "name"         : "\${appconfig.apache2.dir}/wsgi.py",
                    "template"     : "tmpl/wsgi.py.tmpl",
                    "templatelang" : "varsubst"
                },
                {
                    "type"         : "file",
                    "name"         : "\${appconfig.datadir}/$pars->{name}.ini",
                    "template"     : "tmpl/$pars->{name}.ini.tmpl",
                    "templatelang" : "varsubst"
                },
                {
                    "type"         : "file",
                    "name"         : "\${appconfig.apache2.appconfigfragmentfile}",
                    "template"     : "tmpl/htaccess.tmpl",
                    "templatelang" : "varsubst"
                },
                {
                    "type"         : "systemd-service",
                    "name"         : "$pars->{name}-celeryd\@\${appconfig.appconfigid}"
                }
            ]
        },
        "postgresql" : {
            "appconfigitems" : [
                {
                    "type"       : "database",
                    "name"       : "maindb",
                    "retentionpolicy"  : "keep",
                    "retentionbucket"  : "maindb",
                    "privileges" : "all privileges"
                }
            ]
        }
    }
}
END

    my $htAccessTmpl = <<END;
Alias \${appconfig.context}/static/ \${package.codedir}/web/static/

WSGIScriptAlias \${appconfig.contextorslash} \${appconfig.apache2.dir}/wsgi.py

WSGIPassAuthorization On
WSGIDaemonProcess $pars->{name}-\${appconfig.appconfigid} processes=2 threads=10 \
       umask=0007 inactivity-timeout=900 maximum-requests=1000 \
       python-path=\${package.codedir}
WSGIProcessGroup $pars->{name}-\${appconfig.appconfigid}

# Can't do this because there may be more than one WSGI app:
# WSGIApplicationGroup %{GLOBAL}

<Directory "\${package.codedir}/static">
    Require all granted
</Directory>

END

    my $wsgiTmpl = <<END;
#!\${package.codedir}/bin/python2

import os
os.environ['PYTHON_EGG_CACHE'] = '/var/cache/\${appconfig.appconfigid}/egg-cache'

import site
site.addsitedir('\${package.codedir}/site-packages')

from paste.deploy import loadapp

CONFIG_PATH = '\${appconfig.datadir}/paste.ini'
application = loadapp('config:' + CONFIG_PATH)

END

    my $appTmpl = <<END;
[$pars->{name}]
sql_engine = postgresql://\${appconfig.postgresql.dbuser.maindb}:\${appconfig.postgresql.dbusercredential.maindb}\@\${appconfig.postgresql.dbhost.maindb}:\${appconfig.postgresql.dbport.maindb}/\${appconfig.postgresql.dbname.maindb}
END

    my $pasteTmpl = <<END;
[DEFAULT]
# Set to true to enable web-based debugging messages and etc.
debug = true

[pipeline:main]
pipeline = errors routing

[app:$pars->{name}]
use = egg:$pars->{name}#app
config = %(here)s/$pars->{name}.ini

END

    UBOS::Utils::mkdir( "$dir/appicons" );
    UBOS::Utils::mkdir( "$dir/tmpl" );

    UBOS::Utils::saveFile( "$dir/PKGBUILD",                $pkgBuild,     0644 );
    UBOS::Utils::saveFile( "$dir/ubos-manifest.json",      $manifest,     0644 );

    UBOS::Scaffold::ScaffoldUtils::copyIcons( "$dir/appicons" );

    UBOS::Utils::saveFile( "$dir/tmpl/$pars->{name}.tmpl", $appTmpl,      0644 );
    UBOS::Utils::saveFile( "$dir/tmpl/htaccess.tmpl",      $htAccessTmpl, 0644 );
    UBOS::Utils::saveFile( "$dir/tmpl/paste.ini.tmpl",     $pasteTmpl,    0644 );
    UBOS::Utils::saveFile( "$dir/tmpl/wsgi.py.tmpl",       $wsgiTmpl,     0644 );
}

##
# Return help text.
# return: help text
sub help {
    return 'Python app using paste and WSGI';
}

1;
