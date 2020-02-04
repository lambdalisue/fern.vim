let s:Lambda = vital#fern#import('Lambda')
let s:Promise = vital#fern#import('Async.Promise')

function! fern#internal#viewer#open(fri, options) abort
  let bufname = fern#fri#format(a:fri)
  return s:Promise.new(funcref('s:open', [bufname, a:options]))
endfunction

function! fern#internal#viewer#init() abort
  if exists('b:fern') && !get(g:, 'fern_debug')
    return s:Promise.resolve()
  endif
  let bufnr = bufnr('%')
  return s:init()
        \.then({ -> s:notify(bufnr, v:null) })
        \.catch({ e -> s:Lambda.pass(e, s:notify(bufnr, e)) })
endfunction

function! s:open(bufname, options, resolve, reject) abort
  call fern#internal#buffer#open(a:bufname . '$', a:options)
  let b:fern_notifier = {
        \ 'resolve': a:resolve,
        \ 'reject': a:reject,
        \}
endfunction

function! s:init() abort
  setlocal buftype=nofile bufhidden=unload
  setlocal noswapfile nobuflisted nomodifiable
  setlocal signcolumn=yes

  augroup fern_viewer_internal
    autocmd! * <buffer>
    autocmd BufEnter <buffer> setlocal nobuflisted
    autocmd BufReadCmd <buffer> ++nested call s:BufReadCmd()
    autocmd ColorScheme <buffer> call s:ColorScheme()
    autocmd CursorMoved,CursorMovedI <buffer> let b:fern_cursor = getcurpos()
  augroup END

  " Add unique fragment to make each buffer uniq
  let bufname = bufname('%')
  let fri = fern#internal#bufname#parse(bufname)
  if empty(fri.authority)
    let fri.authority = sha256(localtime())[:7]
    let bufname = fern#fri#format(fri)
    execute printf('silent keepalt file %s$', fnameescape(bufname))
  endif

  let resource_uri = fri.path
  let scheme = fern#fri#parse(resource_uri).scheme
  let provider = fern#internal#scheme#provider_new(scheme)
  if provider is# v:null
    return s:Promise.reject(printf('no such scheme %s exists', scheme))
  endif

  try
    let b:fern = fern#internal#core#new(
          \ resource_uri,
          \ provider,
          \)
    let helper = fern#helper#new()
    let root = helper.sync.get_root_node()

    call fern#internal#mapping#init(scheme)
    call fern#internal#drawer#init()
    call fern#internal#spinner#start()
    call helper.fern.renderer.highlight()

    " now the buffer is ready so set filetype to emit FileType
    setlocal filetype=fern
    call helper.fern.renderer.syntax()
    call fern#internal#action#init()

    let reveal = split(fri.fragment, '/')
    let Profile = fern#profile#start('fern#internal#viewer:init')
    return s:Promise.resolve()
          \.then({ -> helper.async.expand_node(root.__key) })
          \.finally({ -> Profile('expand') })
          \.then({ -> helper.async.reveal_node(reveal) })
          \.finally({ -> Profile('reveal') })
          \.then({ -> helper.async.redraw() })
          \.finally({ -> Profile('redraw') })
          \.then({ -> helper.sync.focus_node(reveal) })
          \.finally({ -> Profile() })
  catch
    return s:Promise.reject(v:exception)
  endtry
endfunction

function! s:notify(bufnr, error) abort
  let notifier = getbufvar(a:bufnr, 'fern_notifier', v:null)
  if notifier isnot# v:null
    call setbufvar(a:bufnr, 'fern_notifier', v:null)
    if a:error is# v:null
      call notifier.resolve(a:bufnr)
    else
      call notifier.reject([a:bufnr, a:error])
    endif
  endif
endfunction

function! s:BufReadCmd() abort
  let helper = fern#helper#new()
  call helper.fern.renderer.syntax()
  let root = helper.sync.get_root_node()
  let cursor = get(b:, 'fern_cursor', getcurpos())
  call s:Promise.resolve()
        \.then({ -> helper.async.redraw() })
        \.then({ -> helper.sync.set_cursor(cursor[1:2]) })
        \.then({ -> helper.async.reload_node(root.__key) })
        \.then({ -> helper.async.redraw() })
        \.catch({ e -> fern#logger#error(e) })
endfunction

function! s:ColorScheme() abort
  let helper = fern#helper#new()
  call helper.fern.renderer.highlight()
endfunction
