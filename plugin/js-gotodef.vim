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

" clear all items with item.bufnr == bufnr
function! s:FilterLocList(list, bufNumber)
    let list = deepcopy(a:list)
    return filter(list, 'v:val.bufnr != a:bufNumber')
endfunction

function! s:JsGotoDefGlobal(word)
    " let isQuickfixOpened = 0
    " windo if &l:buftype == "quickfix" | let isQuickfixOpened = 1 | endif

    let searchExpr = s:getSearchExprPerl(a:word)

    :execute ":LAck! '".searchExpr."' ".g:jsGotodefPath
    let locList = s:FilterLocList(getloclist(0), bufnr('%'))
    call setloclist(0, locList)

    if (len(locList) == 1)
        let @/ = a:word
        :ll! | keepjumps normal! zzn
    elseif (len(locList) == 0)
        echo 'JsGotoDef: NOTHING FOUND'
    else
        :cclose
        if (winnr('$') > 2) 
            botright lopen 
            " ничего функционального не несет, только делает
            " поменьше дергов когда всего одно окно (помимо NERDTree)
            :NERDTreeClose | NERDTree | wincmd l | wincmd j
        else 
            belowright lopen 
        endif
    endif
endfunction

function! s:JsGotoDefInner(word, winView)
    let isFirstCall = type(a:winView) != 4
    let currentWinView = isFirstCall ? winsaveview() : a:winView

    " Step 1: run func
    let searchExpr = s:getSearchExprVim(a:word)

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
   \    foldlevel(lineNr) > currentFoldlevel
   \ && lineNr <= blockEndLine
   \ && lineNr >= blockStartLine
   \)
        let lineNr = search(searchExpr, '', blockEndLine)
    endwhile

    if (lineNr == currentPos)
        call winrestview(currentWinView)
        call s:JsGotoDefGlobal(a:word)
    elseif (lineNr == 0)
        if (!searchInWholeFile)
            call s:JsGotoDefInner(a:word, currentWinView)
        else
            call winrestview(currentWinView)
            call s:JsGotoDefGlobal(word)
        endif
    else
        let @/ = a:word
        keepjumps normal! n
    endif
endfunction

function! JsGotoDef() 
    let word = expand("<cword>")

    if (empty(word))
        return
    endif

    " Step 0: save settings
    let saved_magic = &magic
    let saved_ignorecase = &ignorecase
    let saved_foldmethod = &foldmethod
    let saved_searchReg = @/

    let saved_ack_lhandler = g:ack_lhandler
    let saved_hlsearch = &hlsearch
    let saved_ackprg = g:ackprg

    " Step 1: set settings for function
    set magic
    set foldmethod=syntax
    set noignorecase

    let g:ack_lhandler = ''
    set hlsearch
    let g:ackprg .= " -G js"

    " Step 2: run search
    call s:JsGotoDefInner(word, 0)

    " Step 3: restore settings
    let &magic = saved_magic
    let &ignorecase = saved_ignorecase
    let &foldmethod = saved_foldmethod
    let @/ = saved_searchReg

    let g:ackprg = saved_ackprg
    let g:ack_lhandler = saved_ack_lhandler
    let &hlsearch = saved_hlsearch
endfunction!
