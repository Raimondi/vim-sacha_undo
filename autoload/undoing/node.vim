function! undoing#node#new(n, parent, time, curhead, newhead) "{{{1
  let node          = {}
  let node.n        = a:n
  let node.parent   = a:parent
  let node.time     = a:time
  let node.curhead  = a:curhead
  let node.newhead  = a:newhead
  let node.children = []
  if has_key(a:parent, 'children')
    call add(a:parent.children, node)
  endif

  func node.to_s(...) dict
    if a:0 && a:1
      return       'n='         .  self.n
            \ .  ', p='    .  self.parent.n
            \ .  ', c='  .  string(map(copy(self.children), 'v:val.n'))
    endif
    return       'n='         .  self.n
          \ .  ', time='      .  self.time
          \ .  ', curhead='   .  self.curhead
          \ .  ', newhead='   .  self.newhead
          \ .  ', parent='    .  self.parent.n
          \ .  ', children='  .  string(map(copy(self.children), 'v:val.n'))
  endfunction

  return node
endfunction

function! undoing#node#print(nodelist)
  let s = []
  for n in a:nodelist
    call extend(s, [n.to_s()])
  endfor
  return string(s)
endfunction

function! s:empty_to_s()
  return ''
endfunction

function! undoing#node#root()
  return undoing#node#new(0, {'n' : -1, 'to_s' : function('s:empty_to_s')}, 0, 0, 0)
endfunction
