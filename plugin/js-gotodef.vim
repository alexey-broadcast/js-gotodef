if exists("g:loaded_js_gotodef") || &cp || v:version < 700
    finish
endif
let g:loaded_js_gotodef = 1

let g:jsGotodefPath = "src/"

" Regex will look like this:
" TODO: search css classes
" function +word|word *[=:] *(\(|function|\S+ *=>)
function! s:getSearchExpr(word)
    return 'function +'.a:word.'[^ ]*\(' .
      \ '|[ \.]'.a:word.' *[=:] *(\(|function|\S+ *=>)' .
      \ '|class +'.a:word
endfunction

" bug: 
" const lalala =
"   (arg1, arg2) 

function! JsGotoDef()
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
    " get word under cursor
    let word = expand("<cword>")

    if (empty(word))
        return
    endif

    let searchCommand = ":LAck! "

    let searchExpr = s:getSearchExpr(word)

    :execute searchCommand."'".searchExpr."' ".g:jsGotodefPath

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
