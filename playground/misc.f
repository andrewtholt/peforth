
    marker === // ( -- ) Marker before misc.f, forget misc.f and all following definitions.

    : (pyclude) // ( <pathname.py> -- "code" ) Prepare the .py file into a <PY>..</PY> section ready to run
                CR word readTextFile py> re.sub("#__peforth__","",pop()) 
                py> re.sub(r"(from\s+__future__\s+import\s+print_function)",r"#\1",pop()) 
                <text> 
                os.environ['TF_CPP_MIN_LOG_LEVEL']='2' # https://stackoverflow.com/questions/43134753/tensorflow-wasnt-compiled-to-use-sse-etc-instructions-but-these-are-availab
                </text> -indent swap + 
                -indent indent <py> "    <p" + "y>\n" + pop() 
                + "\n    </p" + "y>\n" </pyV> ;
                /// Auto-remove all #__peforth__ marks so we can add debug
                /// statements that are only visible when debugging.
                /// Auto comment out "from __future__ import print_function" 
                /// that is not allowed when in a <PY>..</PY> space.
                
    : pyclude   // ( <pathname.py> -- ... ) Run the .py file in a <PY>..</PY> space
                (pyclude) dictate ; 
                ' (pyclude) :> comment last :: comment=pop(1)

    : .members  // ( obj -- ) See the object details through inspect.getmembers(obj)
                py> inspect.getmembers(pop()) cr (see) cr ;
                /// Also (see) .source
                    
    : .source   // ( function -- ) See source code through inspect.getsource(func)
                py> inspect.getsource(pop()) cr . cr ;
                /// Also .members (see)
                /// py: dis.dis(pop()) \ sees pseudo code of a function at TOS.

    : dos       // ( <command line> -- errorlevel ) Shell to DOS Box run rest of the line
                CR word ( cml ) trim ( cml' )
                ?dup if py> os.system(pop())
                else py> os.system('cmd/k') then ;
                /// See also WshShell 
                
    : cd        // ( <path> -- ) Mimic DOS cd command
                CR word ?dup if py: os.chdir(pop())
                else py> os.getcwd() . cr then ;
                /// Use 'dos' command can NOT do chdir, different shell.
                /// See also: os.chdir('path'); path=os.getcwd()

    : round-off // ( f 100 -- f' ) 對 f 取小數點以下 2 位四捨五入
                py> int(pop(1)*tos(0)+0.5)/pop(0) ;
        
    code txt2json # ( txt -- dict ) Convert given string to dictionary
                push(json.loads("".join([ c if c != "'" else '"' for c in pop()])))
                end-code

    \
    \ Redefine unknown to try global variables in __main__ 
    \
    
    none value _locals_ // ( -- dict ) locals passed down from ok()
    false value debug // ( -- flag ) enable/disable the ok() breakpoint

    : unknown   // ( token -- thing Y|N) Try to find the unknown token in __main__ or _locals_
                _locals_ if \ in a function
                ( token ) _locals_ :> get(tos(),"Ûnknôwn") ( token, local )
                py> str(tos())!="Ûnknôwn" ( token, local, unknown? ) 
                if ( token, local ) nip true exit ( return local Y ) else drop ( token ) then   
                then   
                ( token ) py> getattr(sys.modules['__main__'],pop(),"Ûnknôwn") ( thing ) 
                py> str(tos())=="Ûnknôwn" if ( thing ) drop false else true then ; 
                /// Example: Set a breakpoint in python code like this: 
                ///   if peforth.execute('debug').pop() : peforth.push(locals()).ok("bp>",cmd='to _locals_')
                /// Example: Save locals for investigations:
                ///   if peforth.execute('debug').pop() : peforth.push(locals()).dictate('to _locals_')
                /// That enters peforth that knows variables in __main__ and locals at the breakpoint.
                /// 'quit' to leave the breakpoint and forget locals.
                /// 'exit' to leave the breakpoint w/o forget locals.

    : quit      // ( -- ) ( -- ) Quit the breakpoint forget locals and continue the process
                none to _locals_ py: vm.exit=True ;  

    \ <text>
    \ \ 
    \ \ WshShell - users may not install win32 packages yet so only a clue here
    \ \ Run "WshShell dictate" to vitalize this word
    \ \ 
    \ import win32com.client constant win32com.client // ( -- module )
    \ win32com.client :> Dispatch("WScript.Shell") constant WshShell // ( -- obj ) The "Windows Script Host" object https://technet.microsoft.com/en-us/library/ee156607.aspx
    \     /// WshShell :: rUn("c:\Windows\System32\scrnsave.scr") \ Windows display off power saving mode
    \     /// WshShell :: SeNdKeYs("abc")
    \     /// WshShell :: ApPaCtIvAtE("c:\\") \ beginning 2+ chars of the window title, case insensitive.
    \     /// WshShell ::~ RuN("python -i -m peforth WshShell dictate cls version drop dos title child peforth")
    \ </text> constant WshShell // ( -- "clue" ) Guide how to use WshShell

    \ Obsoleted
    \ <py>
    \     def outport(loc): 
    \         '''
    \         # Make all local variables forth constants.
    \         # The input argument is supposed locals() of the caller.
    \         # Examine locals after a <Py>...</Py> section 
    \         # For studying maching learning, tersorflow, ... etc. 
    \         # Usage: outport(locals())
    \         '''
    \         for i in loc: 
    \             push(loc[i]) # vale
    \             push(i) # variable name
    \             execute('(constant)')
    \             last().type='value.outport'
    \     vm.outport = outport
    \ </py>
    \ 
    \ : inport    // ( dict -- ) Make all pairs in dict peforth values. 
    \             py: outport(pop()) ; 
    \             /// Example: investigate the root application
    \             /// ok(loc=locals(),glo=globals(),cmd=':> [0] inport')
    \             
    \ <py>
    \     def harry_port(loc={}):
    \         '''
    \         # Note! Don't use this technique in any compiled snippet, but run by exec() 
    \         # instead. This function returns a dict of all FORTH values with type of 
    \         # "value.outport". Refer to 1) FORTH word 'inport' which converts a dict, a 
    \         # snapshot of locals(), at TOS to FORTH values, and 2) python function 
    \         # outport() which converts the given locals() to FORTH values. The two are 
    \         # similar. While harry_port() does the reverse, it brings FORTH values, that 
    \         # were outported from a locals(), back to python locals().             
    \         # Usage: Method A) exec(python_code, harry_port()) 
    \         #        Method B) locals().update(harry_port())
    \         # <PY> exec("locals().update(harry_port()); x = sess.run(myXX); print(x)") </PY>
    \         # Usage: 
    \         #   1. exec("x = sess.run(myXX); print(x)", harry_port())
    \         #   2. locals().update(harry_port()) # in code executed by exec()
    \         '''
    \         ws = [w.name for w in words[context][1:] if 'outport' in w.type]
    \         for i in ws:
    \             loc.update({i:v(i)})
    \         return loc 
    \     vm.harry_port = harry_port    
    \ </py>
    \             
    \ : harry_port py> harry_port.__doc__ -indent . cr ; // ( -- ) Print help message







