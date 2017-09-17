

    \
    \ 取出整個 selftest buffer 
    \ py> tick('<selftest>').buffer char peforth-selftest.f writeTextFile stop 
    \
    \ 經過 15:34 2017-09-17 on MetaMoji 的討論，這個 selftest 的方法只適合從頭做起的
    \ jeforth 開發階段。來到 peforth 時是從先前的 jeforth 繼承過來的，本有的 selftest
    \ sections 又亂、順序也不對，若還想要整理到讓它們都跟在各自 word 的 source code 旁邊
    \ 就太累，也沒必要。因此，略施小計如上，把 selftest section 整個都抓在一起，集中編輯
    \ 比較方便。
    \

    <comment>

    程式只要稍微大一點點，附上一些 self-test 讓它伺機檢查自身，隨便有做穩定性
    就會提升。 Forth 的結構全部都是 global words， 改動之後難以一一去檢討影響
    到了哪些 words，與其努力抓 bug 不如早點把 self-test 做進去。

    Self-test 的執行時機是程式開始時，或開機時。沒有特定任務就做 self-test.

    include 各個 modules 時，循序就做 self-test。藉由 forth 的 marker, (forget) 等
    self-test 用過即丟， 只花時間，不佔空間。花平時的開發時間不要緊，有特定任務時就
    跳過 self-test 不佔執行系統時間、空間，只佔 source code 的篇幅。

    我嘗試了種種的 self-test 寫法。有的很醜，混在正常程式裡面有礙視線；不醜的很累，佔
    很大 source code 篇幅。以下是發展到目前最好的方法。
    
    project-k kernel 裡只有 code end-code 兩個基本 forth words。只憑這兩個基本 words 
    就馬上要為每個 word 都做 self-test 原本是很困難的。然而 peforth.f 是整個檔案一次
    讀進來成為大大的一個 TIB 的， 所以其中已經含有全部功能。如果 self-test 安排在所有
    的 words 都 load 好以後做，資源充分就不困難。利用〈selftest〉〈/selftest〉這對「文
    字蒐集器」在任意處所蒐集「測試程式的本文」，最後再一次把它當成 TIB 執行。實用上
    〈selftest〉〈/selftest〉出現在每個 word 定義處，裡頭可以放心自由地使用尚未出生的
    「未來 words」, 對寫程式時的頭腦有很大的幫助。 
    
    </comment>

    --- marker ---
    
    \
    \ Redirect print() to screen-buffer 
    \
    py> [""] value screen-buffer // ( -- 'string' ) Selftest screen buffer
    
    <py>
        class Screenbuffer:
            def __init__(self,buf):
                self.stdoutwas=sys.stdout
                self.buffer=buf
            def write(self, output_stream):
                self.buffer[0] += output_stream
            def view(self):
                self.stdoutwas.write(self.buffer[0])
            def reset(self):
                sys.stdout=self.stdoutwas
        vm.Screenbuffer=Screenbuffer
    </py>
    \ # Start redirection
    \ sys.stdout=Screenbuffer(vm.forth['screen-buffer'])
    \ 
    \ # Print to screen when redirected
    \ sys.stdout.stdoutwas.write("-------1111-----\n")
    \ sys.stdout.stdoutwas.write("-------2222-----\n")
    \ 
    \ # view screen buffer
    \ sys.stdout.view()
    \ 
    \ # reset
    \ sys.stdout.reset()
    
    : display-off ( -- ) // Redirect stdout to screen-buffer
        py: sys.stdout=Screenbuffer(vm.forth['screen-buffer']) 
        screen-buffer :: [0]="" ;

    : display-on ( -- ) // Redirect stdout back to what it was. screen-buffer has data during it off.
        py: sys.stdout.reset() ;
    
    .( *** Start self-test ) cr
    
    *** Data stack should be empty
        depth [d 0 d] [p 'code','end-code','<py>','cr','depth','<selftest>',
        '</self'+'test>','<py>','</'+'pyV>','\\','<comment>','</comment>',
        '.(', 'cr','***' p]
    *** Rreturn stack should have less than 2 cells
        py> len(rstack)<=2 [d True d] [p 'py>','<=','[d','d]','[p','p'+']' p]
    *** // adds help to the last word
        ' // :> help.find("message")!=-1 [d True d] [p "//", ":>", "'" p]
    *** TIB lines after \ should be ignored
        marker ===
        111 \ 222
        : dummy
            999
            \ 333 444 555
        ; last execute ===
        [d 111,999 d] [p '\\' p]
    *** /// add comment to the last word 
        marker ===
        : dummy ; /// 98787665453
        ' dummy :> comment.find('98787665453')!=-1 ( True )
        ===
        [d True d] [p '///',':',';','marker' p] 
    *** immediate makes the LAST an immediate word
        marker ===
        : dummy ; immediate
        ' dummy :> immediate ( True )
        ===
        [d True d] [p 'immediate' p] 
    *** compyle source code to function 
        display-off
        <text> print("Hi! Harry, nice to meet you.") </text> compyle execute
        display-on
        screen-buffer <py> pop()[0].find('nice to meet you')!=-1 </pyV> ( True )
        [d True d] [p 'compyle' p]
    *** </pyV> based on </py> and on compyle
        marker ===
        : try char 123 [compile] </pyV> ; try ( 123 )
        : try2 [ char "abc" ] </pyV> ; try2 ( 123 'abc' )
        === [d 123,'abc' d] [p 'compyle','</py>','</pyV>' p]
    *** interpret-only marks the last word an interpret-only word
        ' execute py> getattr(pop(),'interpretonly',False) ( False ) 
        ' interpret-only :> interpretonly==True ( True )
        [d False,True d] [p "interpret-only" p]
    *** immediate marks the last word an immediate word
        ' execute py> getattr(pop(),'immediate',False) ( False ) 
        ' \ :> immediate==True ( True )
        [d False,True d] [p "immediate" p]
    *** compile-only marks last word as a compile-only word
        ' execute py> getattr(pop(),'compileonly',False) ( False )  
        ' if :> compileonly==True ( True )
        [d False,True d] [p "compile-only" p]
    *** literal is a compiling comamnd that can improve run time performance
        marker === : test [ py> sum(range(101)) literal ] ;
        display-off see test === display-on
        screen-buffer <py> pop()[0].find('Literal: 5050')!=-1 </pyV> ( True )            
        [d True d] [p "(create)","(forget)",'char' p]
    *** (create) creates a new word
        char ~(create)~ (create) py> last().name \ ( "~(create)~" )
        (forget) py> last().name=="~(create)~" \ ( "~(create)~" False ) 
        [d "~(create)~",False d] [p "(create)","(forget)",'char' p]
    *** ' (tick) gets word object 
        ' code :> name [d 'code' d] [p "'" p]
    *** "drop" drops the TOS
        321 123 s" drop" execute \ 321
        654 456 ' drop execute \ 321 654
        [d 321,654 d] [p 'drop', "'", "execute", '\\' p]
    *** here points to next available address 
        marker ~~~
        \ Assume dictionary is clean from garbages
        here >r : test ; here 1+ py> len(dictionary) = ( True | here )
        [d True d] [p 'here' p]
        \ here! 靠 allot 檢查，只它用到。
        
    
    *** version should return a floating point number
        display-off
        version 
        display-on 
        float type py> pop()==float ( True )
        screen-buffer <py> pop()[0].find('p e f o r t h')!=-1 </pyV> ( True )
        [d True,True d]
        [p 'version','py:','(' p]
    *** (space) puts a 0x20 on TOS
        (space) py> String.fromCharCode(32) =
        [d True d] [p "(space)","=" p]
    *** BL should return the string '\s' literally
        BL [d "\\s" d] [p "BL" p]
    *** CR should return the string \n|\r literally
        CR js> "\\n|\\r" = 
        [d True d] [p "CR","=" p]                       
    *** word reads "string" from TIB
        marker ---
        char \s word    111    222 222 === >r s" 111" === r> and \ True , whitespace 會切掉
        char  2 word    111    222 222 === >r s"    111    " === r> and \ True , whitespace 照收
        : </div> ;
        char </div> word    此後到 </ div> 之
                    前都被收進，可
                    以跨行！ come-find-me-!!
        </div> js> pop().find("come-find-me-!!")!=-1 \ True
        [d True,True,True d] [p "word" p]
        ---
    *** pyEval should exec(tos) 
        456 char pop()+1 jsEval [d 457 d] [p "jsEval" p]
    *** last should return the last word
        0 constant xxx
        last :> name [d "xxx" d] [p "last" p]
        (forget)
    *** exit should stop a colon word
        : dummy 123 exit 456 ;
        last execute [d 123 d] [p "exit" p]
        (forget)
    *** branch should jump to run hello
        marker ---
        : sum 0 1 begin 2dup + -rot nip 1+ dup 10 > if drop exit then again ;
        : test sum 55 = ;
        test [d True d] [p '2dup', '-rot', 'nip', '1+', '>', '0branch' p]
        ---
    *** ! @ >r r> r@ drop dup swap over 0<
        marker ---
        variable x 123 x ! x @ 123 = \ True
        111 dup >r r@ r> + swap 2 * = and \ True
        333 444 drop 333 = and \ True
        555 666 swap 555 = \ True 666 True
        rot and swap \ True 666
        0< not and \ True
        -1 0< and \ True
        False over \ True
        [d True, False, True d] [p '!', '@', '>r', 'r>', 'r@', 'swap', 'drop',
        'dup', 'over', '0<', '2drop','marker' p]
        ---
    *** (forget) should forget the last word
        : remember-me ; (forget)
        last :> name=="remember-me" [d False d] 
        [p "(forget)","rescan-word-hash" p]
    *** ' tick and (') should return a word object
        ' code :> name char end-code (') :> name
        [d "code","end-code" d] [p "'","(')" p]
    *** boolean and or && || not AND OR NOT XOR
        undefined not \ True
        "" boolean \ True False
        and \ False
        False and \ False
        False or \ False
        True or \ True
        True and \ True
        True or \ True
        False or \ True
        {} [] || \ True [] {}
        && \ True []
        || \ [] True
        && \ True
        "" && \ True ""
        not \ False
        1 2 AND \ True 0
        2 OR NOT  \ True -3
        -3 = \ True True
        1 2 XOR \ True True 3
        0 XOR 3 = \ True True True
        and and \ True
        <js> function test(x){ return x }; test() </jsV> null = \ True True
        [d True,True d] [p 'and', 'or', 'not', '||', '&&', 'AND', 'OR', 'NOT', 'XOR',
        'True', 'False', '""', '[]', '{}', 'undefined', 'boolean', 'null' p] 
    *** + * - / 1+ 2+ 1- 2-
        1 1 + 2 * 1 - 3 / 1+ 2+ 1- 2- 1 = [d True d]
        [p '+', '*', '-', '/', '1+', '2+', '1-', '2-' p]
    *** mod 7 mod 3 is 1
        7 3 mod [d 1 d] [p "mod" p]
    *** div 7 div 3 is 2
        7 3 div [d 2 d] [p "div" p]
    *** >> -1 signed right shift n times will be still -1
        -1 9 >> [d -1 d] [p ">>" p]
    *** >> -4 signed right shift becomes -2
        -4 1 >> [d -2 d] [p ">>" p]
    *** << -1 signed left shift 63 times become the smallest int number
        -1 63 << 0x80000000 -1 * = [d True d] [p "<<" p]
    *** >>> -1 >>> 1 become 7fffffff
        -1 1 >>> 0x7fffffff = [d True d] [p ">>>" p]
    *** 0= 0> 0<> 0 <= 0>=
        "" 0= \ True
        undefined 0= \ True False
        1 0> \ True False True
        0 0> \ True False True False
        XOR -rot XOR + 2 = \ True
        0<> \ False
        0= \ True
        0<> \ True
        0<= \ True
        0>= \ True
        99 && \ 99
        0= \ False
        99 || 0<> \ True
        -1 0<= \ True True
        1 0>= \ True True True
        s" 123" 123 = \ \ True True True True
        [d True,True,True,True d]
        [p '0=', '0>', '0<>', '0<=', '0>=', '=' p]
    *** == compares after booleanized
        {} [] == \ True
        "" null == \ True
        "" undefined == \ True
        s" 123" 123 == \ True
        [d True,True,True,True d] [p "==",'""',"null", "undefined" p]
    *** === compares the type also
        "" 0 = \ True
        "" 0 == \ True
        "" 0 === \ False
        s" 123" 123 = \ True
        s" 123" 123 == \ True
        s" 123" 123 === \ False
        [d True,True,False,True,True,False d]
        [p "===" p]
    *** > < >= <= != !== <>
        1 2 > \ False
        1 1 > \ False
        2 1 > \ True
        1 2 < \ True
        1 1 < \ False
        2 1 < \ fasle
        1 2 >= \ False
        1 1 >= \ True
        2 1 >= \ True
        1 2 <= \ True
        1 1 <= \ True
        2 1 <= \ fasle
        1 1 <> \ False
        0 1 <> \ True
        [d False,False,True,True,False,False,False,True,True,True,True,False,False,True d]
        [p '<', '>=', '<=', '!=', '!==', '<>' p]
    *** abs makes negative positive
        1 63 << abs [d 0x80000000 d] [p "abs" p]
    *** max min
        1 -2 3 max max (  3 )
        1 -2 3 min min ( -2 )
        [d 3,-2 d] [p "max","min" p]
    *** doVar doNext
        marker ---
        variable x
        : tt for x @ . x @ 1+ x ! next ;
        js: vm.selftest_visible=False;vm.screenbuffer=""
        10 tt space \ "0123456789 "
        x @ ( 10 )
        js: vm.selftest_visible=True
        <js> vm.screenbuffer.slice(-11)=="0123456789 "</jsV> ( True )
        [d 10,True d]
        [p 'doNext','space', ',', 'colon-word', 'create',
        'for', 'next' p]
        ---
    *** pick 2 from 1 2 3 gets 1 2 3 1
        1 2 3 0 pick 3 = depth 4 = and >r 3 drops \ True
        1 2 3 1 pick 2 = depth 4 = and >r 3 drops \ True
        1 2 3 2 pick 1 = depth 4 = and >r 3 drops \ True
        r> r> r> [d True,True,True d] [p "pick",">r","r>" p]
    *** roll 2 from 1 2 3 gets 2 3 1
        1 2 3 0 roll 3 = depth 3 = and >r 2 drops \ True
        1 2 3 1 roll 2 = depth 3 = and >r 2 drops \ True
        1 2 3 2 roll 1 = depth 3 = and >r 2 drops \ True
        r> r> r> [d True,True,True d] [p "roll" p]
    *** [compile] compile [ ]
        marker ---
        : iii ; immediate
        : jjj ;
        : test [compile] iii compile jjj ; \ 正常執行 iii，把 jjj 放進 dictionary
        : use [ test ] ; \ 如果 jjj 是 immediate 就可以不要 [ ... ]
        ' use js> pop().cfa @ ' jjj = [d True d]
        [p "[compile]",'compile', '[', ']' p]
        ---
    *** alias should create a new word that acts same
        marker ---
        1234 constant x ' x alias y
        y [d 1234 d] [p "alias" p] 
        ---
    *** nip rot -rot 2drop 2dup invert negate within
        1 2 3 4 nip \ 1 2 4
        -rot \ 4 1 2
        2drop \ 4
        3 2dup \ 4 3 4 3
        invert negate \ 4 3 4 4
        = rot rot \ True 4 3
        5 within \ True True
        1 2 3 within \ True True False
        4 2 3 within \ True True False False
        -2 -4 -1 within \ True True False False True
        0 -4 -1 within \ True True False False True False
        -5 -4 -1 within \ True True False False True False False
        [d True,True,False,False,True,False,False d]
        [p 'rot', '-rot', '2drop', '2dup', 'negate', 'invert', 'within' p]
    *** ['] tick next word immediately
        marker ---
        : x ;
        : test ['] x ;
        test ' x = [d True d] [p "[']" p]
        ---
    *** allot should consume some dictionary cells
        marker ---
        : a ; : b ; ' b :> cfa ' a :> cfa - \ normal distance
        : aa ;
        10 allot
        : bb ; ' bb :> cfa ' aa :> cfa - \ 10 more expected
        *debug* 1122> ---
        [d 10 d] [p "allot" p]
        
    *** begin again , begin until
        marker ---
        : tt
            1 0 \ index sum
            begin \ index sum
                over \ index sum index
                + \ index sum'
                swap 1+ \ sum' index'
                dup 10 > if \ sum' index'
                    drop
                    exit
                then  \ sum' index'
                swap  \ index' sum'
            again
        ; last execute 55 = \ True
        : ttt
            1 0 \ index sum
            begin \ index sum
                over \ index sum index
                + \ index sum'
                swap 1+ \ sum' index'
                swap \ index' sum'
            over 10 > until \ index' sum'
            nip
        ; last execute 55 = \ True
        [d True,True d] [p 'again', 'until', 'over', 'swap', 'dup', 'exit', 'nip' p]
        ---
    *** aft for then next ahead begin while repeat
                marker ---
                : tt 5 for r@ next ; last execute + + + + 15 = \ True
                : ttt 5 for aft r@ then next ; last execute + + + 10 = \ True True
                depth 2 = \ T T T
                : tttt
                    0 0 \ index sum
                    begin \ idx sum
                        over 10 <=
                    while \ idx sum
                        over +
                        swap 1+ swap
                    repeat \ idx sum
                    nip
                ; last execute 55 = \ T T T T
                [d True,True,True,True d]
                [p 'for', 'then', 'next', 'ahead', 'begin', 'while', 'repeat' p]
                ---
    *** ?dup dup only when it's True
                1 0 ?dup \ 1 0
                2 ?dup \ 1 0 2 2 
                [d 1,0,2,2 d] [p "?dup" p]
    *** +! variable
                marker ---
                variable x 10 x !
                5 x +! x @ ( 15 )
                [d 15 d] [p 'variable', 'marker', '+!', '@', '!', '(' p]
                ---
    *** spaces chars
                marker ---
                : test 3 spaces ;
                js: vm.selftest_visible=False;vm.screenbuffer=""
                test
                js: vm.selftest_visible=True
                <js> vm.screenbuffer.slice(-3)=='   '</jsV>
                [d True d] [p 'chars',"spaces","(space)" p]
                ---
    *** .( ( ." .' s" s' s`
                marker ---
                js: vm.selftest_visible=False;vm.screenbuffer=""
                .( ff) ( now vm.screenbuffer should be 'ff' )
                js> vm.screenbuffer.slice(-2)=="ff" \ True
                : test ." aa" .' bb' s' cc' . s` dd` . s" ee" . ;
                test js> vm.screenbuffer.slice(-10)=="aabbccddee" \ True
                js: vm.selftest_visible=True
                [d True,True d] [p '(', '."', ".'", "s'", "s`", 's"' p]
                ---
    *** count
                    s" abc" count depth
                    [d "abc",3,2 d] [p "count" p]
    *** value and to work together
        marker -%-%-%-%-%-
        112233 value x x 112233 = \ True
        445566 to x x 445566 = \ True
        : test 778899 to x ; test x 778899 = \ True
        -%-%-%-%-%-
        [d True,True,True d] [p 'value','to' p]
    *** <comment>...</comment> can be nested now
                <comment> 
                    aaaa <comment> bbbbbb </comment> cccccc 
                </comment> 
                111 222 <comment> 333 </comment> 444
                [d 111,222,444 d] [p '<comment>', '</comment>', '::' p]
    *** constant value and to
                marker ---
                112233 constant x
                x value y
                x y = \ True
                332211 to y x y = \ False
                ' x :> type=="constant" \ True
                ' y :> type=="value" \ True
                [d True,False,True,True d] [p "constant","value","to" p]
                ---
    *** int 3.14 is 3, 12.34AB is 12
                3.14 int char 12.34AB int
                [d 3,12 d] [p "int" p]
    *** drops n data stack cells ...
                    1 2 3 4 5 2 drops [d 1,2,3 d] [p "drops" p]
    *** dropall clean the data stack
                1 2 3 4 5 dropall depth 0= [d True d] [p "dropall","0=" p]
    *** ASCII char>ASCII ASCII>char
                marker ---
                char abc char>ASCII ( 97 )
                98 ASCII>char ( b )
                : test ASCII c ; test ( 99 )
                [d 97,'b',99 d] [p 'char>ASCII', 'ASCII>char', "ASCII" p]
                ---
    *** .s is probably the most used word
                marker ---
                js: vm.selftest_visible=False;vm.screenbuffer=""
                32424 -24324 .s
                js: vm.selftest_visible=True
                <js> vm.screenbuffer.find('32424')    !=-1 </jsV> \ True
                <js> vm.screenbuffer.find('7ea8h')    !=-1 </jsV> \ True
                <js> vm.screenbuffer.find('-24324')   !=-1 </jsV> \ True
                <js> vm.screenbuffer.find('ffffa0fch')!=-1 </jsV> \ True
                <js> vm.screenbuffer.find('2:')       ==-1 </jsV> \ True
                [d 32424,-24324,True,True,True,True,True d] [p ".s" p]
                ---
    *** d dump
                js: vm.selftest_visible=False;vm.screenbuffer=""
                d 0
                js: vm.selftest_visible=True
                <js> vm.screenbuffer.find('00000: 0 (number)') !=-1 </jsV> \ True
                [d True d] [p 'dump', 'd' p]
    *** see (see)
                marker ---
                : test ; // test.test.test
                js: vm.selftest_visible=False;vm.screenbuffer=""
                see test
                js: vm.selftest_visible=True
                <js> vm.screenbuffer.find('test.test.test') !=-1 </jsV> \ True
                <js> vm.screenbuffer.find('cfa') !=-1 </jsV> \ True
                <js> vm.screenbuffer.find('colon') !=-1 </jsV> \ True
                [d True,True,True d] [p 'see','(see)','(?)' p]
                ---
    *** End of kernel self-test
        [d d] [p 'accept', 'refill', '***' p]

    ~~selftest~~
