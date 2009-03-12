use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::SimpleScan::Plugin::LinkCheck',
    AUTHOR              => 'Joe McMahon <mcmahon@yahoo-inc.com>',
    VERSION_FROM        => 'lib/App/SimpleScan/Plugin/LinkCheck.pm',
    ABSTRACT_FROM       => 'lib/App/SimpleScan/Plugin/LinkCheck.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'App::SimpleScan' => 0,
        'Scalar::Util' => 0,
        'Text::Balanced' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-SimpleScan-Plugin-LinkCheck-*' },
);

sub MY::postamble {
  return <<'MAKE_FRAG';
yman: *.3
	cd build && pod2man ../lib/App/SimpleScan/Plugin/LinkCheck.pm > "../man/man3/App::SimpleScan::Plugin::LinkCheck.3"

yinst: *.yicf
	cd build && yinst_create *.yicf

ydist: yman yinst *.tgz
	cd build && dist_install *.tgz

MAKE_FRAG
    }
