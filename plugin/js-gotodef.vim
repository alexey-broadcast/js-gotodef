if exists("g:loaded_js_gotodef") || &cp || v:version < 700
    finish
endif
let g:loaded_js_gotodef = 1

let g:jsGotodefPath = "src/"

" Regex will look like this:
" TODO: search css classes
" function +word|word *[=:] *(\(|function|\S+ *=>)
function! s:getSearchExprPerl(word)
    let strongWord = '\b' . a:word . '\b'
    return 'function\*? +'.strongWord .
      \ '|\.'.strongWord.' *[=:]' .
      \ '|'.strongWord.' *[=:]' .
      \ '|(const|var|let) +'.strongWord .
      \ '|class +'.strongWord
endfunction

function! s:getSearchExprVim(word)
    let strongWord = a:word
    return '\v' .
      \  'function\*? +'.strongWord .
      \ '|\.'.strongWord.' *[=:]' .
      \ '|'.strongWord.' *[=:]' .
      \ '|(const|var|let) +'.strongWord .
      \ '|class +'.strongWord
endfunction

" bug: 
" const lalala =
"   (arg1, arg2) 

function! s:JsGotoDefGlobal(word)
    " Step 0: save settings
    let saved_ack_lhandler = g:ack_lhandler
    let g:ack_lhandler = ''
    let saved_hlsearch = &hlsearch
    set hlsearch
    let saved_ackprg = g:ackprg
    let g:ackprg .= " -G js"

    " let isQuickfixOpened = 0
    " windo if &l:buftype == "quickfix" | let isQuickfixOpened = 1 | endif
    :cclose

    " Step 1: start function
    let searchExpr = s:getSearchExprPerl(a:word)

    :execute ":LAck! '".searchExpr."' ".g:jsGotodefPath
    let locList = getloclist(0)

    if (len(locList) == 1)
        :ll! | normal! zz
    else
        if (winnr('$') > 2) | botright lopen | else | belowright lopen | endif
        " следующий if - ничего функционального не несет, только делает
        " поменьше дергов когда всего одно окно (помимо NERDTree)
        if (winnr('$') > 2)
            :NERDTreeClose | NERDTree | wincmd l | wincmd j
        endif
    endif

    " Step 3: restore settings
    let g:ackprg = saved_ackprg
    let g:ack_lhandler = saved_ack_lhandler
    let &hlsearch = saved_hlsearch
endfunction

function! s:JsGotoDefInner(wordArg, winView)
    let isFirstCall = type(a:winView) != 4
    let word = isFirstCall ? expand("<cword>") : a:wordArg

    if (empty(word))
        return
    endif


    " Step 0: save settings
    if (isFirstCall)
        let saved_magic = &magic
        set magic

        let saved_ignorecase = &ignorecase
        set noignorecase

        let saved_foldmethod = &foldmethod
        set foldmethod=syntax
    endif
    let currentWinView = isFirstCall ? winsaveview() : a:winView

    " Step 1: run func
    let searchExpr = s:getSearchExprVim(word)

    let currentPos = line('.')
    let currentFoldlevel = foldlevel('.')
    let blockStartLine = 0
    let blockEndLine = line('$')

    let jumpCmdPrefix = isFirstCall ? '' : 'keepjumps '
    execute jumpCmdPrefix . 'normal! [{'
    let searchInWholeFile = line('.') == currentPos
    if (searchInWholeFile)
        keepjumps normal! gg
    else
        let blockStartLine = line('.')
        keepjumps normal! ]}
        let blockEndLine = line('.')
        keepjumps normal! [{
    endif

    let lineNr = search(searchExpr, '', blockEndLine)
    while (
   \         foldlevel(lineNr) > currentFoldlevel
   \      && lineNr <= blockEndLine
   \      && lineNr >= blockStartLine
   \)
        let lineNr = search(searchExpr, '', blockEndLine)
    endwhile

    if (lineNr == currentPos)
        call winrestview(currentWinView)
        call s:JsGotoDefGlobal(word)
    endif

    if (lineNr == 0)
        if (!searchInWholeFile)
            call s:JsGotoDefInner(word, currentWinView)
        else
            call winrestview(currentWinView)
            call s:JsGotoDefGlobal(word)
        endif
    endif

    " restore settings
    if (isFirstCall)
        let &magic = saved_magic
        let &ignorecase = saved_ignorecase
        let &foldmethod = saved_foldmethod
    endif
endfunction

function! JsGotoDef() 
    call s:JsGotoDefInner(0, 0)
endfunction!
