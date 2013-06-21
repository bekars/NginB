#!/usr/bin/perl -w

package BMD::EXCEL;

use strict;
use utf8;
use Encode;
use autodie;
use Try::Tiny;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use Spreadsheet::ParseExcel;

sub new()
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
        'debug' => 0,
        'filename' => 'my_excel.xls',
        @_,
    };

    my $_excel = Spreadsheet::WriteExcel->new($self->{filename});
    $self->{excel} = $_excel;

    bless($self, $class);
    return $self;
}

sub add_sheet($)
{
    my $self = shift;
    my $name = shift;

    $name = decode('utf8', $name);
    return $self->{excel}->add_worksheet($name);
}

sub write
{
    my ($self, $sheet, $row, $col, $text, $color, $bgcolor, $align) = @_;
    my $format;

    $text = decode('utf8', $text);
    if ($color) {
        $format = $self->{excel}->add_format();
        $format->set_color($color);
        $format->set_bg_color($bgcolor) if ($bgcolor);
        $format->set_align($align) if ($align);
        $sheet->write($row, $col, $text, $format);
    } else {
        $sheet->write($row, $col, $text);
    }
}

sub set_selection_sheet($$$)
{
    my ($self, $sheet, $row, $col) = @_;
    $sheet->set_selection($row, $col);
}

sub set_column_width($$$$)
{
    my ($self, $sheet, $from, $to, $width) = @_;
    $sheet->set_column($from, $to, $width);
}

sub destroy()
{
    my $self = shift;
    $self->{excel}->close();
}

sub BEGIN
{
}

sub DESTROY
{
}


1;

# vim: ts=4:sw=4:et

