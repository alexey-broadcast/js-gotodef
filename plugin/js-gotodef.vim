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

    let func = 'function\*? +'.strongWord
    let def = strongWord.' *[=:]'
    let prop = '\.'.strongWord.' *[=:]'
    let var = '(const|var|let) +'.strongWord
    let class = 'class +'.strongWord
    return join([func, def, prop, var, class], '|')
endfunction

" bug: 
" const lalala =
"   (arg1, arg2) 

" clear all items with item.bufnr == bufnr
function! s:NotInBuf(item, bufNumber)
    return a:item.bufnr != a:bufNumber
endfunction
let s:notInBuf = function('s:NotInBuf')

" clear all items with item.bufnr == bufnr
function! s:NotInTest(item)
    return bufname(a:item.bufnr) !~# '__test__'
endfunction
let s:notInTest = function('s:NotInTest')

" clear all items that are inside '__test__' folder
function! s:OnlyInBuf(item, bufNumber)
    return a:item.bufnr == a:bufNumber
endfunction
let s:onlyInBuf = function('s:OnlyInBuf')

" clear all items that are not js-files
function s:OnlyJS(item)
    return bufname(a:item.bufnr) =~# '\.js$'
endfunction
let s:onlyJS = function('s:OnlyJS')

" clear items with 'PropTypes'
function! s:NotPropTypes(item)
    return a:item.text !~# 'PropTypes'
endfunction
let s:notPropTypes = function('s:NotPropTypes')

function s:FilterList(list, fn, ...)
    let bufNumber = get(a:, 1, -1)
    let list = deepcopy(a:list)
    let postfix = '(v:val'.(bufNumber > -1 ? ', bufNumber' : '').')'
    return filter(list, string(a:fn).postfix)
endfunction

function! s:getFoldBound(lnum, startOrEnd)
    let currentFoldlevel = foldlevel(a:lnum)
    let dLnum = (a:startOrEnd == 'start' ? -1 : 1)
    let result = a:lnum
    while (foldlevel(result) >= currentFoldlevel && result >= 0 && result <= line('$'))
        let result = result + dLnum
    endwhile
    let result = result - dLnum " один из шагов в цикле был лишний
    return result
endfunction

function! s:RecursiveSearchInFile(list, currentLine)
    let foldStartLnum = s:getFoldBound(a:currentLine, 'start')
    let foldEndLnum = s:getFoldBound(a:currentLine, 'end')

    for occurence in a:list
        if (
       \       occurence.lnum >= foldStartLnum
       \    && occurence.lnum <= foldEndLnum
       \    && foldlevel(occurence.lnum) == foldlevel(a:currentLine)
       \)
            return occurence.lnum
        endif
    endfor

    if (foldStartLnum > 0)
        return s:RecursiveSearchInFile(a:list, foldStartLnum - 1)
    else
        return -1
    endif
endfunction

function! s:JsGotoDefInner(word)
    let searchExpr = s:getSearchExprPerl(a:word)

    let currentFileDir = expand('%:p:h')
    :execute ":LAck! '".searchExpr."' ".currentFileDir."*"
    let locList = getloclist(0)
    let locList = s:FilterList(locList, s:onlyInBuf, bufnr('%'))
    let locList = s:FilterList(locList, s:notPropTypes)

    let lnum = s:RecursiveSearchInFile(locList, line('.'))

    if (lnum == -1 || lnum == line('.'))
        call s:JsGotoDefGlobal(a:word)
    else
        normal! m'
        call setpos('.', [0, lnum, 0, 0, 0])
        call search(a:word, 'ce')
    endif
endfunction

function! s:JsGotoDefGlobal(word)
    " let isQuickfixOpened = 0
    " windo if &l:buftype == "quickfix" | let isQuickfixOpened = 1 | endif

    let searchExpr = s:getSearchExprPerl(a:word)

    :execute ":LAck! '".searchExpr."' ".g:jsGotodefPath
    let locList = getloclist(0)
    let locList = s:FilterList(locList, s:notInBuf, bufnr('%'))
    let locList = s:FilterList(locList, s:onlyJS)
    let locList = s:FilterList(locList, s:notPropTypes)

    let currentFileDir = expand('%:p:h')
    if (currentFileDir !~# '__test__')
        let locList = s:FilterList(locList, s:notInTest)
    endif
    call setloclist(0, locList)

    if (len(locList) == 1)
        normal! m'
        :ll!
        normal! zz 
        call search(a:word, 'ce')
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

function! JsGotoDef() 
    let word = expand("<cword>")

    if (empty(word))
        return
    endif

    " Step 0: save settings
    let saved_foldmethod = &foldmethod

    let saved_ack_lhandler = g:ack_lhandler
    let saved_hlsearch = &hlsearch
    let saved_ackprg = g:ackprg

    " Step 1: set settings for function
    set foldmethod=syntax

    let g:ack_lhandler = ''
    set hlsearch
    let g:ackprg .= " -G js"

    " Step 2: run search
    call s:JsGotoDefInner(word)

    " Step 3: restore settings
    let &foldmethod = saved_foldmethod

    let g:ackprg = saved_ackprg
    let g:ack_lhandler = saved_ack_lhandler
    let &hlsearch = saved_hlsearch
endfunction!
