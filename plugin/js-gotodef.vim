if exists("g:loaded_js_gotodef") || &cp || v:version < 700
    finish
endif
let g:loaded_js_gotodef = 1

function! s:gotoDef()
    let saved_ack_qhandler = g:ack_qhandler
    let word = expand("<cword>")

    let searchingWord = word

    if (empty(searchingWord))
        return
    endif

    let @/ = searchingWord
    set hlsearch
    let g:ack_qhandler = winnr('$') > 2 ? 'botright copen' : 'belowright copen'

    let searchCommand = ":LAck! "

    " TODO: to var
    let path = "src/" 

    " let isQuickfixOpened = 0
    " windo if &l:buftype == "quickfix" | let isQuickfixOpened = 1 | endif
    :cclose

    let searchExpr = searchingWord." ?=|function +".searchingWord."|".searchingWord." *:"
    :execute searchCommand."'".searchExpr."' ".path

    " let qfList = getqflist()
    let locList = getloclist(0)
    if (len(locList) == 1)
        :ll! | lclose
    " следующий if - ничего функционального не несет, только делает
    " поменьше дергов когда всего одно окно (помимо NERDTree)
    elseif (winnr('$') > 2)
        :NERDTreeClose | NERDTree | wincmd l | wincmd j
    endif

    let g:ack_qhandler = saved_ack_qhandler
endfunction

nnoremap <C-]> :call <SID>gotoDef(0, 0, 0, 1)<cr>

" find/replace in current project 
if has("win32") || has("win16")
"   Plugin 'henrik/vim-qargs' needed for next line
    nnoremap <M-h> :Qdo %s/<C-r>f//gce\|update<left><left><left><left><left><left><left><left><left><left><left><C-r>f
else
"   Plugin 'henrik/vim-qargs' needed for next line
    nnoremap <M-h> :Qdo %s/\<<C-r>f\>//gce\|update<left><left><left><left><left><left><left><left><left><left><left><C-r>f
endif
" }}}
