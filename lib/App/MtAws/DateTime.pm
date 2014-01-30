# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2014  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

package App::MtAws::DateTime;

our $VERSION = '1.112';

use strict;
use warnings;
use utf8;

use POSIX;
use Time::Local;
use App::MtAws::Utils;

require Exporter;
use base qw/Exporter/;

our @EXPORT = qw/epoch_to_iso8601 iso8601_to_epoch/;

#
# Implementing this as I don't want to have non-core dependencies
#

use constant SEC_PER_DAY => 86400;
use constant YEARS_PER_CENTURY => 100;
use constant DAYS_PER_YEAR => 365;

sub is_leap
{
	($_[0] % 400 ==0) || ( ($_[0] % 100 != 0) && ($_[0] % 4 == 0) )
}

our %_leap_cache;

sub number_of_leap_years
{
	my ($y1, $y2, $m) = @_;
	$_leap_cache{$y1,$y2, ($m < 3 ? '0' : '1') } ||= do {
		my $cnt = 0;
		for ($y1+1..$y2-1) {
			$cnt++ if is_leap($_);
		}
		$cnt++ if ($m < 3 ) && is_leap($y1);
		$cnt++ if ($m >= 3) && is_leap($y2);
		$cnt;
	}
}

sub epoch_to_iso8601
{
	my ($time) = @_;
	return if $time < -30610224000 || $time > 253402300799;
	strftime("%Y%m%dT%H%M%SZ", gmtime($time));
}

sub iso8601_to_epoch
{
	my ($str) = @_;
	return unless $str =~ /^\s*(\d{4})[\-\s]*(\d{2})[\-\s]*(\d{2})\s*T\s*(\d{2})[\:\s]*(\d{2})[\:\s]*(\d{2})[\,\.\d]{0,10}\s*Z\s*$/i; # _some_ iso8601 support for now
	my ($year, $month, $day, $hour, $min, $sec) = ($1,$2,$3,$4,$5,$6);
	return if $year < 1000;
	my $leap = 0;
	$leap = $sec - 59, $sec = 59 if ($sec == 60 || $sec == 61);

	# some Y2038 bugs in timegm, workaround it. we need consistency across platforms and perl versions when parsing vault metadata
	if (!is_y2038_supported && (($year <= 1901) || ($year >= 2038)) ) {
		while ($year <= 1901) {
			$leap -= number_of_leap_years($year, $year + YEARS_PER_CENTURY, $month)*SEC_PER_DAY;
			$year += YEARS_PER_CENTURY;
			$leap -= YEARS_PER_CENTURY*SEC_PER_DAY*DAYS_PER_YEAR;
		}
		while ($year >= 2038) {
			$leap += number_of_leap_years($year - YEARS_PER_CENTURY, $year, $month)*SEC_PER_DAY;
			$year -= YEARS_PER_CENTURY;
			$leap += YEARS_PER_CENTURY*SEC_PER_DAY*DAYS_PER_YEAR;
		}
	}
	eval { timegm($sec,$min,$hour,$day,$month - 1,$year) + $leap };
}

1;

__END__
