#!/usr/bin/env perl
use strict;
use warnings;

use File::Spec::Functions qw(catfile catdir curdir);

my ($nargs) = $#ARGV + 1;
if ( glob($nargs) >= 3 ) {
    print("Usage: $0 [target] [subtarget]\n\n");
    print(
"This program will build the optimized version of OpenWrt for the selected [target].\n"
    );
    exit 1;
}

use constant {
    DIST              => 'NoTengoBattery',
    DOWNLOAD_ROOT_URL => 'downloads.notengobattery.com',
    ISSUES            => 'issues',
    LINUX_TARGET      => 'target/linux',
    PROJECTS          => 'projects',
    PROJECT_NAME      => "openwrt-" . $ARGV[0],
    RELEASES          => 'releases',
    RELEASE_NOTES     => 'release-notes',
    ROOT_URL          => 'notengobattery.com',
    TARGET            => $ARGV[0],
    SUBTARGET         => $ARGV[1] || 'generic',
    VERSION           => $ENV{VER} || 'v4.0.0'
};

my ($kconfgPathPatternSub) =
  sprintf '*/%s/%s/*config-*.*', TARGET, SUBTARGET;
my ($kconfgPathPatternMain) =
  sprintf '*/%s/*config-*.*', TARGET;
my ($releaseURL) =
  'https://' . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION );
my ($issuesURL) =
  'https://'
  . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION, ISSUES );
my ($downloadURL) =
  'https://' . catdir( DOWNLOAD_ROOT_URL, PROJECTS, 'openwrt-' . VERSION );
my ($supportURL) =
  'https://'
  . catdir( ROOT_URL, PROJECTS, PROJECT_NAME, RELEASES, VERSION,
    RELEASE_NOTES );
my ($curDir)            = curdir();
my ($dSeed)             = catdir( glob($curDir),    'seeds' );
my ($dScripts)          = catdir( glob($curDir),    'scripts' );
my ($linuxTarget)       = catdir( glob($curDir),    LINUX_TARGET );
my ($fConfig)           = catfile( glob($curDir),   '.config' );
my ($fConfigSeed)       = catfile( glob($curDir),   'config.seed' );
my ($fCommonSeed)       = catfile( glob($dSeed),    'common.seed' );
my ($fFeaturesSeed)     = catfile( glob($dSeed),    'features.seed' );
my ($fKernelCommonSeed) = catfile( glob($dSeed),    'common-kernel.seed' );
my ($fKernelSeed)       = catfile( glob($dSeed),    'kernel.seed' );
my ($fKernelTargetSeed) = catfile( glob($dSeed),    TARGET . '-kernel.seed' );
my ($fPackagesSeed)     = catfile( glob($dSeed),    ($ENV{PKGS} || 'packages') . '.seed' );
my ($fSubTargetSeed)    = catfile( glob($dSeed),    TARGET . '-' . SUBTARGET . '.seed' );
my ($fTargetSeed)       = catfile( glob($dSeed),    TARGET . '.seed' );
my ($fScriptDiff)       = catfile( glob($dScripts), 'diffconfig.sh' );

my ($kconfg) =
  readpipe( sprintf "find %s -type f -path '%s' | head -n 1", $linuxTarget, $kconfgPathPatternSub );
if (!$kconfg) {
  ($kconfg) =
    readpipe( sprintf "find %s -type f -path '%s' | head -n 1", $linuxTarget, $kconfgPathPatternMain );
}

open( COMMON_SEED, "<", glob($fCommonSeed) )
  or die qq(Could not open file '$fCommonSeed' (COMMON_SEED): $!);
open( FEATURES_SEED, "<", glob($fFeaturesSeed) )
  or die qq(Could not open file '$fFeaturesSeed' (FEATURES_SEED): $!);
open( KERNEL_SEED, "<", glob($fKernelSeed) )
  or die qq(Could not open file '$fKernelSeed' (KERNEL_SEED): $!);
open( TARGET_SEED, "<", glob($fTargetSeed) )
  or die qq(Could not open file '$fTargetSeed' (TARGET_SEED): $!);
open( SUBTARGET_SEED, "<", glob($fSubTargetSeed) );
open( PACKAGE_SEED, "<", glob($fPackagesSeed) )
  or die qq(Could not open file '$fPackagesSeed' (PACKAGE_SEED): $!);
open( KERNEL_COMMON_SEED, "<", glob($fKernelCommonSeed) )
  or die qq(Could not open file '$fKernelCommonSeed' (KERNEL_COMMON_SEED): $!);
open( KERNEL_TARGET_SEED, "<", glob($fKernelTargetSeed) )
  or die qq(Could not open file '$fKernelTargetSeed' (KERNEL_TARGET_SEED): $!);
open( CONFIG_SEED, ">", glob($fConfigSeed) )
  or die qq(Could not open file '$fConfigSeed' (CONFIG_SEED): $!);
open( CONFIG, ">", glob($fConfig) )
  or die qq(Could not open file '$fConfig' (CONFIG): $!);
open( KCONFIG, ">>", glob($kconfg) )
  or die qq(Could not open file '$kconfg' (KCONFIG): $!);

printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_BUG_URL",     glob($issuesURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_DIST",        DIST );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_HOME_URL",    glob($releaseURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_NUMBER",      VERSION );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_REPO",        glob($downloadURL) );
printf( CONFIG "%s=\"%s\"\n", "CONFIG_VERSION_SUPPORT_URL", glob($supportURL) );
print( CONFIG <COMMON_SEED>,    "\n" );
print( CONFIG <FEATURES_SEED>,  "\n" );
print( CONFIG <KERNEL_SEED>,    "\n" );
print( CONFIG <TARGET_SEED>,    "\n" );
print( CONFIG <SUBTARGET_SEED>, "\n" );
print( CONFIG <PACKAGE_SEED>,   "\n" );
close(CONFIG);

print( KCONFIG <KERNEL_COMMON_SEED>, "\n" );
print( KCONFIG <KERNEL_TARGET_SEED>, "\n" );
close(KCONFIG);

system("./scripts/feeds update -a");
system("./scripts/feeds install -a");
system("make -j4 defconfig");
system("make -j4 kernel_oldconfig");
system("rm -rf ./bin");
print( CONFIG_SEED readpipe("$fScriptDiff") );

print("\n\nProject configured. Now is a good moment to build.\n")
