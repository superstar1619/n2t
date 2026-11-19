#!/usr/bin/perl -w 
use strict;
use v5.34;
use File::Spec::Functions qw(catfile);
use constant{
    C_ARITHMETIC => 0 ,
    C_PUSH => 1 ,
    C_POP => 2 ,
    C_LABEL => 3 ,
    C_GOTO => 4 ,
    C_IF => 5 ,
    C_FUNCTION => 6 ,
    C_RETURN => 7 ,
    C_CALL => 8
};

my $filename;
my $functionname = "Start";
my $prefile;

##############
# subroutine #
##############

sub Parser
{
    my $fh = shift;
    my $line;
    my $type;
    my $command;
    my @args;
    my $hasMoreLines = sub {
        return eof $fh ? 0 : 1;
    };
    my $advance = sub  {
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
    my $split_command = sub  {
        return ($command, @args) = split /\s+/, $line;
    };
    my $commandtype = sub  {
        if($command =~ m/add|sub|neg|eq|gt|lt|and|or|not/)
        {
            $type = C_ARITHMETIC;
        }
        elsif($command =~ m/push/)
        {
            $type = C_PUSH;
        }
        elsif($command =~ m/pop/)
        {
            $type = C_POP;
        }
        elsif($command =~ m/label/)
        {
            $type = C_LABEL;
        }
        elsif($command =~ m/if\-goto/)
        {
            $type = C_IF;
        }
        elsif($command =~ m/goto/)
        {
            $type = C_GOTO;
        }
        elsif($command =~ m/function/)
        {
            $type = C_FUNCTION;
        }
        elsif($command =~ m/call/)
        {
            $type = C_CALL;
        }
        elsif($command =~ m/return/)
        {
            $type = C_RETURN;
        }
    };
    my $arg1 = sub  {
        return $type == C_ARITHMETIC ? $command : $args[0];
    };
    my $arg2 = sub  {
        return $args[1];
    };
    my $closefile = sub  {
        close $fh;
        return;
    };
    return {
        "hasMoreLines" => $hasMoreLines,
        "advance" => $advance,
        "split_command" => $split_command,
        "commandtype" => $commandtype,
        "arg1" => $arg1,
        "arg2" => $arg2,
        "closefile" => $closefile
    };
}

sub WritePart {
    my $symbol;
    my $string;
    my $st=0;
    my %exist_map;
    my $sh;
    state $fret=0;
    my $clear = sub  {
        $string = '';
        open $sh, ">", \$string;
    };
    my $pop_R = sub {
        my $number = shift;
        $clear->();
        say {$sh} "\@SP";
        say {$sh} "AM=M-1";
        say {$sh} "D=M";
        say {$sh} "\@${number}";
        say {$sh} "M=D";
        return $string;
    };
    my $push_R = sub {
        my $number = shift;
        $clear->();
        say {$sh} "\@${number}";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        return $string;
    };
    my $init = sub {
        $clear->();
        say {$sh} "\@256";
        say {$sh} "D=A";
        say {$sh} "\@SP";
        say {$sh} "M=D";
        return $string;
    };
    my $simpleArith1 = sub {
        my $symbol = shift;
        $clear->();
        say {$sh} "\@13";
        say {$sh} "D=M";
        say {$sh} "\@14";
        say {$sh} "D=D${symbol}M";
        say {$sh} "\@15";
        say {$sh} "M=D";
        return $string;
    };
    my $simpleArith2 = sub {
        my $symbol = shift;
        $clear->();
        say {$sh} "\@14";
        say {$sh} "D=M";
        say {$sh} "\@15";
        say {$sh} "M=${symbol}D";
        return $string;
    };
    my $simpleArith3 = sub {
        state $sum=0;
        $sum++;
        my $symbol = shift;
        $clear->();
        say {$sh} "\@13";
        say {$sh} "D=M";
        say {$sh} "\@14";
        say {$sh} "D=D-M";
        say {$sh} "\@NEXT$sum";
        say {$sh} "D;$symbol";
        say {$sh} "D=0";
        say {$sh} "\@IGN$sum";
        say {$sh} "0;JMP";
        say {$sh} "(NEXT$sum)";
        say {$sh} "D=-1";
        say {$sh} "(IGN$sum)";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        return $string;
    };
    #local argument this that
    my $push1 = sub {
        my $symbol = shift;
        my $index = shift;
        $clear->();
        say {$sh} "\@$index";
        say {$sh} "D=A";
        say {$sh} "\@$symbol";
        say {$sh} "A=D+M";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        return $string;
    };
    my $pop1 = sub {
        my $symbol = shift;
        my $index = shift;
        $clear->();
        say {$sh} "\@$index";
        say {$sh} "D=A";
        say {$sh} "\@$symbol";
        say {$sh} "D=D+M";
        say {$sh} "\@13";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "AM=M-1";
        say {$sh} "D=M";
        say {$sh} "\@13";
        say {$sh} "A=M";
        say {$sh} "M=D";
        return $string;
    };
    # pointer 0/1
    my $push2 = sub {
        my $symbol = shift;
        $clear->();
        say {$sh} "\@$symbol";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        return $string;
    };
    my $pop2 = sub {
        my $symbol = shift;
        $clear->();
        say {$sh} "\@SP";
        say {$sh} "AM=M-1";
        say {$sh} "D=M";
        say {$sh} "\@$symbol";
        say {$sh} "M=D";
        return $string;
    };
    #temp i
    my $push3 = sub {
        my $index = shift;
        $clear->();
        $index += 5;
        say {$sh} "\@R$index";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        return $string;
    };
    my $pop3 = sub {
        my $index = shift;
        $clear->();
        $index += 5;
        say {$sh} "\@SP";
        say {$sh} "AM=M-1";
        say {$sh} "D=M";
        say {$sh} "\@R$index";
        say {$sh} "M=D";
        return $string;
    };
    #constant
    my $push4 = sub {
        my $index = shift;
        $clear->();
        say {$sh} "\@$index";
        say {$sh} "D=A";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        return $string;
    };
    #static
    my $get_static_var = sub {
        my $index = shift;
        if(!defined($exist_map{$index}))
        {
            $st++;
            $exist_map{$index}=$st;
        }
        return $exist_map{$index};
    };
    my $push5 = sub {
        my $index = shift;
        $index = $get_static_var->($index);
        $clear->();
        say {$sh} "\@${prefile}\.$index";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        return $string;
    };
    my $pop5 = sub {
        my $index = shift;
        $index = $get_static_var->($index);
        $clear->();
        say {$sh} "\@SP";
        say {$sh} "AM=M-1";
        say {$sh} "D=M";
        say {$sh} "\@${prefile}\.$index";
        say {$sh} "M=D";
        return $string;
    };
    my $write_label = sub {
        my $label = shift;
        $clear->();
        say {$sh} "(${functionname}\$$label)";
        return $string;
    };
    my $write_goto = sub {
        my $label = shift;
        $clear->();
        say {$sh} "\@${functionname}\$$label";
        say {$sh} "0;JMP";
        return $string;
    };
    my $write_if_goto = sub {
        my $label = shift;
        $clear->();
        say {$sh} "\@SP";
        say {$sh} "M=M-1";
        say {$sh} "A=M";
        say {$sh} "D=M";
        say {$sh} "\@${functionname}\$$label";
        say {$sh} "D;JNE";
        return $string;
    };
    my $write_func = sub {
        my $times = shift;
        $clear->();
        $fret=0;
        say {$sh} "(${functionname})";
        foreach (1..$times){
            say {$sh} "\@SP";
            say {$sh} "A=M";
            say {$sh} "M=0";
            say {$sh} "\@SP";
            say {$sh} "M=M+1";
        }
        return $string;
    };
    my $write_call = sub {
        my ($jf, $nargs) = @_;
        $clear->();
        $fret++;
        say {$sh} "\@$functionname\$ret\.$fret";
        say {$sh} "D=A";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";

        say {$sh} "\@LCL";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";

        say {$sh} "\@ARG";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        
        say {$sh} "\@THIS";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        
        say {$sh} "\@THAT";
        say {$sh} "D=M";
        say {$sh} "\@SP";
        say {$sh} "A=M";
        say {$sh} "M=D";
        say {$sh} "\@SP";
        say {$sh} "M=M+1";
        
        say {$sh} "\@SP";
        say {$sh} "D=M";
        say {$sh} "\@5";
        say {$sh} "D=D-A";
        say {$sh} "\@$nargs";
        say {$sh} "D=D-A";
        say {$sh} "\@ARG";
        say {$sh} "M=D";

        say {$sh} "\@SP";
        say {$sh} "D=M";
        say {$sh} "\@LCL";
        say {$sh} "M=D";

        say {$sh} "\@$jf";
        say {$sh} "0;JMP";
        say {$sh} "($functionname\$ret\.$fret)";
        return $string;
    };
    my $write_return = sub {
        $clear->();
        say {$sh} "\@LCL";
        say {$sh} "D=M";
        say {$sh} "\@13";
        say {$sh} "M=D";

        
        say {$sh} "\@5";
        say {$sh} "D=D-A";
        say {$sh} "A=D";
        say {$sh} "D=M";
        say {$sh} "\@14";
        say {$sh} "M=D";

        
        say {$sh} "\@SP";
        say {$sh} "M=M-1";
        say {$sh} "A=M";
        say {$sh} "D=M";
        say {$sh} "\@ARG";
        say {$sh} "A=M";
        say {$sh} "M=D";


        say {$sh} "\@ARG";
        say {$sh} "D=M";
        say {$sh} "D=D+1";
        say {$sh} "\@SP";
        say {$sh} "M=D";

        
        say {$sh} "\@13";
        say {$sh} "D=M";
        say {$sh} "D=D-1";
        say {$sh} "A=D";
        say {$sh} "D=M";
        say {$sh} "\@THAT";
        say {$sh} "M=D";

        
        say {$sh} "\@13";
        say {$sh} "D=M";
        say {$sh} "\@2";
        say {$sh} "A=D-A";
        say {$sh} "D=M";
        say {$sh} "\@THIS";
        say {$sh} "M=D";

        
        say {$sh} "\@13";
        say {$sh} "D=M";
        say {$sh} "\@3";
        say {$sh} "A=D-A";
        say {$sh} "D=M";
        say {$sh} "\@ARG";
        say {$sh} "M=D";

        
        say {$sh} "\@13";
        say {$sh} "D=M";
        say {$sh} "\@4";
        say {$sh} "A=D-A";
        say {$sh} "D=M";
        say {$sh} "\@LCL";
        say {$sh} "M=D";

        
        say {$sh} "\@14";
        say {$sh} "A=M";
        say {$sh} "0;JMP";

        return $string;
    };
    return {
        "pop_R" => $pop_R,
        "push_R" => $push_R,
        "init" => $init,
        "simpleArith1" => $simpleArith1,
        "simpleArith2" => $simpleArith2,
        "simpleArith3" => $simpleArith3,
        "push1" => $push1,
        "pop1" => $pop1,
        "push2" => $push2,
        "pop2" => $pop2,
        "push3" => $push3,
        "pop3" => $pop3,
        "push4" => $push4,
        "push5" => $push5,
        "pop5" => $pop5,
        "write_label" => $write_label,
        "write_goto" => $write_goto,
        "write_if_goto" => $write_if_goto,
        "write_func" => $write_func,
        "write_call" => $write_call,
        "write_return" => $write_return,
    };
}


sub CodeWriter {
    my $fh = shift;
    my $writepart = WritePart();
    my $writeInit = sub {
        print {$fh} $writepart->{"init"}->();
        print {$fh} $writepart->{"write_call"}->("Sys.init", "0");
        return ;
    };
    my $writeArithmetic = sub {
        my $arith = shift;
        my %map_table = qw'
            add + 
            sub - 
            and &
            or |
            neg -
            not !
            eq JEQ
            gt JGT
            lt JLT
        ';
        my @keys = qw'add sub and or neg not eq gt lt';
        my $count = 0;
        my $symbol;
        my $op;
        foreach $op (@keys)
        {
            $symbol = $map_table{$op};
            last if ($arith =~ m/$op/);
            $count++;
        }
        my $sg='';
        if($count<=3)
        {
            $sg .= $writepart->{"pop_R"}->(14);
            $sg .= $writepart->{"pop_R"}->(13);
            $sg .= $writepart->{"simpleArith1"}->($symbol);
            $sg .= $writepart->{"push_R"}->(15);
        }
        elsif($count<=5)
        {
            $sg .= $writepart->{"pop_R"}->(14);
            $sg .= $writepart->{"simpleArith2"}->($symbol);
            $sg .= $writepart->{"push_R"}->(15);
        }
        else
        {
            $sg .= $writepart->{"pop_R"}->(14);
            $sg .= $writepart->{"pop_R"}->(13);
            $sg .= $writepart->{"simpleArith3"}->($symbol);
        }
        print {$fh} $sg;
    };
    my $writePushPop = sub {
        my ($commandtype, $arg1, $arg2) = @_;
        my %map_table = qw'
            local LCL
            argument ARG
            this THIS
            that THAT
            pointer Pointer
            temp Temp
            constant Constant
            static Static
        ';
        my @keys = qw'local argument this that pointer temp constant static';
        my $count = 0;
        my $symbol;
        my $op;
        foreach $op (@keys)
        {
            $symbol = $map_table{$op};
            last if ($arg1 =~ m/$op/);
            $count++;
        }
        my $sg='';
        if($commandtype == C_PUSH)
        {
            if($count<=3)
            {
                $sg = $writepart->{"push1"}->($symbol, $arg2);
            }
            elsif($count == 4)
            {
                if($arg2 == 0)
                {
                    $sg = $writepart->{"push2"}->("THIS");
                }
                else
                {
                    $sg = $writepart->{"push2"}->("THAT");
                }
            }
            elsif($count == 5)
            {
                $sg = $writepart->{"push3"}->($arg2);
            }
            elsif($count == 6)
            {
                $sg = $writepart->{"push4"}->($arg2);
            }
            elsif($count == 7)
            {
                $sg = $writepart->{"push5"}->($arg2);
            }
        }
        elsif($commandtype == C_POP)
        {
            if($count<=3)
            {
                $sg = $writepart->{"pop1"}->($symbol, $arg2);
            }
            elsif($count == 4)
            {
                if($arg2 == 0)
                {
                    $sg = $writepart->{"pop2"}->("THIS");
                }
                else
                {
                    $sg = $writepart->{"pop2"}->("THAT");
                }
            }
            elsif($count == 5)
            {
                $sg = $writepart->{"pop3"}->($arg2);
            }
            elsif($count == 7)
            {
                $sg = $writepart->{"pop5"}->($arg2);
            }
        }
        print {$fh} $sg;
    };
    my $writeLabel = sub {
        my $label = shift;
        print {$fh} $writepart->{"write_label"}->($label);
    };
    my $writeGoto = sub {
        my $label = shift;
        print {$fh} $writepart->{"write_goto"}->($label);
    };
    my $writeIf = sub {
        my $label = shift;
        print {$fh} $writepart->{"write_if_goto"}->($label);
    };
    my $writeFunction = sub {
        my $times = shift;
        print {$fh} $writepart->{"write_func"}->($times);
    };
    my $writeCall = sub {
        my ($jf, $args) = @_;
        print {$fh} $writepart->{"write_call"}->($jf, $args);
    };
    my $writeReturn = sub {
        print {$fh} $writepart->{"write_return"}->();
    };
    my $closefile = sub {
        close $fh;
    };
    return {
        "writeInit" => $writeInit,
        "writeArithmetic" => $writeArithmetic,
        "writePushPop" => $writePushPop,
        "writeLabel" => $writeLabel,
        "writeGoto" => $writeGoto,
        "writeIf" => $writeIf,
        "writeFunction" => $writeFunction,
        "writeCall" => $writeCall,
        "writeReturn" => $writeReturn,
        "writeFunction" => $writeFunction,
        "writeCall" => $writeCall,
        "writeReturn" => $writeReturn,
        "closefile" => $closefile,
    };
}



########
# main #
########
open my $fsh, ">", "Main\.asm";
if(-d $ARGV[0])
{
    opendir my $dh, $ARGV[0];
    {
        my $cw = CodeWriter($fsh);
        $cw->{"writeInit"}->();
    }

    foreach $filename (readdir $dh)
    {
        if(!($filename =~ m/^.*\.vm$/))
        {
            next;
        }
        $filename =~ m/^(.*).vm$/;
        $prefile = $1;
        $functionname='';
        open my $fh, "<", catfile($ARGV[0],$filename);
        open my $sh, ">", \ my $string;

        while(<$fh>)
        {
            chomp;
            $_ =~ /^([^\/]*)/;
            $_ = $1;
            $_ =~ /(\S.*\S)/;
            my $sg=$1;
            if(!(defined $sg) || ($sg =~ /^\s*$/))
            {
                next;
            }
            say {$sh} $sg;
        }
        close $fh;
        undef $fh;

        print $string;

        open $sh, "<", \$string;

        my $parser = Parser($sh);

        my $cw = CodeWriter($fsh);

        while($_ = $parser->{"advance"}->())
        {
            say {$fsh} "\/\/$_";
            $parser->{"split_command"}->();
            my $type = $parser->{"commandtype"}->();
            if($type == C_ARITHMETIC)
            {
                $cw->{"writeArithmetic"}->($parser->{"arg1"}->());
            }
            elsif($type == C_PUSH || $type == C_POP)
            {
                $cw->{"writePushPop"}->($type, $parser->{"arg1"}->(), $parser->{"arg2"}->());
            }
            elsif($type == C_LABEL)
            {
                $cw->{"writeLabel"}->($parser->{"arg1"}->());
            }
            elsif($type == C_GOTO)
            {
                $cw->{"writeGoto"}->($parser->{"arg1"}->());
            }
            elsif($type == C_IF)
            {
                $cw->{"writeIf"}->($parser->{"arg1"}->());
            }
            elsif($type == C_FUNCTION)
            {
                $functionname = $parser->{"arg1"}->();
                $cw->{"writeFunction"}->($parser->{"arg2"}->());
            }
            elsif($type == C_CALL)
            {
                $cw->{"writeCall"}->($parser->{"arg1"}->(), $parser->{"arg2"}->());
            }
            elsif($type == C_RETURN)
            {
                $cw->{"writeReturn"}->();
            }
        }
        $parser->{"closefile"}->();
    }
}
else
{
    {
        my $cw = CodeWriter($fsh);
        $cw->{"writeInit"}->();
    }

    foreach $filename (@ARGV)
    {
        $filename =~ m/^(.*).vm$/;
        $prefile = $1;
        $functionname='';
        open my $fh, "<", $filename;
        open my $sh, ">", \ my $string;

        while(<$fh>)
        {
            chomp;
            $_ =~ /^([^\/]*)/;
            $_ = $1;
            $_ =~ /(\S.*\S)/;
            my $sg=$1;
            if(!(defined $sg) || ($sg =~ /^\s*$/))
            {
                next;
            }
            say {$sh} $sg;
        }
        close $fh;
        undef $fh;

        print $string;

        open $sh, "<", \$string;

        my $parser = Parser($sh);

        my $cw = CodeWriter($fsh);

        while($_ = $parser->{"advance"}->())
        {
            say {$fsh} "\/\/$_";
            $parser->{"split_command"}->();
            my $type = $parser->{"commandtype"}->();
            if($type == C_ARITHMETIC)
            {
                $cw->{"writeArithmetic"}->($parser->{"arg1"}->());
            }
            elsif($type == C_PUSH || $type == C_POP)
            {
                $cw->{"writePushPop"}->($type, $parser->{"arg1"}->(), $parser->{"arg2"}->());
            }
            elsif($type == C_LABEL)
            {
                $cw->{"writeLabel"}->($parser->{"arg1"}->());
            }
            elsif($type == C_GOTO)
            {
                $cw->{"writeGoto"}->($parser->{"arg1"}->());
            }
            elsif($type == C_IF)
            {
                $cw->{"writeIf"}->($parser->{"arg1"}->());
            }
            elsif($type == C_FUNCTION)
            {
                $functionname = $parser->{"arg1"}->();
                $cw->{"writeFunction"}->($parser->{"arg2"}->());
            }
            elsif($type == C_CALL)
            {
                $cw->{"writeCall"}->($parser->{"arg1"}->(), $parser->{"arg2"}->());
            }
            elsif($type == C_RETURN)
            {
                $cw->{"writeReturn"}->();
            }
        }
        $parser->{"closefile"}->();
    }
}

