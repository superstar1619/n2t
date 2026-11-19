#!/usr/bin/perl -w
use strict;
use v5.34;

use File::Spec::Functions qw(catfile);
use File::Basename qw(fileparse basename dirname);

use constant {
    KEYWORD => "keyword",
    SYMBOL => "symbol",
    INDENTIFIER => "identifier",
    INT_CONST => "integerConstant",
    STRING_CONST => "stringConstant",
};

use constant {
    STATIC => "static",
    FIELD => "this",
    ARG => "argument",
    VAR => "local",
    NONE => "none",
};

my $dr = '.';

##############
# subroutine #
##############

sub file_sub {
    my ($pattern, @source) = @_;
    my $filelists = [];
    if(-d $source[0])
    {
        $dr = $source[0];
        opendir my $dh, $source[0];
        foreach (readdir $dh){
            if(/$pattern/)
            {
                push @$filelists, [catfile($source[0], $_), catfile($dr, $_ =~ s/${pattern}$/T.xml/r), catfile($dr, $_ =~ s/${pattern}$/.xml/r), catfile($dr, $_ =~ s/${pattern}$/.vm/r)];
            }
        }
    }
    else
    {
        foreach (@source){
            if(/$pattern/)
            {
                push @$filelists, [$_, catfile($dr, (basename $_) =~ s/${pattern}$/T.xml/r), catfile($dr, (basename $_) =~ s/${pattern}$/.xml/r) , catfile($dr, (basename $_) =~ s/${pattern}$/.vm/r) ];
            }
        }
    }
    return $filelists;
}

sub ign_blank {
    my $fh = shift;
    open my $sh, ">", \ my $string;
    while(<$fh>)
    {
        chomp;
        # say "$_ ";
        $_ =~ s/\/\/.*/ /;
        print {$sh} "$_ ";
        # say "$_ ";
    }
    close $sh;
    $string =~ s/\/\*\*?.*?\*\// /g;
    $string .= ' ';
    return $string;
}

sub JackTokenizer {
    my $fs = shift;
    my $keyword = qr/class|constructor|function|method|field|static|var|int|char|boolean|void|true|false|null|this|let|do|if|else|while|return/;
    my $symbol = qr/\{|\}|\(|\)|\[|\]|\.|\,|\;|\+|\-|\*|\/|\&|\||\<|\>|\=|\~/;
    my $number = qr/\d+/;
    my $string = qr/[^\"]*/;
    my $indentifier = qr/[\_a-zA-Z]{1}[\_a-zA-Z\d]*/;
    my $tokenlists = [];
    while($fs ne "")
    {
        my $pattern;
        $fs =~ s/^\s+//;
        last if $fs eq "";
        
        if($fs =~ m/^($keyword)[^\_a-zA-Z\d]/)
        {
            push @$tokenlists, [$1, KEYWORD];   
        }
        elsif($fs =~ m/^($symbol)/)
        {
            push @$tokenlists, [$1, SYMBOL]; 
        }
        elsif($fs =~ m/^($number)/)
        {
            push @$tokenlists, [$1, INT_CONST]; 
        }
        elsif($fs =~ m/^(\"($string)\")/)
        {
            push @$tokenlists, [$2, STRING_CONST];
        }
        elsif($fs =~ m/^($indentifier)/)
        {
            push @$tokenlists, [$1, INDENTIFIER]; 
        }

        if(!(defined $1) || $1 eq "")
        {
            print $fs;
        }
        else
        {
            $pattern = qr/\Q$1\E/;
            $fs =~ s/^$pattern//;
        }
    }
    return $tokenlists;
}

sub output_token {
    my $fh = shift;
    my $tokenlists = shift;
    say {$fh}"<tokens>";
    foreach (@$tokenlists){
        print {$fh}"<$_->[1]>";
        if($_->[0] eq '<')
        {
            print {$fh}" \&lt; ";
        }
        elsif($_->[0] eq '>')
        {
            print {$fh}" \&gt; ";
        }
        elsif($_->[0] eq '&')
        {
            print {$fh}" \&amp; ";
        }
        else
        {
            print {$fh}" $_->[0] ";
        }
        print {$fh}"<\/$_->[1]>";
        print {$fh}"\n";
    }
    say {$fh}"<\/tokens>";
}

sub SymbolTable {
    my $symboltable = [{}, {}];
    my $count = {};
    my $reset_class = sub {
        $count->{"static"} = 0;
        $count->{"this"} = 0;
        $count->{"argument"} = 0;
        $count->{"local"} = 0;
        $symboltable =  [{}, {}];
    };
    my $reset_subroutine = sub {
        $count->{"argument"} = 0;
        $count->{"local"} = 0;
        $symboltable->[1] = {};
    }; 
    my $define = sub {
        my ($name, $type, $kind) = @_;
        my $num = $count->{$kind}++;
        if($kind eq STATIC || $kind eq FIELD)
        {
            $symboltable->[0]->{$name} = [$kind, $type, $num];
        }
        elsif($kind eq ARG || $kind eq VAR)
        {
            $symboltable->[1]->{$name} = [$kind, $type, $num];
        }
        else
        {
            die "define NONE kind!\n";
        }
    };
    my $varCount = sub {
        my $kind = shift;
        if($kind eq ARG || $kind eq VAR || $kind eq STATIC || $kind eq FIELD)
        {
            return $count->{$kind};
        }
        else
        {
            return -1;
        }
    };
    my $kindOf = sub {
        my $name = shift;
        if(defined $symboltable->[1]->{$name})
        {
            return $symboltable->[1]->{$name}->[0];
        }
        elsif(defined $symboltable->[0]->{$name})
        {
            return $symboltable->[0]->{$name}->[0];
        }
        else
        {
            return NONE;
        }
    };
    my $typeOf = sub {
        my $name = shift;
        if(defined $symboltable->[1]->{$name})
        {
            return $symboltable->[1]->{$name}->[1];
        }
        elsif(defined $symboltable->[0]->{$name})
        {
            return $symboltable->[0]->{$name}->[1];
        }
    };
    my $indexOf = sub {
        my $name = shift;
        if(defined $symboltable->[1]->{$name})
        {
            return $symboltable->[1]->{$name}->[2];
        }
        elsif(defined $symboltable->[0]->{$name})
        {
            return $symboltable->[0]->{$name}->[2];
        }
    };
    return {
        "reset_class" => $reset_class,
        "reset_subroutine" => $reset_subroutine,
        "define" => $define,
        "varCount" => $varCount,
        "kindOf" => $kindOf,
        "typeOf" => $typeOf,
        "indexOf" => $indexOf,
    };
}

sub VMWriter {
    my $fh = shift;
    my $writePush = sub {
        my ($segment, $index) = @_;
        say {$fh} "push $segment $index";
    };
    my $writePop = sub {
        my ($segment, $index) = @_;
        say {$fh} "pop $segment $index";
    };
    my $writeArithmetic = sub {
        my $command = shift;
        say {$fh} "$command";
    };
    my $writeLabel = sub {
        my $label = shift;
        say {$fh} "label $label";
    };
    my $writeGoto = sub {
        my $label = shift;
        say {$fh} "goto $label";
    };
    my $writeIf = sub {
        my $label = shift;
        say {$fh} "if-goto $label";
    };
    my $writeCall = sub {
        my $name = shift;
        my $nargs = shift;
        say {$fh} "call $name $nargs";
    };
    my $writeFunction = sub {
        my $name = shift;
        my $nargs = shift;
        say {$fh} "function $name $nargs";
    };
    my $writeReturn = sub {
        say {$fh} "return";
    };
    return {
        "writePush" => $writePush,
        "writePop" => $writePop,
        "writeArithmetic" => $writeArithmetic,
        "writeLabel" => $writeLabel,
        "writeGoto" => $writeGoto,
        "writeIf" => $writeIf,
        "writeCall" => $writeCall,
        "writeFunction" => $writeFunction,
        "writeReturn" => $writeReturn,
    };
}


sub CompileEngine {
    my ($fh, $outputfh, $tokenlists) = @_;
    my $mb = [];
    my $matchbracket;
    my $compileSingle;
    my $compileClass;
    my $compileClassVarDec;
    my $compileSubroutine;
    my $compileParameterList;
    my $compileSubroutineBody;
    my $compileVarDec;
    my $compileStatements;
    my $compileLet;
    my $compileIf;
    my $compileWhile;
    my $compileDo;
    my $compileReturn;
    my $compileExpression;
    my $compileTerm;
    my $compileExpressionList;
    my $compileSubroutineCall;
    
    my $compileOp;
    my $symboltable = SymbolTable();  
    my $vw = VMWriter($outputfh);
    my $total_count = 0;
    my $classname;
    my $func_eq_void=0;
    my $genenrate_label = sub {
        $total_count++;
        return "$classname\.$total_count";
    };
    my @map_dot;
    
    $matchbracket = sub {
        my ($start, $end) = @_;
        my @stack;
        for(my $i=$start; $i<=$end; $i++)
        {
            if($tokenlists->[$i]->[0] eq '(' || $tokenlists->[$i]->[0] eq '[' || $tokenlists->[$i]->[0] eq '{')
            {
                push @stack, $i;
            }
            elsif($tokenlists->[$i]->[0] eq ')' || $tokenlists->[$i]->[0] eq ']' || $tokenlists->[$i]->[0] eq '}')
            {
                my $p = pop @stack;
                $mb->[$p] = $i;
            }
            elsif($tokenlists->[$i]->[0] eq ',')
            {
                $map_dot[$i] = $stack[$#stack];
            }
        }
    };

    #### new added
    $compileOp = sub {
        my $op = shift;
        my $type = shift;
        if($op eq '+')
        {
            $vw->{"writeArithmetic"}->("add");
        }
        elsif($op eq '-')
        {
            if($type == 0)
            {
                $vw->{"writeArithmetic"}->("sub");
            }
            else
            {
                $vw->{"writeArithmetic"}->("neg");
            }
        }
        elsif($op eq '*')
        {
            $vw->{"writeCall"}->("Math.multiply", 2);
        }
        elsif($op eq '/')
        {
            $vw->{"writeCall"}->("Math.divide", 2);
        }
        elsif($op eq '&')
        {
            $vw->{"writeArithmetic"}->("and");
        }
        elsif($op eq '|')
        {
            $vw->{"writeArithmetic"}->("or");
        }
        elsif($op eq '<')
        {
            $vw->{"writeArithmetic"}->("lt");
        }
        elsif($op eq '>')
        {
            $vw->{"writeArithmetic"}->("gt");
        }
        elsif($op eq '=')
        {
            $vw->{"writeArithmetic"}->("eq");
        }
        elsif($op eq '~')
        {
            $vw->{"writeArithmetic"}->("not");
        }
    };
    ####
    
    $compileClass = sub {
        my ($start, $end) = @_;
        $matchbracket->($start, $end);
        say {$fh} "<class>";

        #### new added
        $classname = $tokenlists->[$start+1]->[0];
        $symboltable->{"reset_class"}->();
        $total_count=0;
        ####

        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileSingle->($start+2);
        my $i = $start + 3;
        my $j = $end - 1;
        for(my ($now, $pre) = ($i + 1, $i);$now <= $j; $now++)
        {
            if(($tokenlists->[$now+1]->[0] =~ m/static|field|constructor|function|method/)||($now == $j))
            {
                if($tokenlists->[$pre]->[0] =~ m/static|field/)
                {
                    $compileClassVarDec->($pre, $now);
                }
                else
                {
                    $compileSubroutine->($pre, $now);
                }
                $pre = $now + 1;
            }
        }
        $compileSingle->($end);
        say {$fh} "<\/class>";
    };
    $compileClassVarDec = sub {
        my ($start, $end) = @_;
        
        #### new added
        my $kind = $tokenlists->[$start]->[0];
        if($kind eq "static")
        {
            $kind = STATIC;
        }
        elsif($kind eq "field")
        {
            $kind = FIELD;
        }
        my $type = $tokenlists->[$start+1]->[0];
        for(my $i = $start+2;$i<=$end;$i+=2)
        {
            my $name = $tokenlists->[$i]->[0];
            $symboltable->{"define"}->($name, $type, $kind);
        }
        ####
        say {$fh} "<classVarDec>";
        for(my $i = $start; $i<=$end ;$i++)
        {
            $compileSingle->($i);
        }

        say {$fh} "<\/classVarDec>";
    };
    $compileSubroutine = sub {
        my ($start, $end) = @_;
        #### new added
        $symboltable->{"reset_subroutine"}->();
        my $type_of_func = $tokenlists->[$start]->[0];
        if($type_of_func eq "method")
        {
            $symboltable->{"define"}->("this", $classname, ARG);
        }
        $func_eq_void = $tokenlists->[$start+1]->[0] eq "void" ? 1 : 0;
        ####
        say {$fh} "<subroutineDec>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileSingle->($start+2);
        $compileSingle->($start+3);
        my $right = $mb->[$start+3];
        $compileParameterList->($start+4, $right-1);
        #### new added
        my $compileFunc = sub {
            my $nargs = $symboltable->{"varCount"}->(VAR);
            my $funcname = $classname . "\." . $tokenlists->[$start+2]->[0]; 
            $vw->{"writeFunction"}->($funcname, $nargs);
            if($type_of_func eq "constructor")
            {
                $vw->{"writePush"}->("constant", $symboltable->{"varCount"}->(FIELD));
                $vw->{"writeCall"}->("Memory.alloc", 1);
                $vw->{"writePop"}->("pointer", 0);
            }
            elsif($type_of_func eq "method")
            {
                $vw->{"writePush"}->("argument", 0);
                $vw->{"writePop"}->("pointer", 0);
            }
        };
        ####
        $compileSingle->($right);
        $compileSubroutineBody->($right+1, $end, $compileFunc);
        say {$fh} "<\/subroutineDec>";
    };
    $compileParameterList = sub {
        my ($start, $end) = @_;
        my $count=0;
        say {$fh} "<parameterList>";
        #### new added
        for(my $i = $start;$i <= $end; $i+=3)
        {
            my $type = $tokenlists->[$i]->[0];
            my $varname = $tokenlists->[$i+1]->[0];
            $count++;
            $symboltable->{"define"}->($varname, $type, ARG);
        }
    
        ####
        for(my $i = $start; $i<=$end ;$i++)
        {
            $compileSingle->($i);
        }
        say {$fh} "<\/parameterList>";
        return $count;
    };
    $compileSubroutineBody = sub {
        my ($start, $end, $compileFunc) = @_;
        say {$fh} "<subroutineBody>";
        $compileSingle->($start);
        if($tokenlists->[$start+1]->[0] ne 'var')
        {
            $compileFunc->();
            $compileStatements->($start+1,$end-1);
        }
        else
        {
            for(my ($i, $pre) = ($start+1, $start+1); $i<=$end-1 ;$i++)
            {
                if($tokenlists->[$i]->[0] eq ';')
                {
                    $compileVarDec->($pre, $i);
                    if($tokenlists->[$i+1]->[0] ne 'var')
                    {
                        $compileFunc->();
                        $compileStatements->($i+1,$end-1);
                        last;
                    }
                    else
                    {
                        $pre = $i+1;
                    }
                }
            }
        }
        $compileSingle->($end);
        say {$fh} "<\/subroutineBody>";
    };
    $compileVarDec = sub {
        my ($start, $end) = @_;
        say {$fh} "<varDec>";
        #### new added
        my $type = $tokenlists->[$start+1]->[0];
        for(my $i = $start+2;$i<=$end;$i+=2)
        {
            my $name = $tokenlists->[$i]->[0];
            $symboltable->{"define"}->($name, $type, VAR);
        }
        ####
        for(my $i = $start; $i<=$end ;$i++)
        {
            $compileSingle->($i);
        }
        say {$fh} "<\/varDec>";
    };
    $compileStatements = sub {
        my ($start, $end) = @_;
        say {$fh} "<statements>";
        my $j;
        for(my $i = $start; $i<=$end ;$i=$j+1)
        {
            if($tokenlists->[$i]->[0] eq 'let')
            {
                for($j = $i+1;$j<=$end; $j++)
                {
                    last if $tokenlists->[$j]->[0] eq ';';
                }
                $compileLet->($i,$j);
            }
            elsif($tokenlists->[$i]->[0] eq 'if')
            {
                my @arr;
                $j = $mb->[$i+1];
                push @arr, $j;
                $j = $mb->[$j+1];
                push @arr, $j;
                if($tokenlists->[$j+1]->[0] eq 'else')
                {
                    $j = $mb->[$j+2];
                    push @arr, $j;
                }
                $compileIf->($i, $j, @arr);
            }
            elsif($tokenlists->[$i]->[0] eq 'while')
            {
                my @arr;
                $j = $mb->[$i+1];
                push @arr, $j;
                $j = $mb->[$j+1];
                push @arr, $j;
                $compileWhile->($i, $j, @arr);
            }
            elsif($tokenlists->[$i]->[0] eq 'do')
            {
                for($j = $i+1;$j<=$end; $j++)
                {
                    last if $tokenlists->[$j]->[0] eq ';';
                }
                $compileDo->($i,$j);
            }
            elsif($tokenlists->[$i]->[0] eq 'return')
            {
                for($j = $i+1;$j<=$end; $j++)
                {
                    last if $tokenlists->[$j]->[0] eq ';';
                }
                $compileReturn->($i,$j);
            }
        }
        say {$fh} "<\/statements>";
    };
    $compileLet = sub {
        my ($start, $end) = @_;
        say {$fh} "<letStatement>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        my $now = $start + 2;
        #### new added
        my $varname = $tokenlists->[$start+1]->[0];
        my $kind = $symboltable->{"kindOf"}->($varname);
        my $index = $symboltable->{"indexOf"}->($varname);
        ####
        if($tokenlists->[$now]->[0] eq '[')
        {
            #### new added
            $vw->{"writePush"}->($kind, $index);
            ####
            $compileSingle->($now);
            my $next = $mb->[$now];
            $compileExpression->($now+1, $next-1);
            $compileSingle->($next);
            $now = $next+1;
            #### new added
            $vw->{"writeArithmetic"}->("add");
            ####

        }
        $compileSingle->($now);
        $compileExpression->($now+1, $end-1);
        $compileSingle->($end);

        #### new added
        if($tokenlists->[$start + 2]->[0] eq '[')
        {
            $vw->{"writePop"}->("temp", 0);
            $vw->{"writePop"}->("pointer", 1);
            $vw->{"writePush"}->("temp", 0);
            $vw->{"writePop"}->("that", 0);
        }
        else
        {
            $vw->{"writePop"}->($kind, $index);
        }
        ####
        say {$fh} "<\/letStatement>";
    };
    $compileIf = sub {
        my ($start, $end, @arr) = @_;
        say {$fh} "<ifStatement>";
        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileExpression->($start+2, $arr[0]-1);
        #### new added
        $vw->{"writeArithmetic"}->("not");
        my $label1 = $genenrate_label->();
        $vw->{"writeIf"}->($label1);
        ####
        $compileSingle->($arr[0]);
        $compileSingle->($arr[0]+1);
        $compileStatements->($arr[0]+2, $arr[1]-1);
        $compileSingle->($arr[1]);
        #### new added
        my $label2;
        if(defined $arr[2])
        {
            $label2 = $genenrate_label->();
            $vw->{"writeGoto"}->($label2);
        }
        $vw->{"writeLabel"}->($label1);
        ####
        if(defined $arr[2])
        {
            $compileSingle->($arr[1]+1);
            $compileSingle->($arr[1]+2);
            $compileStatements->($arr[1]+3, $arr[2]-1);
            $compileSingle->($arr[2]);
            #### new added
            $vw->{"writeLabel"}->($label2);
            ####
        }
        say {$fh} "<\/ifStatement>";
    };
    $compileWhile = sub {
        my ($start, $end, @arr) = @_;
        say {$fh} "<whileStatement>";
        #### new added
        my $label1 = $genenrate_label->();
        my $label2 = $genenrate_label->();
        $vw->{"writeLabel"}->($label1);
        ####
        $compileSingle->($start);
        $compileSingle->($start+1);
        $compileExpression->($start+2, $arr[0]-1);
        #### new added
        $vw->{"writeArithmetic"}->("not");
        $vw->{"writeIf"}->($label2);
        ####
        $compileSingle->($arr[0]);
        $compileSingle->($arr[0]+1);
        $compileStatements->($arr[0]+2, $arr[1]-1);
        $compileSingle->($arr[1]);
        #### new added
        $vw->{"writeGoto"}->($label1);
        $vw->{"writeLabel"}->($label2);
        ####
        say {$fh} "<\/whileStatement>";
    };
    $compileDo = sub {
        my ($start, $end) = @_;
        say {$fh} "<doStatement>";
        $compileSingle->($start);
        $compileSubroutineCall->($start+1, $end-1);
        $compileSingle->($end);
        #### new added
        $vw->{"writePop"}->("temp", 0);
        ####
        say {$fh} "<\/doStatement>";
    };
    $compileReturn = sub {
        my ($start, $end) = @_;
        say {$fh} "<returnStatement>";
        $compileSingle->($start);
        if($start+1 <= $end-1)
        {
            $compileExpression->($start+1, $end-1);
        }
        #### new added
        else
        {
            $vw->{"writePush"}->("constant", 0);
        }
        $vw->{"writeReturn"}->();
        ####
        $compileSingle->($end);
        say {$fh} "<\/returnStatement>";
    };
    $compileExpression = sub {
        my ($start, $end) = @_;
        say {$fh} "<expression>";
        my $i=$start;
        my $j;
        my $flag=0;
        my $op;
        while($i<=$end)
        {
            if($flag == 1)
            {
                $compileSingle->($i);
                #### new added
                $op = $tokenlists->[$i]->[0];
                ####
                $i++;
            }
            $i = $compileTerm->($i) + 1;
            #### new added
            $compileOp->($op, 0) if $flag == 1;
            ####
            $flag=1;
        }
        say {$fh} "<\/expression>";
    };
    $compileTerm = sub {
        my $p = shift;
        say {$fh} "<term>";
        if($tokenlists->[$p]->[1] eq INT_CONST)
        {
            $compileSingle->($p);
            #### new added
            $vw->{"writePush"}->("constant", $tokenlists->[$p]->[0]);
            ####
            say {$fh} "<\/term>";
            return $p;
        }
        elsif($tokenlists->[$p]->[1] eq STRING_CONST)
        {
            $compileSingle->($p);
            say {$fh} "<\/term>";
            #### new added
            my $string = $tokenlists->[$p]->[0];
            my $l = length $string;
            $vw->{"writePush"}->("constant", $l);
            $vw->{"writeCall"}->("String.new", 1);
            foreach my $char (split //, $string)
            {
                my $ascii = ord($char);
                $vw->{"writePush"}->("constant", $ascii);
                $vw->{"writeCall"}->("String.appendChar", 2);
            }
            ####
            return $p;
        }
        elsif($tokenlists->[$p]->[0] =~ m/true|false|null|this/)
        {
            $compileSingle->($p);
            say {$fh} "<\/term>";
            #### new added
            if($tokenlists->[$p]->[0] eq 'true')
            {
                $vw->{"writePush"}->("constant", 1);
                $vw->{"writeArithmetic"}->('neg');
            }
            elsif($tokenlists->[$p]->[0] eq 'null' || $tokenlists->[$p]->[0] eq 'false')
            {
                $vw->{"writePush"}->("constant", 0);
            }
            elsif($tokenlists->[$p]->[0] eq 'this')
            {
                $vw->{"writePush"}->("pointer", 0);
            }
            ####
            return $p;
        }
        elsif($tokenlists->[$p]->[1] eq INDENTIFIER)
        {
            my $next;
            if($tokenlists->[$p+1]->[0] eq '[')
            {
                $compileSingle->($p);
                my $count=1;
                my $next = $mb->[$p+1];
                #### new added
                my $name = $tokenlists->[$p]->[0];
                my $kind = $symboltable->{"kindOf"}->($name);
                my $index = $symboltable->{"indexOf"}->($name);
                $vw->{"writePush"}->($kind, $index);
                ####
                $compileSingle->($p+1);
                $compileExpression->($p+2, $next-1);
                $compileSingle->($next);
                #### new added
                $vw->{"writeArithmetic"}->("add");
                $vw->{"writePop"}->("pointer", 1);
                $vw->{"writePush"}->("that", 0);
                ####
                say {$fh} "<\/term>";
                return $next;
            }
            elsif($tokenlists->[$p+1]->[0] eq '(')
            {
                my $count=1;
                my $next = $mb->[$p+1];
                $compileSubroutineCall->($p,$next);
                say {$fh} "<\/term>";
                return $next;   
            }
            elsif($tokenlists->[$p+1]->[0] eq '.')
            {
                my $count=1;
                my $next = $mb->[$p+3];
                $compileSubroutineCall->($p,$next);
                say {$fh} "<\/term>";
                return $next;
            }
            else{
                #### new added
                my $name = $tokenlists->[$p]->[0];
                my $kind = $symboltable->{"kindOf"}->($name);
                my $index = $symboltable->{"indexOf"}->($name);
                $vw->{"writePush"}->($kind, $index);
                ####
                $compileSingle->($p);
                say {$fh} "<\/term>";
                return $p;
            }
        }
        elsif($tokenlists->[$p]->[0] eq '(')
        {
            my $next = $mb->[$p];
            $compileSingle->($p);
            $compileExpression->($p+1, $next-1);
            $compileSingle->($next);
            say {$fh} "<\/term>";
            return $next;
        }
        elsif($tokenlists->[$p]->[0] =~ m/\-|\~/)
        {
            #### new added
            my $op = $tokenlists->[$p]->[0];
            ####
            $compileSingle->($p);
            my $p = $compileTerm->($p+1);
            say {$fh} "<\/term>";
            #### new added
            $compileOp->($op, 1);
            ####
            return $p;
        }
    };
    $compileExpressionList = sub {
        my ($start, $end) = @_;
        my $pre = $start-1;
        say {$fh} "<expressionList>";
        my $p;
        my $listcount=0;
        for($p=$start;$p<=$end;$p++)
        {
            if($tokenlists->[$p]->[0] eq ',' && $map_dot[$p] == $pre)
            {
                $compileExpression->($start, $p-1);
                $start = $p+1;
                $compileSingle->($p);
                $listcount++;
            }
        }
        if($start <= $end)
        {
            $compileExpression->($start, $end);
            $listcount++;
        }
        say {$fh} "<\/expressionList>";
        return $listcount;
    };
    $compileSubroutineCall = sub {
        my ($start, $end) = @_;
        $compileSingle->($start);
        #### new added
        my $subroutinename;
        my $nargs = 0;
        #### 
        if($tokenlists->[$start+1]->[0] eq '.')
        {
            #### new added
            $subroutinename = $tokenlists->[$start]->[0];
            if($symboltable->{"kindOf"}->($subroutinename) ne NONE)
            {
                my $name = $subroutinename;
                $subroutinename = $symboltable->{"typeOf"}->($name);
                my $kind = $symboltable->{"kindOf"}->($name);
                my $index = $symboltable->{"indexOf"}->($name);
                $vw->{"writePush"}->($kind, $index);
                $nargs++;
            }
            $subroutinename .= '.' . $tokenlists->[$start+2]->[0];
            ####
            $compileSingle->($start+1);
            $compileSingle->($start+2);
            $compileSingle->($start+3);
            $nargs += $compileExpressionList->($start+4, $end-1); #
            $compileSingle->($end);
        }
        else
        {
            ####new added
            $nargs++;
            $subroutinename = $classname . '.' . $tokenlists->[$start]->[0];
            $vw->{"writePush"}->("pointer", 0);
            ####
            $compileSingle->($start+1);
            $nargs += $compileExpressionList->($start+2, $end-1); #
            $compileSingle->($end);
        }
        $vw->{"writeCall"}->($subroutinename, $nargs);
    };
    $compileSingle = sub {
        my $position = shift;
        my $word = $tokenlists->[$position];
        print {$fh}"<$word->[1]>";
        if($word->[0] eq '<')
        {
            print {$fh}" \&lt; ";
        }
        elsif($word->[0] eq '>')
        {
            print {$fh}" \&gt; ";
        }
        elsif($word->[0] eq '&')
        {
            print {$fh}" \&amp; ";
        }
        else
        {
            print {$fh}" $word->[0] ";
        }
        print {$fh}"<\/$word->[1]>";
        print {$fh}"\n";
    };
    return $compileClass;
}

########
# main #
########


my $filelists = file_sub(qr/\.jack/, @ARGV);

foreach my $filename (@$filelists){
    open my $fh, "<", $filename->[0];
    my $content = ign_blank $fh;
    close $fh;
    my $tokenlists = JackTokenizer $content;
    # open $fh, ">", $filename->[1];
    open $fh, ">", $filename->[1];
    output_token $fh, $tokenlists;
    close $fh;
    open $fh, ">", $filename->[2];
    open my $outputfh, ">", $filename->[3];
    my $ce = CompileEngine($fh, $outputfh, $tokenlists);
    $ce->(0, $#$tokenlists);
}