function! undoing#node#new(n, parent, time, curhead, newhead) "{{{1
  let node          = {}
  let node.n        = a:n
  let node.parent   = a:parent
  let node.time     = a:time
  let node.curhead  = a:curhead
  let node.newhead  = a:newhead

  func node.to_s() dict
    return       'n='         .  self.n
          \ .  ', time='      .  self.time
          \ .  ', curhead='   .  self.curhead
          \ .  ', newhead='   .  self.newhead
          \ .  ', parent='    .  self.parent.n
  endfunction

  return node
endfunction

function! undoing#node#root()
  return undoing#node#new(0, {'n' : -1}, 0, 0, 0)
endfunction
