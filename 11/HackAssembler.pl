#!/usr/bin/perl -w

use v5.34;

use strict;

use constant A_INSTRUCTION => 0;
use constant C_INSTRUCTION => 1;
use constant L_INSTRUCTION => 2;


sub Parser {
    my $fh = shift;
    my $line;
    my $type;
    my $hasMoreLines = sub {
        if(eof $fh)
        {
            return 0;
        }
        else
        {
            return 1;
        }
    };
    my $advance = sub {
        if($hasMoreLines->())
        {
            chomp($line = <$fh>);
            return $line;
        }
        else
        {
            return undef;
        }
    };
    my $instructionType = sub  {
        if($line =~ m/^@/)
        {
            return $type = A_INSTRUCTION;
        }
        elsif($line =~ m/^\(.*\)$/)
        {
            return $type = L_INSTRUCTION;
        }
        else
        {
            return $type = C_INSTRUCTION;
        }
    };
    my $symbol = sub  {
        if($type == L_INSTRUCTION)
        {
            $line =~ m/^\((.*)\)$/;
            return $1;
        }
        elsif($type == A_INSTRUCTION)
        {
            $line =~ m/^@(.*)$/;
            return $1;
        }
    };
    my $dcj = sub  {
        if($type == C_INSTRUCTION)
        {
            $line =~ m/^(?:([^=]*)=)?([^=;]*)(?:;(.*))?$/;
            return ($1, $2, $3);
        }
    };

    return {"hasMoreLines" => $hasMoreLines, 
            "advance" => $advance, 
            "instructionType" => $instructionType,
            "symbol" => $symbol,
            "dcj" => $dcj};
}


sub symboltable {
    my %hash = qw(SP  0  LCL  1  ARG  2  THIS  3  THAT  4  SCREEN  16384  KBD  24576 );
    foreach (0..15){
        $hash{'R'.$_} = $_;
    }
    my $addEntry = sub {
        my ($symbol, $address) = @_;
        $hash{$symbol} = $address;
    };
    my $contains = sub {
        my $symbol = shift;
        return exists $hash{$symbol};
    };
    my $getAddress = sub  {
        my $symbol = shift;
        return $hash{$symbol};
    };
    my $print_symboltable = sub {
        
        while(my($key, $value) = each %hash)
        {
            print "$key => $value \n";
        }
    };
    return {"addEntry" => $addEntry, 
            "contains" => $contains, 
            "getAddress" => $getAddress,
            "print_symboltable" => $print_symboltable};
}

sub Code{
    my $type;
    my $encode;
    my %dest_hash = qw(null 000 M 001 D 010 DM 011 A 100 AM 101 AD 110 ADM 111);
    my %comp_hash = qw(0 0101010 1 0111111 
                  -1 0111010 D 0001100 
                  A 0110000 M 1110000
                  !D 0001101 !A 0110001
                  !M 1110001 -D 0001111
                  -A 0110011 -M 1110011
                  D+1 0011111 A+1 0110111
                  M+1 1110111 D-1 0001110
                  A-1 0110010 M-1 1110010
                  D+A 0000010 D+M 1000010
                  D-A 0010011 D-M 1010011
                  A-D 0000111 M-D 1000111
                  D&A 0000000 D&M 1000000
                  D|A 0010101 D|M 1010101);
    my %jump_hash = qw(null 000 JGT 001 JEQ 010 JGE 011 JLT 100 JNE 101 JLE 110 JMP 111);
    my $set_type = sub {
        $type = shift;
        $encode = "";
        return ;
    };
    my $EncodeProcess = sub {
        if($type == A_INSTRUCTION)
        {
            my $symbol = shift;
            $encode = "0";
            foreach (reverse 0..14)
            {
                $encode .= (($symbol >> $_) & 1) ? 1 : 0;
            }
        }
        else
        {
            $encode = "111";
            my ($dest, $comp, $jump) = @_;
            $encode .= $comp_hash{$comp};
            if(!(defined $dest) || $dest eq "")
            {
                $encode .= "000";
            }
            else
            {
                $encode .= ($dest =~ m/A/) ? 1 : 0;
                $encode .= ($dest =~ m/D/) ? 1 : 0;
                $encode .= ($dest =~ m/M/) ? 1 : 0;
            }

            if(!(defined $jump) || $jump eq "")
            {
                $jump = "null";
            }
            
            $encode .= $jump_hash{$jump};
        }
        return $encode;
    };
    return {"set_type" => $set_type, "EncodeProcess" => $EncodeProcess};
}


# main


$ARGV[0] =~ m/^(.*).asm$/;
my $filename = $1 . ".hack";

my $string;

open my $sh, ">", \$string;

while(<>)
{
    chomp;
    $_ =~ s/\s//g;
    $_ =~ m/([^\/]*)/;
    $_ = $1;
    if(!(defined $_) || $_ eq '')
    {
        next;
    }
    my $pattern = '//';
    if(m/^\Q$pattern\E/ )
    {
        next;
    }
    say {$sh} $_;
}
print $string;
print "\n";

close $sh;

open $sh, "<", \$string;

open my $fsh, ">", \ my $fstring;

my $parser = Parser($sh);
my $st = symboltable();

my $total_lines = -1;
my $cite_symbol = 15;

while($_ = $parser->{"advance"}->())
{
    my $type = $parser->{"instructionType"}->();
    my $symbol;
    
    if($type == L_INSTRUCTION)
    {
        $symbol = $parser->{"symbol"}->();
        $st->{"addEntry"}->($symbol, $total_lines + 1);
    }
    else
    {
        $total_lines++;
        print {$fsh} "$_\n";
    }
}

# print $fstring;
# print "\n";
# print $st->{"print_symboltable"}->();

$string = "";

open $sh, ">", \$string;

open $fsh, "<", \ $fstring;

$parser = Parser($fsh);

while($_ = $parser->{"advance"}->())
{
    my $type = $parser->{"instructionType"}->();
    my $symbol;
    
    if($type == A_INSTRUCTION)
    {
        $symbol = $parser->{"symbol"}->();
        if(!($symbol =~ m/^[0-9]*$/))
        {
            if(!$st->{"contains"}->($symbol))
            {
                $cite_symbol ++;
                $st->{"addEntry"}->($symbol, $cite_symbol);
            }
            $symbol = $st->{"getAddress"}->($symbol);
        }
        say {$sh} "\@$symbol";
    }
    elsif($type == C_INSTRUCTION)
    {
        say {$sh} $_;
    }
}

undef $fsh;
undef $fstring;

open $sh, "<", \$string;
open my $fh, ">", $filename;

# print $filename;

$parser = Parser($sh);

my $code = Code();

my $first_line = 0;
while($_ = $parser->{"advance"}->())
{
    my $type = $parser->{"instructionType"}->();
    my $symbol;
    $code->{"set_type"}->($type);
    my $encode;
    if($type == A_INSTRUCTION)
    {
        $symbol = $parser->{"symbol"}->();
        $encode = $code->{"EncodeProcess"}->($symbol);
    }
    elsif($type == C_INSTRUCTION)
    {
        $encode = $code->{"EncodeProcess"}->($parser->{"dcj"}->());
    }
    if($first_line)
    {
        print {$fh} "\n$encode";
    }
    else
    {
        print {$fh} $encode;
        $first_line = 1;
    }
}