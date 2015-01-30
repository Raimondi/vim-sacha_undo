function! undoing#node#new(n, parent, time, curhead, newhead) "{{{1
  let node          = {}
  let node.n        = a:n
  let node.parent   = a:parent
  let node.time     = a:time
  let node.curhead  = a:curhead
  let node.newhead  = a:newhead
  let node.children = []

  func node.to_s() dict
    return       'n='         .  self.n
          \ .  ', time='      .  self.time
          \ .  ', curhead='   .  self.curhead
          \ .  ', newhead='   .  self.newhead
          \ .  ', children='  .  string(map(deepcopy(self.children), 'v:val.n'))
          \ .  ', parent='    .  (empty(self.parent) ? 'None' : self.parent.n)
  endfunction

  return node
endfunction
