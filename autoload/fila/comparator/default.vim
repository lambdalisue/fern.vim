let s:Comp = { i1, i2 -> i1 == i2 ? 0 : i1 > i2 ? 1 : -1 }
let s:STATUS_NONE = g:fila#tree#item#STATUS_NONE

function! fila#comparator#default#new() abort
  return { 'compare': funcref('s:compare') }
endfunction

function! s:compare(n1, n2) abort
  let k1 = split(a:n1.resource_uri, '/')
  let k2 = split(a:n2.resource_uri, '/')
  let t1 = a:n1.status isnot# s:STATUS_NONE
  let t2 = a:n2.status isnot# s:STATUS_NONE
  let l1 = len(k1)
  let l2 = len(k2)
  for index in range(0, min([l1, l2]) - 1)
    if k1[index] ==# k2[index]
      continue
    endif
    let _t1 = index + 1 is# l1 ? t1 : 1
    let _t2 = index + 1 is# l2 ? t2 : 1
    if _t1 is# _t2
      " Lexical compare
      return k1[index] > k2[index] ? 1 : -1
    else
      " Directory first
      return _t1 ? -1 : 1
    endif
  endfor
  " Shorter first
  let r = s:Comp(l1, l2)
  return r is# 0 ? s:Comp(!a:n1.status, !a:n2.status) : r
endfunction
