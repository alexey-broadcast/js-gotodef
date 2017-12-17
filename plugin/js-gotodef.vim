if exists("g:loaded_js_gotodef") || &cp || v:version < 700
    finish
endif
let g:loaded_js_gotodef = 1

let g:jsGotodefPath = "src/"

" Regex will look like this:
" TODO: search css classes
" function +word|word *[=:] *(\(|function|\S+ *=>)
function! s:getSearchExpr(word)
    return 'function +'.a:word.'|'.a:word.' *[=:] *(\(|function|\S+ *=>)'
endfunction

function! s:gotoDef()
    echom g:ackprg
    " Step 0: save settings
    let saved_ack_qhandler = g:ack_qhandler
    let g:ack_qhandler = winnr('$') > 2 ? 'botright lopen' : 'belowright lopen'
    let saved_hlsearch = &hlsearch
    set hlsearch

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
        :ll! | lclose
    " следующий if - ничего функционального не несет, только делает
    " поменьше дергов когда всего одно окно (помимо NERDTree)
    elseif (winnr('$') > 2)
        :NERDTreeClose | NERDTree | wincmd l | wincmd j
    endif

    " Step 3: restore settings
    let g:ack_qhandler = saved_ack_qhandler
    let &hlsearch = saved_hlsearch
endfunction

nnoremap <C-]> :call <SID>gotoDef()<cr>
